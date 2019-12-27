defmodule HistoriaLiveWeb.ResumeController do
  use HistoriaLiveWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html", layout: {HistoriaLiveWeb.LayoutView, "resume.html"})
  end
end
