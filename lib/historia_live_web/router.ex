defmodule HistoriaLiveWeb.Router do
  use HistoriaLiveWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HistoriaLiveWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/cv", PageController, :cv
    get "/contact", PageController, :contact
    post "/send", PageController, :send
    resources "/posts", PostController, only: [:index, :show]
    resources "/resume", ResumeController, only: [:index]
  end

  # Other scopes may use custom stacks.
  # scope "/api", HistoriaLiveWeb do
  #   pipe_through :api
  # end
end
