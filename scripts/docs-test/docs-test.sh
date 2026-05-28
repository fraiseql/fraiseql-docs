#!/usr/bin/env bash
# docs-test.sh — Operator CLI for the FraiseQL docs-test harness.
#
# Wraps the Compose plumbing under `scripts/docs-test/` so that page tests
# (Cycle 5+) and human operators do not have to inline 30 lines of profile
# enumeration, env loading, teardown bookkeeping, and SHA drift detection
# per invocation.
#
# Subcommands: up | down | reset | exec | status | logs | sha
# Each subcommand supports --help.
#
# Authored against Phase 00 Cycle 4 spec
# (_internal/.plan/.phases/phase-00-foundation.md § Cycle 4).
#
# source: docker-compose.docs-test.yml — profile policy (this repo)
# source: _internal/.plan/handoff.md — Cycle 1/2/3 lessons (this repo)

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate the harness directory regardless of caller cwd. Standard pattern;
# resolves symlinks via the BASH_SOURCE → dirname → cd → pwd dance.
# ---------------------------------------------------------------------------
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMPOSE_FILE="$HERE/docker-compose.docs-test.yml"
ENV_FILE="$HERE/.env"
ENV_EXAMPLE="$HERE/.env.example"
LAST_PROFILES_FILE="$HERE/.last-profiles"
FRAISEQL_SHA_FILE="$HERE/FRAISEQL_SHA"

# Known profiles. Single source of truth; completion scripts mirror this set
# from a hand-maintained list (kept in sync with this constant by the
# REFACTOR step's checklist).
#
# source: docker-compose.docs-test.yml — every service's `profiles:` entry
KNOWN_PROFILES=(all postgres mysql sqlite mssql redis nats fraiseql storage)

# Default --wait-timeout for `up`. Cycle 2 measured cold-boot ~43.4 s for
# --profile all; storage cold-boot ~6 s; combined warm ~7 s. 240 s gives
# comfortable headroom for slow MSSQL cold starts on memory-pressured hosts.
DEFAULT_WAIT_TIMEOUT=240

# Working directory: always run docker compose from $HERE so relative build
# contexts in the compose file resolve consistently.
cd "$HERE"

# ---------------------------------------------------------------------------
# Logging helpers. Stderr for warnings and errors; stdout reserved for the
# subcommand's own output (so piping `status` / `sha` to other tools works).
# ---------------------------------------------------------------------------
err() {
    printf 'docs-test: %s\n' "$*" >&2
}

warn() {
    printf 'docs-test: warning: %s\n' "$*" >&2
}

die() {
    err "$*"
    exit 1
}

# ---------------------------------------------------------------------------
# Env loading. If `.env` exists, source it. If only `.env.example` exists,
# print a one-line warning to stderr and continue (Compose will use the
# defaults baked into the compose file via the ${VAR:-default} fallbacks).
#
# Set -a / set +a flips automatic export on so sourced KEY=VALUE pairs
# become environment for the docker compose child process.
# ---------------------------------------------------------------------------
load_env() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        # shellcheck disable=SC1090
        . "$ENV_FILE"
        set +a
    elif [ -f "$ENV_EXAMPLE" ]; then
        warn "no \`.env\` — using compose defaults"
    fi
}

# ---------------------------------------------------------------------------
# Profile parsing. Accepts both:
#   --profile a,b,c    (comma-separated)
#   --profile a --profile b   (repeated)
# Internally normalises to a flat array of profile names. The caller turns
# that into the repeated `--profile <p>` argv that `docker compose`
# understands.
#
# Usage:
#   parse_profiles "$@"   # populates the global $PARSED_PROFILES array.
# Sets:
#   PARSED_PROFILES   — array of profile names (no dedup; harmless to repeat)
#   REMAINING_ARGS    — array of args left after consuming --profile pairs
# ---------------------------------------------------------------------------
PARSED_PROFILES=()
REMAINING_ARGS=()
parse_profiles() {
    PARSED_PROFILES=()
    REMAINING_ARGS=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --profile)
                [ $# -ge 2 ] || die "--profile requires an argument"
                # Split on comma (Compose CLI does not accept comma syntax
                # natively; we expand here).
                IFS=',' read -ra _split <<<"$2"
                for p in "${_split[@]}"; do
                    [ -n "$p" ] || continue
                    PARSED_PROFILES+=("$p")
                done
                shift 2
                ;;
            --profile=*)
                IFS=',' read -ra _split <<<"${1#--profile=}"
                for p in "${_split[@]}"; do
                    [ -n "$p" ] || continue
                    PARSED_PROFILES+=("$p")
                done
                shift
                ;;
            *)
                REMAINING_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

