defmodule HistoriaLiveWeb.PageController do
  use HistoriaLiveWeb, :controller

  def index(conn, _params) do
    post = HistoriaLive.PostRepo.all() |> HistoriaLive.PostRepo.order_by_datetime() |> Enum.at(0)
    render(conn, "index.html", post: post)
  end
end
