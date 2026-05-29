#compdef docs-test.sh
# docs-test.zsh — Zsh completion for docs-test.sh.
#
# How to source me:
#   source scripts/docs-test/completions/docs-test.zsh
# (or symlink into one of your $fpath dirs as `_docs-test.sh`.)
#
# Provides:
#   - subcommand completion (up, down, reset, exec, status, logs, sha)
#   - --profile <p> completion against the known profile set
#   - per-subcommand flag completion (--volumes, --follow, --wait-timeout)
#
# Profile set kept in sync (by hand) with the KNOWN_PROFILES array in
# docs-test.sh and the `profiles:` entries in docker-compose.docs-test.yml.

_docs_test() {
    local -a subcommands profiles services
    subcommands=(
        'up:Boot harness services (default --profile all)'
        'down:Tear down across ALL profiles'
        'reset:down --volumes then up with last-used profiles'
        'exec:Run a command in a service container'
        'status:Operator-facing health summary'
        'logs:Tail or follow logs for a service'
        'sha:Compare ~/code/fraiseql HEAD vs. the frozen SHA'
        'help:Show top-level help'
    )
    profiles=(all postgres mysql sqlite mssql redis nats fraiseql storage)
    services=(postgres mysql sqlite-init mssql redis nats fraiseql minio minio-init azurite azurite-init fake-gcs)

    # Subcommand position.
    if (( CURRENT == 2 )); then
        _describe -t subcommands 'docs-test subcommand' subcommands
        _values 'top-level options' '--help[Show top-level help]'
        return
    fi

    local sub="${words[2]}"
    case "$sub" in
        up)
            _arguments \
                '*--profile=[Profile to boot (repeatable, comma-separated)]:profile:(all postgres mysql sqlite mssql redis nats fraiseql storage)' \
                '*--profile[Profile to boot (repeatable, comma-separated)]:profile:(all postgres mysql sqlite mssql redis nats fraiseql storage)' \
                '--wait-timeout[Healthcheck wait timeout in seconds]:seconds:' \
                '--help[Show up subcommand help]'
            ;;
        down)
            _arguments \
                '(--volumes -v)'{--volumes,-v}'[Also remove named volumes]' \
                '--help[Show down subcommand help]'
            ;;
        reset)
            _arguments '--help[Show reset subcommand help]'
            ;;
        exec)
            if (( CURRENT == 3 )); then
                _describe -t services 'service' services
            else
                _values 'exec options' '--[Terminate option parsing; pass remainder verbatim]' '--help[Show exec subcommand help]'
            fi
            ;;
        status)
            _arguments '--help[Show status subcommand help]'
            ;;
        logs)
            if (( CURRENT == 3 )); then
                _describe -t services 'service' services
            else
                _arguments \
                    '(--follow -f)'{--follow,-f}'[Stream new log lines]' \
                    '--help[Show logs subcommand help]'
            fi
            ;;
        sha)
            _arguments '--help[Show sha subcommand help]'
            ;;
    esac
}

_docs_test "$@"
