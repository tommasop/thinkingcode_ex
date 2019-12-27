defmodule HistoriaLive.Repo do
  use Ecto.Repo, otp_app: :historia_live, adapter: Ecto.Adapters.Postgres
  import Ecto.Query

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

  def last(queryable) do
    queryable |> order_by([r], {:desc, r.id}) |> all |> Enum.at(0)
  end
end
