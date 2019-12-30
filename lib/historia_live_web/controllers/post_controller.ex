defmodule HistoriaLiveWeb.PostController do
  use HistoriaLiveWeb, :controller

  def index(conn, _params) do
    posts = HistoriaLive.PostRepo.all() |> HistoriaLive.PostRepo.order_by_datetime()
    render(conn, "index.html", posts: posts)
  end

  def show(conn, %{"id" => id}) do
    case HistoriaLive.PostRepo.get(id) do
      {:ok, post} ->
        render(conn, "show.html", post: post)

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> put_view(HistoriaLiveWeb.ErrorView)
        |> render("404.html")
    end
  end
end
