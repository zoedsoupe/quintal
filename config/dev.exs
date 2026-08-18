import Config

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# AT Protocol OAuth. In dev the client metadata URL must be publicly
# reachable, so point these at a tunnel (e.g. cloudflared) when testing
# the real flow.
config :quintal, Quintal.Auth.ProtoRune,
  client_id: "http://localhost:4000/oauth/client-metadata.json",
  redirect_uri: "http://localhost:4000/oauth/callback"

# Configure your database
config :quintal, Quintal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "quintal_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :quintal, QuintalWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {0, 0, 0, 0}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "qWnqR1XSm+iVAiYLfWUDwqMby+dj+H6Hfupcqcq7yAeDsg0GjoOaz6o44pCmXr9q",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:quintal, ~w(--sourcemap=inline --watch)]}
  ]

# Dev-only key for encrypting sessions at rest. Prod reads
# QUINTAL_SESSION_KEY (see runtime.exs).
config :quintal, :session_key, Base.decode64!("0UfHQYaT13xaFUSbU9DrxGFwV8pNO62OHDqSNYapikw=")

# Enable dev routes for dashboard and mailbox
config :quintal, dev_routes: true
