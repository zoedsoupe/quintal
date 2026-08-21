defmodule QuintalWeb.TemaPlug do
  @moduledoc """
  Estampa o tema do canto no `<html>` do root layout: o preset (papel,
  madrugada, gloss) vira `data-theme` e a cor de acento vira `--acento`
  inline, cascateando para todas as telas (spec 7.2).

  Na página `/canto/:handle` o tema é o do canto visitado, mesmo para
  quem só passa: a casa é do dono, quem visita vê a decoração dele.
  Nas demais telas vale o canto da pessoa logada. Papel não vira
  atributo: é o preset default e a lamparina (`prefers-color-scheme`)
  resolve a noite sozinha. Deslogada fora de canto, nada.
  """

  import Ecto.Query, only: [from: 2]
  import Plug.Conn

  alias Quintal.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    canto =
      case conn.path_info do
        ["canto", handle] -> canto_pelo_handle(handle)
        _ -> conn |> get_session("quintal_did") |> canto_do_dono()
      end

    conn
    |> assign(:tema, if(canto && canto.tema != "papel", do: canto.tema))
    |> assign(:cor, canto && canto.cor)
  end

  # uma query, sem preload: o plug roda em todo request e só precisa de
  # tema e cor (Cantos.get/1 traria a identidade junto, desperdiçada)
  defp canto_pelo_handle(handle) do
    Repo.one(
      from c in Quintal.Canto,
        join: i in Quintal.Identidade,
        on: i.did == c.dono_did,
        where: i.handle == ^handle,
        select: %{tema: c.tema, cor: c.cor}
    )
  end

  defp canto_do_dono(nil), do: nil

  defp canto_do_dono(did) do
    Repo.one(from c in Quintal.Canto, where: c.dono_did == ^did, select: %{tema: c.tema, cor: c.cor})
  end
end
