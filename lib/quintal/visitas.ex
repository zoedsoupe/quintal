defmodule Quintal.Visitas do
  @moduledoc """
  As notificações quietas (spec 7.5; marco m3): uma página visitas com o
  resumo desde a última passada. Sem badges vermelhos, sem contagens
  permanentes, sem push, sem email. Alguém passou aqui, só isso.

  Tudo é estado local do appview: os eventos nascem das indexações
  (`Quintal.Recados`, `Quintal.Depoimentos`, `Quintal.Prosas`,
  `Quintal.Follows`) e dedupam pela tripla `(tipo, ref_uri, autor_did)`,
  então a escrita otimista e o eco do firehose contam uma vez só.

  A `leitura` é a exceção voluntária: nunca rastreamos quem lê. O
  leitor marca a prosa como lida na página de leitura, se quiser, e só
  então a visita chega para quem escreveu.

  O resumo zera a cada visita: `marcar_lido/1` sobe a marca e
  `resumo/1` conta só o que veio depois.
  """

  import Ecto.Query

  alias Quintal.Repo
  alias Quintal.VisitaEvento
  alias Quintal.VisitaLidoEm

  require Logger

  @tipos ~w(recado resposta novo_leitor depoimento leitura)

  @doc """
  Registra um evento de visita no canto de `dono_did`.

  Idempotente por `(tipo, ref_uri, autor_did)`: chamar de novo com a
  mesma tripla não duplica. Visita da própria pessoa no próprio canto
  nunca registra.
  """
  @spec registrar(dono_did :: String.t(), tipo :: String.t(), ref_uri :: String.t(), autor_did :: String.t()) ::
          :ok | {:error, Ecto.Changeset.t()}
  def registrar(did, _tipo, _ref_uri, did), do: :ok

  def registrar(dono_did, tipo, ref_uri, autor_did) when tipo in @tipos do
    %VisitaEvento{}
    |> VisitaEvento.changeset(%{
      dono_did: dono_did,
      tipo: tipo,
      ref_uri: ref_uri,
      autor_did: autor_did,
      created_at: DateTime.utc_now()
    })
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:tipo, :ref_uri, :autor_did])
    |> case do
      {:ok, _evento} ->
        :ok

      {:error, changeset} ->
        Logger.warning("[#{__MODULE__}] evento #{tipo} #{ref_uri} fora do índice: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc "O resumo desde a última passada: quantos eventos de cada tipo."
  @spec resumo(did :: String.t()) :: %{
          recado: non_neg_integer(),
          resposta: non_neg_integer(),
          novo_leitor: non_neg_integer(),
          depoimento: non_neg_integer(),
          leitura: non_neg_integer()
        }
  def resumo(did) do
    contagens =
      from(e in VisitaEvento,
        where: e.dono_did == ^did and e.created_at > ^visto_em(did),
        group_by: e.tipo,
        select: {e.tipo, count(e.id)}
      )
      |> Repo.all()
      |> Map.new()

    Map.new(@tipos, fn tipo -> {String.to_atom(tipo), Map.get(contagens, tipo, 0)} end)
  end

  @doc "Os eventos desde a última passada, do mais novo para o mais antigo, com a identidade de quem passou."
  @spec eventos_desde_ultima(did :: String.t()) :: [VisitaEvento.t()]
  def eventos_desde_ultima(did) do
    Repo.all(
      from e in VisitaEvento,
        where: e.dono_did == ^did and e.created_at > ^visto_em(did),
        order_by: [desc: e.created_at],
        preload: [:autor]
    )
  end

  @doc "Marca a página visitas como lida agora: o resumo zera."
  @spec marcar_lido(did :: String.t()) :: :ok | {:error, Ecto.Changeset.t()}
  def marcar_lido(did) do
    %VisitaLidoEm{}
    |> VisitaLidoEm.changeset(%{dono_did: did, visto_em: DateTime.utc_now()})
    |> Repo.insert(on_conflict: {:replace, [:visto_em]}, conflict_target: :dono_did)
    |> case do
      {:ok, _lido_em} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc "Tem novidade desde a última passada? (a bolinha lilás da navegação)"
  @spec novidade?(did :: String.t()) :: boolean()
  def novidade?(did) do
    Repo.exists?(from e in VisitaEvento, where: e.dono_did == ^did and e.created_at > ^visto_em(did))
  end

  @doc "Essa pessoa já deixou visita nessa prosa?"
  @spec leitura_marcada?(ref_uri :: String.t(), autor_did :: String.t()) :: boolean()
  def leitura_marcada?(ref_uri, autor_did) do
    Repo.exists?(
      from e in VisitaEvento,
        where: e.tipo == "leitura" and e.ref_uri == ^ref_uri and e.autor_did == ^autor_did
    )
  end

  defp visto_em(did) do
    case Repo.get(VisitaLidoEm, did) do
      %VisitaLidoEm{visto_em: visto_em} -> visto_em
      nil -> DateTime.from_unix!(0)
    end
  end
end
