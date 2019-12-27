defmodule HistoriaLiveWeb.PageController do
  use HistoriaLiveWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
