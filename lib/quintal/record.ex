defmodule Quintal.Record do
  @moduledoc """
  Leitura de record cru do atproto: chaves atom quando vem do XRPC,
  string quando vem da escrita otimista ou da firehose. Todos os
  indexadores precisam das duas pontas, então a tradução mora aqui.
  """

  @doc "O valor da chave, em atom ou string. `nil` quando não está."
  def campo(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  def campo(_outro, _key), do: nil

  @doc "O `createdAt`/`updatedAt` do record como `DateTime`. `nil` quando não está ou não parseia."
  def parse_datetime(nil), do: nil

  def parse_datetime(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end

  def parse_datetime(_outro), do: nil
end
