defmodule HistoriaLiveWeb.PageController do
  alias HistoriaLive.Mailer
  use HistoriaLiveWeb, :controller

  def index(conn, _params) do
    post = HistoriaLive.PostRepo.all() |> HistoriaLive.PostRepo.order_by_datetime() |> Enum.at(0)
    render(conn, "index.html", post: post)
  end

  def cv(conn, params) do
    path = Application.app_dir(:historia_live, "priv/static/cv_#{params["lang"]}.pdf")

    if File.exists?(path) do
      send_download(conn, {:file, path})
    else
      conn
      |> put_flash(:error, "No CV found!")
      |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  def contact(conn, _params) do
    render(conn, "contact.html")
  end

  def send(conn, params) do
    contact = params["contact"]

    case ExCSSCaptcha.validate_captcha(contact) do
      true ->
        Mail.ContactMail.contact_email(
          contact["email"],
          contact["name"],
          contact["subject"],
          contact["content"]
        )
        |> Mailer.deliver_later()

        conn
        |> put_flash(:info, "Tommaso will receive your message shortly. Thanks!")
        |> redirect(to: Routes.page_path(conn, :contact))

      false ->
        conn
        |> put_flash(:error, "Captcha validation failed!")
        |> redirect(to: Routes.page_path(conn, :contact))
    end
  end
end
