defmodule Quintal.FirehoseCursor do
  @moduledoc """
  Uma linha só: a posição do consumidor no firehose (spec 8.4).

  Persistida em disco para o reconnect de boot retomar de onde parou,
  em vez de reler a janela inteira do relay (spec 9.5).
  """

  use Ecto.Schema

  @primary_key {:id, :integer, []}
  schema "firehose_cursor" do
    field :cursor, :integer
  end
end
