import Config

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# proto_rune HTTP transport mocked at the adapter seam
config :proto_rune, :http_client, Quintal.HTTPMock

# Deterministic client metadata for the endpoint tests
config :quintal, Quintal.Auth.ProtoRune,
  client_id: "http://localhost:4002/oauth/client-metadata.json",
  redirect_uri: "http://localhost:4002/oauth/callback"

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :quintal, Quintal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "quintal_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :quintal, QuintalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "U8Jl/4Q7xjAy/DzE1Uj/K7RGrkfX7ZiICX/YpiYUxi+vDaW2dazDJ+J5MIsDVey1",
  server: false

# Swap the OAuth boundary for a mock
config :quintal, :auth_impl, Quintal.Auth.Mock

# Swap the pds boundary for a mock
config :quintal, :pds_impl, Quintal.PDS.Mock

# Test-only key for encrypting sessions at rest
config :quintal, :session_key, Base.decode64!("dTfyNvqfM/LPpCoRaSQvNDbDhh7wy3fJwBR8b8HNvdE=")
