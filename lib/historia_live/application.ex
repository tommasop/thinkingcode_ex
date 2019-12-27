defmodule HistoriaLive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(HistoriaLive.Repo, []),
      # Start the endpoint when the application starts
      supervisor(HistoriaLiveWeb.Endpoint, [])
      # Start your own worker by calling: Connect.Worker.start_link(arg1, arg2, arg3)
      # worker(Connect.Worker, [arg1, arg2, arg3]),
      #      {ConCache,
      #       [name: :token_cache, ttl_check_interval: :timer.minutes(20), global_ttl: :timer.hours(1)]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HistoriaLive.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    HistoriaLiveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