# Build the `--profile p1 --profile p2 ...` argv for docker compose from
# the PARSED_PROFILES array. Empty if no profiles given.
profile_argv() {
    local out=()
    for p in "${PARSED_PROFILES[@]}"; do
        out+=(--profile "$p")
    done
    if [ ${#out[@]} -gt 0 ]; then
        printf '%s\n' "${out[@]}"
    fi
}

# ---------------------------------------------------------------------------
# Persist last-used profile set for `reset` to recover. Written one profile
# per line so multi-profile invocations replay verbatim.
# ---------------------------------------------------------------------------
save_last_profiles() {
    : >"$LAST_PROFILES_FILE"
    for p in "${PARSED_PROFILES[@]}"; do
        printf '%s\n' "$p" >>"$LAST_PROFILES_FILE"
    done
}

load_last_profiles() {
    PARSED_PROFILES=()
    if [ -f "$LAST_PROFILES_FILE" ]; then
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            PARSED_PROFILES+=("$p")
        done <"$LAST_PROFILES_FILE"
    fi
    if [ ${#PARSED_PROFILES[@]} -eq 0 ]; then
        PARSED_PROFILES=(all)
    fi
}

# ---------------------------------------------------------------------------
# `up` subcommand.
#
# Behaviour:
#   - Default profile if none given: `all` (the long-running services).
#   - `--profile sqlite` triggers `docker compose run --rm sqlite-init`
#     semantics (one-shot exit-0). This matches the Cycle 1 fix (commit
#     9adb4eb) that removed sqlite-init from `--profile all` because
#     `up --wait` treats exit-0 as failure.
#   - Non-sqlite profiles use `up -d --wait --wait-timeout N`.
#   - --wait-timeout N overrides the default.
#
# source: _internal/.plan/handoff.md — Cycle 1 finishing note on sqlite-init
# ---------------------------------------------------------------------------
cmd_up_help() {
    cat <<'EOF'
docs-test.sh up — boot harness services.

Usage:
  docs-test.sh up [--profile P[,Q,...]]... [--wait-timeout N]

Options:
  --profile P,Q,...   Profile(s) to boot. Comma-separated and/or repeated.
                      Defaults to `all` if omitted.
  --wait-timeout N    Seconds to wait for healthchecks. Default 240.
  --help              Show this help.

Special cases:
  --profile sqlite    Runs `docker compose run --rm sqlite-init` (one-shot;
                      materialises /data/fraiseql.db) instead of `up --wait`,
                      because sqlite-init exits 0 and would otherwise be
                      treated as a healthcheck failure by --wait.
  --profile fraiseql  Auto-includes postgres + redis (per compose file).

Examples:
  docs-test.sh up                       # --profile all
  docs-test.sh up --profile fraiseql    # fraiseql + deps
  docs-test.sh up --profile postgres,redis
  docs-test.sh up --profile all --profile storage --wait-timeout 300
EOF
}

cmd_up() {
    local wait_timeout="$DEFAULT_WAIT_TIMEOUT"
    local args=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --help | -h)
                cmd_up_help
                return 0
                ;;
            --wait-timeout)
                [ $# -ge 2 ] || die "--wait-timeout requires an argument"
                wait_timeout="$2"
                shift 2
                ;;
            --wait-timeout=*)
                wait_timeout="${1#--wait-timeout=}"
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    parse_profiles "${args[@]+"${args[@]}"}"
    if [ ${#PARSED_PROFILES[@]} -eq 0 ]; then
        PARSED_PROFILES=(all)
    fi

    load_env

    # Special handling: sqlite is materialised via `compose run --rm`. If
    # sqlite is the ONLY profile, do not call `up --wait` at all. If sqlite
    # is mixed with other profiles, run sqlite-init separately and then
    # `up --wait` the remainder.
    local has_sqlite=0
    local non_sqlite=()
    for p in "${PARSED_PROFILES[@]}"; do
        if [ "$p" = "sqlite" ]; then
            has_sqlite=1
        else
            non_sqlite+=("$p")
        fi
    done

    if [ "$has_sqlite" -eq 1 ]; then
        printf 'docs-test: materialising sqlite (one-shot)...\n'
        docker compose -f "$COMPOSE_FILE" --profile sqlite run --rm sqlite-init
    fi

    if [ ${#non_sqlite[@]} -gt 0 ]; then
        local profile_args=()
        for p in "${non_sqlite[@]}"; do
            profile_args+=(--profile "$p")
        done
        printf 'docs-test: up --wait --wait-timeout %s (profiles: %s)...\n' \
            "$wait_timeout" "${non_sqlite[*]}"
        docker compose -f "$COMPOSE_FILE" "${profile_args[@]}" \
            up -d --wait --wait-timeout "$wait_timeout"
    fi

    # Persist the user-requested set verbatim (includes sqlite if asked).
    save_last_profiles
}

# ---------------------------------------------------------------------------
# `down` subcommand.
#
# Behaviour:
#   - Always enumerates EVERY profile so storage / fraiseql / sqlite
#     containers are also torn down. Cycle 3 surfaced that `docker compose
#     down` without profiles leaves profiled containers running.
#   - --volumes (or -v) appends `-v` to wipe named volumes.
#   - Always passes --remove-orphans.
#
# source: _internal/.plan/handoff.md — Cycle 3 close, "Compose-design
#         discovery" bullet
# source: https://docs.docker.com/compose/profiles/ — profiles must be
#         enumerated at `down` to affect profiled containers
# ---------------------------------------------------------------------------
cmd_down_help() {
    cat <<'EOF'
docs-test.sh down — tear down harness services across ALL profiles.

Usage:
  docs-test.sh down [--volumes | -v] [--help]

Options:
  --volumes, -v   Also remove named volumes (data wipe). Off by default.
  --help          Show this help.

Notes:
  Always enumerates --profile all --profile storage --profile fraiseql
  --profile sqlite and passes --remove-orphans, because `docker compose
  down` without profiles does NOT touch profiled containers (verified in
  Cycle 3 close handoff entry).
EOF
}

cmd_down() {
    local wipe_volumes=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --help | -h)
                cmd_down_help
                return 0
                ;;
            --volumes | -v)
                wipe_volumes=1
                shift
                ;;
            *)
                die "down: unknown argument: $1"
                ;;
        esac
    done

    load_env

    local args=(
        --profile all
        --profile storage
        --profile fraiseql
        --profile sqlite
        down
        --remove-orphans
    )
    if [ "$wipe_volumes" -eq 1 ]; then
        args+=(-v)
    fi
    docker compose -f "$COMPOSE_FILE" "${args[@]}"
}

# ---------------------------------------------------------------------------
# `reset` subcommand.
#
# `down --volumes` followed by `up` with the profile set most recently used.
# Falls back to `--profile all` when `.last-profiles` is absent.
# ---------------------------------------------------------------------------
cmd_reset_help() {
    cat <<'EOF'
docs-test.sh reset — `down --volumes` then `up` with the last-used profiles.

Usage:
  docs-test.sh reset [--help]

Reads `scripts/docs-test/.last-profiles` (written by `up`). When absent,
defaults to `--profile all`.
EOF
}

cmd_reset() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help | -h)
                cmd_reset_help
                return 0
                ;;
            *)
                die "reset: unknown argument: $1"
                ;;
        esac
    done

    cmd_down --volumes

    load_last_profiles
    # Replay via cmd_up to inherit its sqlite special-casing.
    local replay_args=()
    for p in "${PARSED_PROFILES[@]}"; do
        replay_args+=(--profile "$p")
    done
    cmd_up "${replay_args[@]}"
}

