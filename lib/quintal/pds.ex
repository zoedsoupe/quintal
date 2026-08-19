defmodule Quintal.PDS do
  @moduledoc """
  Fronteira XRPC com o pds da pessoa (spec 9.3 e 9.4).

  Toda leitura e escrita de records `place.quintal.*` passa por aqui.
  As escritas validam o record contra o lexicon local antes de sair
  (`Quintal.Lexicon`): falhar cedo, falhar em casa.

  Records trafegam como mapas de chaves string, no formato do lexicon
  (`"text"`, `"createdAt"`). Respostas do pds chegam decodificadas com
  chaves atom snakelized (`%{uri:, cid:, value:}`), cortesia do
  `ProtoRune.XRPC.Client`.
  """

  @typedoc "Sessão OAuth atproto da pessoa, com did e service_url do pds."
  @type session :: ProtoRune.Atproto.OAuth.Session.t()

  @type pds_record :: %{String.t() => term()}
  @type error :: {:error, term()}

  @doc "Busca um record por repo, coleção e rkey."
  @callback get_record(session(), repo :: String.t(), collection :: String.t(), rkey :: String.t()) ::
              {:ok, map()} | error()

  @doc "Lista records de uma coleção. Opções: `:limit`, `:cursor`, `:reverse`."
  @callback list_records(session(), repo :: String.t(), collection :: String.t(), opts :: keyword()) ::
              {:ok, map()} | error()

  @doc "Cria um record (rkey tid gerado pelo pds). Valida contra o lexicon antes."
  @callback create_record(session(), collection :: String.t(), pds_record()) ::
              {:ok, %{uri: String.t(), cid: String.t()}} | error()

  @doc """
  Escreve um record num rkey determinado (create ou update). Valida
  contra o lexicon antes. Opção `:swap_commit` para concorrência
  otimista (spec 9.4).
  """
  @callback put_record(
              session(),
              collection :: String.t(),
              rkey :: String.t(),
              pds_record(),
              opts :: keyword()
            ) :: {:ok, %{uri: String.t(), cid: String.t()}} | error()

  @doc "Apaga um record. Opção `:swap_record` para concorrência otimista."
  @callback delete_record(session(), collection :: String.t(), rkey :: String.t(), opts :: keyword()) ::
              :ok | error()

  @doc "Sobe um blob (imagem de prosa). Retorna a referência decodificada."
  @callback upload_blob(session(), data :: binary(), content_type :: String.t()) ::
              {:ok, map()} | error()

  @doc "The configured implementation."
  @spec impl() :: module()
  def impl, do: Application.get_env(:quintal, :pds_impl, Quintal.PDS.ProtoRune)
end
