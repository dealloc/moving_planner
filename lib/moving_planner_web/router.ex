defmodule MovingPlannerWeb.Router do
  use MovingPlannerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MovingPlannerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MovingPlannerWeb do
    pipe_through :browser

    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/login", SessionController, :delete

    get "/data", DataController, :index
    get "/export", DataController, :export
    post "/import", DataController, :import
  end

  scope "/", MovingPlannerWeb do
    pipe_through :browser

    live_session :authenticated, on_mount: {MovingPlannerWeb.Auth, :require_auth} do
      live "/", DashboardLive, :index
      live "/boxes", BoxesLive.Index, :index
      live "/boxes/new", BoxesLive.Index, :new
      live "/boxes/:id", BoxesLive.Show, :show
      live "/boxes/:id/edit", BoxesLive.Show, :edit
      live "/items", ItemsLive.Index, :index
      live "/rooms", RoomsLive.Index, :index
      live "/todos", TodosLive.Index, :index
      live "/furniture", FurnitureLive.Index, :index
      live "/furniture/new", FurnitureLive.Index, :new
      live "/truck/depart", TruckLive, :depart
      live "/truck/arrive", TruckLive, :arrive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", MovingPlannerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:moving_planner, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MovingPlannerWeb.Telemetry
    end
  end
end
