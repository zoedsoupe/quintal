defmodule QuintalWeb.Router do
  use QuintalWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
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

    live_session :default do
      live "/", HomeLive
      live "/cadastro", CadastroLive
      live "/faq", FaqLive
      live "/conduta", CondutaLive
    end

    get "/oauth/login", OAuthController, :login
    get "/oauth/logout", OAuthController, :logout
    get "/oauth/callback", OAuthController, :callback
  end

  scope "/", QuintalWeb do
    pipe_through :api

    get "/oauth/client-metadata.json", OAuthController, :client_metadata
  end
end
