defmodule HistoriaLiveWeb.PageController do
  use HistoriaLiveWeb, :controller

  def index(conn, _params) do
    post = HistoriaLive.PostRepo.all() |> HistoriaLive.PostRepo.order_by_datetime() |> Enum.at(0)
    render(conn, "index.html", post: post)
  end

  def cv(conn, _params) do
    path = Application.app_dir(:historia_live, "priv/static/cv.pdf")
    send_download(conn, {:file, path})
  end
end