# ---------------------------------------------------------------------------
# `exec` subcommand.
#
# Passthrough to `docker compose exec <service> <argv...>`. The `--`
# terminator preserves quoting so users can write
#   docs-test.sh exec postgres -- psql -c "SELECT 1"
# without wrestling shell escaping.
#
# source: argument-handling convention — `--` ends option parsing per
#         POSIX utility syntax guidelines
# ---------------------------------------------------------------------------
cmd_exec_help() {
    cat <<'EOF'
docs-test.sh exec — run a command in a running service container.

Usage:
  docs-test.sh exec <service> -- <cmd> [args...]

Examples:
  docs-test.sh exec postgres -- psql -U fraiseql -d fraiseql -c "SELECT 1"
  docs-test.sh exec redis -- redis-cli ping
  docs-test.sh exec fraiseql -- /app/fraiseql-server --version

The `--` is required and terminates docs-test.sh's own argument parsing.
Everything after `--` is passed verbatim to `docker compose exec`.
EOF
}

cmd_exec() {
    local service=""
    local saw_double_dash=0
    local cmd=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --help | -h)
                if [ "$saw_double_dash" -eq 0 ]; then
                    cmd_exec_help
                    return 0
                fi
                cmd+=("$1")
                shift
                ;;
            --)
                saw_double_dash=1
                shift
                # Consume the rest verbatim.
                while [ $# -gt 0 ]; do
                    cmd+=("$1")
                    shift
                done
                ;;
            *)
                if [ -z "$service" ]; then
                    service="$1"
                else
                    cmd+=("$1")
                fi
                shift
                ;;
        esac
    done

    [ -n "$service" ] || die "exec: <service> is required (see --help)"
    [ ${#cmd[@]} -gt 0 ] || die "exec: a command after \`--\` is required (see --help)"

    load_env
    docker compose -f "$COMPOSE_FILE" exec "$service" "${cmd[@]}"
}

# ---------------------------------------------------------------------------
# `status` subcommand.
#
# Header section first (working tree path, branch, commit, frozen SHA vs
# ~/code/fraiseql HEAD), then `docker compose ps` output augmented with
# host port mappings.
# ---------------------------------------------------------------------------
cmd_status_help() {
    cat <<'EOF'
docs-test.sh status — operator-facing health summary.

Usage:
  docs-test.sh status [--help]

Prints:
  - working tree path, branch, short commit SHA
  - frozen FraiseQL SHA (from scripts/docs-test/FRAISEQL_SHA) vs.
    ~/code/fraiseql HEAD; flags mismatch
  - docker compose ps output (service, status, health, ports)
EOF
}

# Helper: detect ~/code/fraiseql HEAD without erroring if missing.
fraiseql_head() {
    local fraiseql_dir="${HOME}/code/fraiseql"
    if [ -d "$fraiseql_dir/.git" ] || [ -f "$fraiseql_dir/.git" ]; then
        (cd "$fraiseql_dir" && git rev-parse HEAD 2>/dev/null) || printf '(unavailable)\n'
    else
        printf '(not found at %s)\n' "$fraiseql_dir"
    fi
}

# Helper: read the frozen SHA file gracefully when absent.
frozen_sha() {
    if [ -f "$FRAISEQL_SHA_FILE" ]; then
        # Strip whitespace; the file may contain a trailing newline.
        tr -d '[:space:]' <"$FRAISEQL_SHA_FILE"
    else
        printf '(unset -- set in phase 00 cycle 9)'
    fi
}

cmd_status() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help | -h)
                cmd_status_help
                return 0
                ;;
            *)
                die "status: unknown argument: $1"
                ;;
        esac
    done

    load_env

    local tree_path branch short_commit frozen head
    tree_path="$(cd "$HERE/../.." && pwd)"
    branch="$(git -C "$tree_path" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '(no git)')"
    short_commit="$(git -C "$tree_path" rev-parse --short HEAD 2>/dev/null || printf '(no git)')"
    frozen="$(frozen_sha)"
    head="$(fraiseql_head)"

    local mismatch_flag="(matched)"
    case "$frozen" in
        '(unset -- set in phase 00 cycle 9)')
            mismatch_flag="(frozen SHA unset; comparison skipped)"
            ;;
        *)
            if [ "$frozen" != "$head" ]; then
                mismatch_flag="MISMATCH"
            fi
            ;;
    esac

    cat <<EOF
