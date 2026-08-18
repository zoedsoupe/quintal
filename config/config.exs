import Config

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  quintal: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, JSON

# Configure LiveView
# the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
config :phoenix_live_view, root_tag_attribute: "phx-r"

# AT Protocol OAuth, shared parts. client_id and redirect_uri are set
# per environment. Scope stays restricted to the place.quintal.*
# collections: never broad atproto access, never Bluesky collections.
config :quintal, Quintal.Auth.ProtoRune,
  scope: "atproto repo:place.quintal.feed.prosa repo:place.quintal.canto.* repo:place.quintal.graph.follow"

# Configure the endpoint
config :quintal, QuintalWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: QuintalWeb.ErrorHTML, json: QuintalWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Quintal.PubSub,
  live_view: [signing_salt: "wCdIpsWV"]

config :quintal,
  ecto_repos: [Quintal.Repo],
  generators: [timestamp_type: :utc_datetime]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
