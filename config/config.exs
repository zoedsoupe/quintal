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
# NOTE: partial wildcards (place.quintal.canto.*) are invalid per the
# atproto permission spec; each collection must be listed explicitly.
# Blob upload is a separate permission from repo: without blob:,
# com.atproto.repo.uploadBlob answers 403 (mirror of the lexicon accept).
config :quintal, Quintal.Auth.ProtoRune,
  scope:
    "atproto repo:place.quintal.feed.prosa repo:place.quintal.canto.config repo:place.quintal.canto.blogroll repo:place.quintal.canto.depoimento repo:place.quintal.canto.recado repo:place.quintal.graph.follow blob:image/jpeg blob:image/png blob:image/webp"

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

# pt-br primeiro (spec 2): erros de changeset chegam em portugues
config :quintal, QuintalWeb.Gettext, default_locale: "pt_BR"

# Hosts que o router atende: o app mora em quintal.blog.br e a
# documentação dos lexicons em quintal.place. Dev e test sobrescrevem
# com hosts locais, senão nada casa fora de produção.
config :quintal, QuintalWeb.Router,
  app_hosts: ["quintal.blog.br"],
  docs_hosts: ["quintal.place"]

config :quintal, :env, config_env()

# Quem funda o quintal entra sem convite: a portaria do alpha fecha para
# cara nova, nunca para as fundadoras (spec 6.1).
config :quintal, :fundadoras, ["did:plc:4rt5dyqvarrbolr7qmfcbcsm"]

config :quintal,
  ecto_repos: [Quintal.Repo],
  generators: [timestamp_type: :utc_datetime]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
