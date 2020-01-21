defmodule HistoriaLiveWeb.AcmeChallengeController do
  use HistoriaLiveWeb, :controller

  def show(conn, %{"challenge" => "xpgY_FedL8fBZAKAGdDXYU5MpcBYZsM9WM9WXGRWnQk"}) do
    send_resp(
      conn,
      200,
      "xpgY_FedL8fBZAKAGdDXYU5MpcBYZsM9WM9WXGRWnQk.wPrdeMqRvx_fVbZozhwbDA0ubsNFMCpAK2g4GBp1_Pc"
    )
  end

  def show(conn, _) do
    send_resp(conn, 200, "Not valid")
  end
end
