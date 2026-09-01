server domain="pseudofamously-unkindled-yulanda.ngrok-free.dev":
    #!/usr/bin/env bash
    set -euo pipefail
    export QUINTAL_PUBLIC_HOST={{domain}}

    ngrok http 4000 --url={{domain}} > /dev/null 2>&1 &
    NGROK_PID=$!
    trap 'kill $NGROK_PID 2>/dev/null || true' EXIT

    sleep 2
    echo {{domain}}
    iex -S mix phx.server
