defmodule Quintal.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :quintal

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Gera `n` códigos de convite avulsos da portaria e imprime um por linha.

  Chamável pelo remote console em produção, onde `mix` não existe (spec
  6.1). O repositório sobe sob demanda, como no `migrate`.
  """
  def convites_gerar(n \\ 1) do
    load_app()

    {:ok, _, codigos} =
      Ecto.Migrator.with_repo(Quintal.Repo, fn _repo ->
        for _ <- 1..n do
          {:ok, convite} = Quintal.Convites.gerar("admin")
          convite.codigo
        end
      end)

    Enum.each(codigos, &IO.puts/1)
  end

  @doc """
  Revoga um convite ainda não usado (spec 6.1).

  Chamável pelo remote console. Um código já usado não é revogável: a
  entrada já aconteceu.
  """
  def revogar_convite(codigo) when is_binary(codigo) do
    load_app()

    {:ok, _, resultado} =
      Ecto.Migrator.with_repo(Quintal.Repo, fn _repo -> Quintal.Convites.revogar(codigo) end)

    case resultado do
      :ok -> IO.puts("convite #{codigo} revogado")
      {:error, :invalido} -> IO.puts(:stderr, "código inexistente ou já usado: #{codigo}")
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
