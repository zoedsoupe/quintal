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

    get "/", PageController, :home
    get "/oauth/callback", OAuthController, :callback
  end

  scope "/", QuintalWeb do
    pipe_through :api

    get "/oauth/client-metadata.json", OAuthController, :client_metadata
  end
end