================================================================================
 FraiseQL docs-test harness — status
================================================================================
 Working tree     : $tree_path
 Branch           : $branch
 Commit (short)   : $short_commit
 Frozen SHA       : $frozen
 ~/code/fraiseql  : $head
 SHA comparison   : $mismatch_flag
--------------------------------------------------------------------------------
EOF

    # docker compose ps prints a table including STATUS and PORTS.
    # source: https://docs.docker.com/reference/cli/docker/compose/ps/
    # Always enumerate every profile so storage / fraiseql / sqlite show up
    # if they're running.
    docker compose -f "$COMPOSE_FILE" \
        --profile all --profile storage --profile fraiseql --profile sqlite \
        ps
}

# ---------------------------------------------------------------------------
# `logs` subcommand.
#
# Passthrough to `docker compose logs <service>` with --follow → -f.
# When --follow is set we trap SIGINT/SIGTERM to terminate the underlying
# `docker compose logs -f` process group cleanly and exit 0 (so Ctrl-C
# during follow returns success rather than 130).
# ---------------------------------------------------------------------------
cmd_logs_help() {
    cat <<'EOF'
docs-test.sh logs — tail or follow logs from a service.

Usage:
  docs-test.sh logs <service> [--follow] [--help]

Options:
  --follow, -f    Stream new log lines until interrupted. Ctrl-C exits 0.
  --help          Show this help.

Examples:
  docs-test.sh logs fraiseql
  docs-test.sh logs postgres --follow
EOF
}

