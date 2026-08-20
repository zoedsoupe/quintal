defmodule QuintalWeb.Router do
  use QuintalWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug QuintalWeb.TemaPlug
    plug :fetch_live_flash
    plug :put_root_layout, html: {QuintalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", QuintalWeb do
    pipe_through :browser

    live_session :default, on_mount: [QuintalWeb.SessaoHook] do
      live "/", HomeLive
      live "/cadastro", CadastroLive
      live "/convite", ConviteLive
      live "/faq", FaqLive
      live "/conduta", CondutaLive
    end

    # conteúdo do quintal: portaria fechada, só com sessão (spec 6.1)
    live_session :privado, on_mount: [{QuintalWeb.SessaoHook, :privado}] do
      live "/passear", PassearLive
      live "/canto/:handle/prosa/:rkey", ProsaLive
      live "/canto/:handle", CantoLive
      live "/visitas", VisitasLive
    end

    get "/oauth/login", OAuthController, :login
    get "/oauth/logout", OAuthController, :logout
    get "/oauth/callback", OAuthController, :callback
    post "/convite", ConviteController, :create
  end

  scope "/", QuintalWeb do
    pipe_through :api

    get "/oauth/client-metadata.json", OAuthController, :client_metadata
  end
end
