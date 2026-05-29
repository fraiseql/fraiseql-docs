# docs-test.bash — Bash completion for docs-test.sh.
#
# How to source me:
#   source scripts/docs-test/completions/docs-test.bash
#
# Provides:
#   - subcommand completion (up, down, reset, exec, status, logs, sha, help)
#   - --profile <p> completion against the known profile set
#   - --volumes / --follow / --help / --wait-timeout flag completion
#
# Profile set kept in sync (by hand) with the KNOWN_PROFILES array in
# docs-test.sh and the `profiles:` entries in docker-compose.docs-test.yml.

_docs_test_complete() {
    local cur prev words cword
    _init_completion -n =: 2>/dev/null || {
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    }

    local subcommands="up down reset exec status logs sha help --help"
    local profiles="all postgres mysql sqlite mssql redis nats fraiseql storage"
    local services="postgres mysql sqlite-init mssql redis nats fraiseql minio minio-init azurite azurite-init fake-gcs"

    # Position 1: the subcommand itself.
    if [ "$cword" -eq 1 ]; then
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "$subcommands" -- "$cur") )
        return 0
    fi

    local sub="${words[1]}"

    # --profile <TAB> → profile names
    case "$prev" in
        --profile)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "$profiles" -- "$cur") )
            return 0
            ;;
        --wait-timeout)
            COMPREPLY=()
            return 0
            ;;
    esac

    # Per-subcommand flags + service positionals.
    case "$sub" in
        up)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "--profile --wait-timeout --help" -- "$cur") )
            ;;
        down)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "--volumes -v --help" -- "$cur") )
            ;;
        reset)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "--help" -- "$cur") )
            ;;
        exec)
            # First positional after `exec` is a service name.
            if [ "$cword" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=( $(compgen -W "$services" -- "$cur") )
            else
                # shellcheck disable=SC2207
                COMPREPLY=( $(compgen -W "-- --help" -- "$cur") )
            fi
            ;;
        status)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "--help" -- "$cur") )
            ;;
        logs)
            if [ "$cword" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=( $(compgen -W "$services" -- "$cur") )
            else
                # shellcheck disable=SC2207
                COMPREPLY=( $(compgen -W "--follow -f --help" -- "$cur") )
            fi
            ;;
        sha)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "--help" -- "$cur") )
            ;;
    esac
}

# Wire the completion to both `docs-test.sh` (when invoked by basename in
# PATH) and the relative-path form `./scripts/docs-test/docs-test.sh`.
complete -F _docs_test_complete docs-test.sh
complete -F _docs_test_complete ./scripts/docs-test/docs-test.sh
