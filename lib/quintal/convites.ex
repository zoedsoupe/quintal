defmodule Quintal.Convites do
  @moduledoc """
  A portaria do alpha fechado (spec 6; marco m4).

  Todo convite é um código único: um código, uma entrada, um uso. Cada
  pessoa convidada pode gerar até 5 códigos (`cota/0`), e só depois de
  ter o próprio canto (o bootstrap do login cria o canto.config antes).
  A portaria (`"admin"`) gera códigos avulsos sem cota, pelo mix task
  `mix quintal.convite`.

  O contador é derivado (spec 6.2): convites restantes = 5 menos os já
  usados, contados por `criado_por`. Códigos gerados e ainda não usados
  não descontam da cota.
  """

  import Ecto.Query

  alias Quintal.Convite
  alias Quintal.Repo

  @cota 5
  @admin "admin"

  # alfabeto sem ambíguos (0/o, 1/l): código se escreve à mão num recado
  @alfabeto ~c"abcdefghjkmnpqrstuvwxyz23456789"

  @doc "A cota de convites por pessoa (spec 6.1)."
  @spec cota() :: non_neg_integer()
  def cota, do: @cota

  @doc "A pessoa funda o quintal? Fundadora entra sem convite e gera sem cota."
  @spec fundadora?(did :: String.t()) :: boolean()
  def fundadora?(did) do
    did in Application.get_env(:quintal, :fundadoras, [])
  end

  @doc """
  Gera um código novo para `criado_por` (did ou `"admin"`).

  Pessoa comum respeita a cota de 5 usados; `"admin"` e fundadoras são sempre livres.
  """
  @spec gerar(criado_por :: String.t()) :: {:ok, Convite.t()} | {:error, :cota_esgotada | Ecto.Changeset.t()}
  def gerar(@admin), do: inserir(@admin)

  def gerar(criado_por) do
    if fundadora?(criado_por) or restantes(criado_por) > 0 do
      inserir(criado_por)
    else
      {:error, :cota_esgotada}
    end
  end

  @doc "Os convites ainda disponíveis na cota da pessoa (5 menos os usados)."
  @spec restantes(criado_por :: String.t()) :: non_neg_integer()
  def restantes(criado_por) do
    usados =
      Repo.one(
        from c in Convite,
          where: c.criado_por == ^criado_por and not is_nil(c.usado_por),
          select: count(c.codigo)
      )

    max(@cota - usados, 0)
  end

  @doc "Os códigos gerados pela pessoa ainda não usados, do mais novo para o mais antigo."
  @spec disponiveis(criado_por :: String.t()) :: [Convite.t()]
  def disponiveis(criado_por) do
    Repo.all(
      from c in Convite,
        where: c.criado_por == ^criado_por and is_nil(c.usado_por),
        order_by: [desc: c.criado_em]
    )
  end

  @doc "O código existe e ainda não foi usado?"
  @spec valido?(codigo :: String.t()) :: boolean()
  def valido?(codigo) when is_binary(codigo) do
    Repo.exists?(from c in Convite, where: c.codigo == ^codigo and is_nil(c.usado_por))
  end

  @doc """
  A pessoa já mora no quintal? (identidade indexada ou convite já usado
  por ela).

  A checagem do convite cobre a janela entre o primeiro login e o
  bootstrap assíncrono indexar a identidade: sem ela, o segundo acesso
  cairia no gate de novo com o código já queimado.
  """
  @spec entrou?(did :: String.t()) :: boolean()
  def entrou?(did) do
    Repo.exists?(from i in Quintal.Identidade, where: i.did == ^did) or
      Repo.exists?(from c in Convite, where: c.usado_por == ^did)
  end

  @doc """
  Marca o código como usado por `did`.

  Atômico via update condicional: dois primeiros acessos simultâneos com
  o mesmo código não entram juntos.
  """
  @spec usar(codigo :: String.t(), did :: String.t()) :: :ok | {:error, :invalido}
  def usar(codigo, did) do
    {n, _} =
      Repo.update_all(
        from(c in Convite, where: c.codigo == ^codigo and is_nil(c.usado_por)),
        set: [usado_por: did, usado_em: DateTime.utc_now()]
      )

    if n == 1, do: :ok, else: {:error, :invalido}
  end

  @doc "Revoga um código ainda não usado (portaria, spec 6.1)."
  @spec revogar(codigo :: String.t()) :: :ok | {:error, :invalido}
  def revogar(codigo) do
    {n, _} = Repo.delete_all(from c in Convite, where: c.codigo == ^codigo and is_nil(c.usado_por))
    if n == 1, do: :ok, else: {:error, :invalido}
  end

  defp inserir(criado_por) do
    %Convite{}
    |> Convite.changeset(%{codigo: codigo(), criado_por: criado_por, criado_em: DateTime.utc_now()})
    |> Repo.insert()
  end

  defp codigo do
    sufixo = for _ <- 1..4, into: "", do: <<Enum.random(@alfabeto)>>
    "axo-#{sufixo}"
  end
end