cmd_logs() {
    local service=""
    local follow=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --help | -h)
                cmd_logs_help
                return 0
                ;;
            --follow | -f)
                follow=1
                shift
                ;;
            *)
                if [ -z "$service" ]; then
                    service="$1"
                    shift
                else
                    die "logs: unexpected argument: $1"
                fi
                ;;
        esac
    done

    [ -n "$service" ] || die "logs: <service> is required (see --help)"

    load_env

    if [ "$follow" -eq 1 ]; then
        # Run `docker compose logs -f` in the foreground so it shares the
        # script's controlling terminal and process group.  An interactive
        # Ctrl-C therefore hits the whole group at once (kernel-delivered
        # SIGINT to every member), which is the standard, robust teardown
        # path — no manual signal forwarding needed and no orphans.
        #
        # `set +e` lets us capture the child's non-zero signal-exit; we
        # then translate "killed by SIGINT/SIGTERM" → exit 0 so Ctrl-C
        # during follow returns success per cycle-spec constraint #7.
        local rc=0
        set +e
        docker compose -f "$COMPOSE_FILE" logs -f "$service"
        rc=$?
        set -e
        # 130 = killed by SIGINT, 143 = killed by SIGTERM.  Treat both as
        # graceful interruption of an unbounded follow.
        if [ "$rc" -eq 130 ] || [ "$rc" -eq 143 ] || [ "$rc" -eq 0 ]; then
            return 0
        fi
        return "$rc"
    else
        docker compose -f "$COMPOSE_FILE" logs "$service"
    fi
}

# ---------------------------------------------------------------------------
# `sha` subcommand.
#
# Print ~/code/fraiseql HEAD vs the frozen SHA file. Exit 0 if they match
# or if the file is absent (the latter is the pre-Cycle-9 state); exit 1
# when both are present and differ.
#
# source: _internal/.plan/.phases/phase-00-foundation.md § Cycle 9
# ---------------------------------------------------------------------------
cmd_sha_help() {
    cat <<'EOF'
docs-test.sh sha — compare ~/code/fraiseql HEAD against the frozen SHA.

Usage:
  docs-test.sh sha [--help]

Exit codes:
  0   SHAs match, or the frozen SHA file does not yet exist (pre-Cycle-9).
  1   Both present but different (loud warning printed).

The frozen SHA file is `scripts/docs-test/FRAISEQL_SHA`. It is created in
Phase 00 Cycle 9.
EOF
}

