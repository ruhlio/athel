defmodule Athel.Router do
  use Athel.Web, :router

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

  scope "/", Athel do
    pipe_through :browser

    get "/", PageController, :index

    scope "/groups" do
      get "/", GroupController, :index
      get "/:name", GroupController, :show
      post "/:name", GroupController, :create_topic

      get "/:group_name/articles/:message_id", ArticleController, :show
    end

    scope "/admin" do
      get "/new_group", AdminController, :new_group
      post "/new_group", AdminController, :create_group
    end
  end
end
