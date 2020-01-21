defmodule HistoriaLiveWeb.AcmeChallengeController do
  use HistoriaLiveWeb, :controller

  def show(conn, %{"challenge" => "kSBz8Vte72Thjrs-OVT2KtkUDHD-fAaoXarhCZ7YI-Y"}) do
    send_resp(
      conn,
      200,
      "kSBz8Vte72Thjrs-OVT2KtkUDHD-fAaoXarhCZ7YI-Y.wPrdeMqRvx_fVbZozhwbDA0ubsNFMCpAK2g4GBp1_Pc"
    )
  end

  def show(conn, _) do
    send_resp(conn, 200, "Not valid")
  end
end
