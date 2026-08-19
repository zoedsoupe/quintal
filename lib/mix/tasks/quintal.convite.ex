defmodule Mix.Tasks.Quintal.Convite do
  @moduledoc """
  Gera códigos de convite avulsos da portaria (spec 6.1): sem cota,
  revogáveis enquanto não usados.

      mix quintal.convite          # gera 1 código
      mix quintal.convite 3        # gera 3 códigos
  """

  use Mix.Task

  @shortdoc "Gera códigos de convite da portaria"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    n = args |> List.first() |> then(&((&1 && String.to_integer(&1)) || 1))

    for _ <- 1..n do
      {:ok, convite} = Quintal.Convites.gerar("admin")
      Mix.shell().info(convite.codigo)
    end
  end
end