cmd_sha() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help | -h)
                cmd_sha_help
                return 0
                ;;
            *)
                die "sha: unknown argument: $1"
                ;;
        esac
    done

    local head frozen
    head="$(fraiseql_head)"
    if [ ! -f "$FRAISEQL_SHA_FILE" ]; then
        printf 'docs-test sha: ~/code/fraiseql HEAD = %s\n' "$head"
        printf 'docs-test sha: frozen SHA file absent (created in phase 00 cycle 9)\n'
        return 0
    fi
    frozen="$(frozen_sha)"

    printf 'docs-test sha: frozen SHA          = %s\n' "$frozen"
    printf 'docs-test sha: ~/code/fraiseql HEAD = %s\n' "$head"

    if [ "$frozen" = "$head" ]; then
        printf 'docs-test sha: OK (matched)\n'
        return 0
    fi

    cat >&2 <<EOF
================================================================================
 docs-test sha: WARNING — SHA DRIFT DETECTED
================================================================================
 The local ~/code/fraiseql checkout has diverged from the frozen
 FraiseQL SHA that this docs-test harness validates against.

 frozen : $frozen
 HEAD   : $head

 Implications:
   - Source citations on docs pages may reference line numbers that no
     longer match HEAD.
   - Reproductions may pass or fail for reasons unrelated to the docs
     change under review.

 Action:
   - Either check out the frozen SHA in ~/code/fraiseql, or
   - File a G2 SHA-bump proposal in _internal/.plan/handoff.md.
================================================================================
EOF
    return 1
}

# ---------------------------------------------------------------------------
# Top-level help.
# ---------------------------------------------------------------------------
cmd_help() {
    cat <<'EOF'
docs-test.sh — FraiseQL docs-test harness operator CLI.

Usage:
  docs-test.sh <subcommand> [args...]

Subcommands:
  up        Boot harness services. Default --profile all.
  down      Tear down across ALL profiles. --volumes wipes data.
  reset     down --volumes then up with the last-used profile set.
  exec      Run a command in a service container.
              docs-test.sh exec <service> -- <cmd> [args...]
  status    Operator-facing health summary (working tree, frozen SHA, ps).
  logs      Tail or follow logs. --follow exits 0 on Ctrl-C.
  sha       Compare ~/code/fraiseql HEAD vs. the frozen SHA file.

Run `docs-test.sh <subcommand> --help` for per-subcommand options.

Notes:
  - MSSQL needs ~2 GB RAM and ~10–30 s to become healthy.
  - `--profile sqlite` triggers `docker compose run --rm sqlite-init` rather
    than `up --wait` (sqlite-init is a one-shot, exits 0).
  - `down` always enumerates all profiles to avoid storage / fraiseql
    containers being left running (Compose v2 design).
EOF
    cat <<EOF

Known profiles:
  ${KNOWN_PROFILES[*]}

Resources:
  Compose file : $COMPOSE_FILE
  Env file     : $ENV_FILE (optional; example at $ENV_EXAMPLE)
  Frozen SHA   : $FRAISEQL_SHA_FILE (created in phase 00 cycle 9)
EOF
}

# ---------------------------------------------------------------------------
# Dispatch.
# ---------------------------------------------------------------------------
main() {
    if [ $# -eq 0 ]; then
        cmd_help
        return 0
    fi

    local sub="$1"
    shift
    case "$sub" in
        --help | -h | help)
            cmd_help
            ;;
        up) cmd_up "$@" ;;
        down) cmd_down "$@" ;;
        reset) cmd_reset "$@" ;;
        exec) cmd_exec "$@" ;;
        status) cmd_status "$@" ;;
        logs) cmd_logs "$@" ;;
        sha) cmd_sha "$@" ;;
        *)
            err "unknown subcommand: $sub"
            err "run \`docs-test.sh --help\` for usage"
            return 2
            ;;
    esac
}

main "$@"
