defmodule QuintalWeb.TemaPlug do
  @moduledoc """
  Estampa o tema do canto da pessoa logada no `<html>` do root layout:
  o preset (papel, madrugada, gloss) vira `data-theme` e a cor de acento
  vira `--acento` inline, cascateando para todas as telas (spec 7.2).

  Papel não vira atributo: é o preset default e a lamparina
  (`prefers-color-scheme`) resolve a noite sozinha. Deslogada, nada.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn |> get_session("quintal_did") |> canto() do
      nil ->
        conn

      canto ->
        conn
        |> assign(:tema, if(canto.tema == "papel", do: nil, else: canto.tema))
        |> assign(:cor, canto.cor)
    end
  end

  defp canto(nil), do: nil
  defp canto(did), do: Quintal.Cantos.get(did)
end
