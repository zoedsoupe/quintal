defmodule QuintalWeb.Router do
  use QuintalWeb, :router

  # hosts atendidos por scope: produção usa os domínios do config.exs,
  # dev e test sobrescrevem com hosts locais
  @app_hosts Application.compile_env(:quintal, [__MODULE__, :app_hosts])
  @docs_hosts Application.compile_env(:quintal, [__MODULE__, :docs_hosts])

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug QuintalWeb.TemaPlug
    plug :fetch_live_flash
    plug :put_root_layout, html: {QuintalWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; img-src 'self' https: blob:; media-src 'self' https:; frame-src https://www.youtube-nocookie.com https://embed.music.apple.com https://open.spotify.com; style-src 'self' 'unsafe-inline'; connect-src 'self' ws: wss:"
    }
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :portaria do
    plug QuintalWeb.PortariaPlug
  end

  scope "/", QuintalWeb, host: @app_hosts do
    pipe_through :browser

    live_session :default, on_mount: [QuintalWeb.SessaoHook] do
      live "/", LandingLive
      live "/cadastro", CadastroLive
      live "/convite", ConviteLive
      live "/faq", FaqLive
      live "/conduta", CondutaLive
    end

    get "/oauth/login", OAuthController, :login
    post "/oauth/logout", OAuthController, :logout
    get "/oauth/callback", OAuthController, :callback
    post "/convite", ConviteController, :create
  end

  scope "/", QuintalWeb, host: @app_hosts do
    pipe_through [:browser, :portaria]

    # conteúdo do quintal: portaria fechada, só com sessão (spec 6.1)
    live_session :privado, on_mount: [{QuintalWeb.SessaoHook, :privado}] do
      live "/inicio", HomeLive
      live "/boas-vindas", BoasVindasLive
      live "/prosear", EscreverLive, :prosear
      live "/recadar", EscreverLive, :recado
      live "/passear", PassearLive
      live "/canto/:handle/prosa/:rkey", ProsaLive
      live "/canto/:handle", CantoLive
      live "/visitas", VisitasLive
      live "/conta", ContaLive
    end

    get "/conta/exportar", ContaController, :exportar
  end

  scope "/", QuintalWeb, host: @app_hosts do
    pipe_through :api

    get "/oauth/client-metadata.json", OAuthController, :client_metadata
  end

  # visão humana dos lexicons, no domínio público da documentação.
  # os json crus saem pelo Plug.Static em /lexicons/:nsid.json
  scope "/", QuintalWeb, host: @docs_hosts do
    pipe_through :browser

    get "/lexicons", LexiconsController, :index
    get "/lexicons/:nsid", LexiconsController, :show
  end
end
