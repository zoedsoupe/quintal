defmodule Quintal.Prosas do
  @moduledoc """
  Escrever e ler prosas (spec 8.2, fluxos 2 e 3; marco m1).

  `prosear/3` escreve o record no repo da pessoa via
  `com.atproto.repo.createRecord` e indexa otimista: o eco do firehose
  vai chegar como o mesmo evento, então toda indexação é upsert por
  `uri` (`indexar/2`, compartilhado com o backfill do `Quintal.Bootstrap`).

  `apagar/2` remove o record do pds e do índice: a prosa sai dos dois
  lados, como a interface promete ("ela sai do seu pds também", spec 7.7).

  `list_por_autor/2` lê direto do índice, em ordem cronológica, sem
  ranqueamento em nenhuma camada. Paginação por cursor entra no m2,
  junto com o feed.
  """

  import Ecto.Query

  alias Quintal.Prosa
  alias Quintal.Repo
  alias Quintal.RichText
  alias Quintal.Visitas

  require Logger

  @prosa "place.quintal.feed.prosa"

  @tipos ~w(nota pergunta cronica ensaio lero)

  @doc """
  Escreve uma prosa nova no pds da pessoa e indexa otimista.

  `tipo` é metadado interno opcional (nota, pergunta, cronica, ensaio,
  lero; spec 10.1); `nil` deixa o campo fora do record. `imagens` é uma lista
  de `%{"image" => blob, "alt" => texto}` (máx. 4, alt obrigatório,
  spec 10.1).

  Áudio é coisa de lero: `tipo: "lero"` exige `audio`
  (`%{"audio" => blob}`) e dispensa texto (o record leva `text` vazio).
  Áudio em qualquer outro tipo é `{:error, :audio_so_lero}`; lero sem
  áudio é `{:error, :audio_faltando}`.

  Retorna `{:ok, %Prosa{}}` com a prosa já indexada, ou `{:error, _}`
  sem efeito colateral no índice. Texto em branco falha em casa, antes
  da rede.
  """
  @spec prosear(
          Quintal.PDS.session(),
          texto :: String.t(),
          tipo :: String.t() | nil,
          imagens :: [map()],
          audio :: map() | nil
        ) ::
          {:ok, Prosa.t()} | {:error, :texto_vazio | :audio_faltando | :audio_so_lero | term()}
  def prosear(session, texto, tipo \\ nil, imagens \\ [], audio \\ nil) do
    criar(session, texto, tipo, nil, imagens, audio)
  end

  @doc """
  Responde uma prosa (spec 5.1, feature 4): mesmo record, mesma
  estrutura, com `reply` apontando para a raiz e para a mãe. A mãe
  precisa estar no índice para montarmos o strongRef (uri + cid).
  """
  @spec responder(Quintal.PDS.session(), parent :: Prosa.t(), texto :: String.t()) ::
          {:ok, Prosa.t()} | {:error, :texto_vazio | :mae_fora_do_indice | term()}
  def responder(session, %Prosa{uri: parent_uri}, texto) do
    with %Prosa{} = parent <- Repo.get(Prosa, parent_uri),
         root_uri = parent.reply_root || parent.uri,
         %Prosa{} = root <- if(root_uri == parent.uri, do: parent, else: Repo.get(Prosa, root_uri)) do
      reply = %{
        "root" => %{"uri" => root.uri, "cid" => root.cid},
        "parent" => %{"uri" => parent.uri, "cid" => parent.cid}
      }

      criar(session, texto, nil, reply, [], nil)
    else
      _sem_mae_ou_raiz -> {:error, :mae_fora_do_indice}
    end
  end

  defp criar(session, texto, tipo, reply, imagens, audio) when is_binary(texto) do
    cond do
      audio && tipo != "lero" ->
        {:error, :audio_so_lero}

      tipo == "lero" && is_nil(audio) ->
        {:error, :audio_faltando}

      tipo != "lero" && String.trim(texto) == "" ->
        {:error, :texto_vazio}

      true ->
        texto = if tipo == "lero", do: "", else: texto
        record = %{"text" => texto, "createdAt" => DateTime.to_iso8601(DateTime.utc_now())}
        record = if tipo in @tipos, do: Map.put(record, "tipo", tipo), else: record
        record = if reply, do: Map.put(record, "reply", reply), else: record
        record = if imagens == [], do: record, else: Map.put(record, "images", imagens)
        record = if audio, do: Map.put(record, "audio", audio), else: record

        record =
          case RichText.facets(texto) do
            [] -> record
            facets -> Map.put(record, "facets", facets)
          end

        with {:ok, %{uri: uri, cid: cid}} <- pds().create_record(session, @prosa, record) do
          indexar(session.did, %{uri: uri, cid: cid, value: record})
        end
    end
  end

  @doc """
  Salva o texto novo de uma prosa própria: `put_record` no mesmo rkey
  (spec 9.4), com o resto do record (createdAt, reply, imagens, tipo)
  reconstruído do índice, e reindexa.

  Prosa fora do índice ou alheia é `{:error, :prosa_alheia}`. Resposta
  cuja mãe ou raiz saiu do índice é `{:error, :mae_fora_do_indice}`:
  sem os cids não dá pra reconstruir o strongRef.
  """
  @spec editar(Quintal.PDS.session(), uri :: String.t(), texto :: String.t()) ::
          {:ok, Prosa.t()} | {:error, :texto_vazio | :prosa_alheia | :mae_fora_do_indice | term()}
  def editar(session, "at://" <> rest = uri, texto) when is_binary(texto) do
    if String.trim(texto) == "" do
      {:error, :texto_vazio}
    else
      with [did, @prosa, rkey] <- String.split(rest, "/"),
           true <- did == session.did,
           %Prosa{} = prosa <- Repo.get(Prosa, uri),
           prosa = Repo.preload(prosa, :imagens),
           {:ok, record} <- record_lexicon(prosa, texto),
           {:ok, %{uri: uri, cid: cid}} <- pds().put_record(session, @prosa, rkey, record, []) do
        indexar(session.did, %{uri: uri, cid: cid, value: record})
      else
        {:error, _reason} = error -> error
        _other -> {:error, :prosa_alheia}
      end
    end
  end

  def editar(_session, _uri, _texto), do: {:error, :prosa_alheia}

  # Reconstrói o record no formato do lexicon a partir do índice, com o
  # texto novo. O blob da imagem já mora normalizado no índice (chaves
  # string, cortesia do ProsearForm.blob_lexicon/1 e da firehose crua).
  defp record_lexicon(%Prosa{} = prosa, texto) do
    with {:ok, reply} <- reply_lexicon(prosa) do
      record =
        %{"text" => texto, "createdAt" => DateTime.to_iso8601(prosa.created_at)}
        |> put_se_houver("tipo", prosa.tipo)
        |> put_se_houver("langs", prosa.langs)
        |> put_se_houver("reply", reply)
        |> put_se_houver("facets", facets_lexicon(texto))
        |> put_se_houver("images", imagens_lexicon(prosa.imagens))
        |> put_se_houver("audio", audio_lexicon(prosa))

      {:ok, record}
    end
  end

  defp put_se_houver(record, _chave, valor) when valor in [nil, []], do: record
  defp put_se_houver(record, chave, valor), do: Map.put(record, chave, valor)

  defp facets_lexicon(texto) do
    case RichText.facets(texto) do
      [] -> nil
      facets -> facets
    end
  end

  defp imagens_lexicon([]), do: nil

  defp imagens_lexicon(imagens) do
    Enum.map(imagens, &%{"image" => &1.blob, "alt" => &1.alt})
  end

  defp audio_lexicon(%Prosa{audio_blob: nil}), do: nil
  defp audio_lexicon(%Prosa{audio_blob: blob, audio_alt: alt}) when alt in [nil, ""], do: %{"audio" => blob}
  defp audio_lexicon(%Prosa{audio_blob: blob, audio_alt: alt}), do: %{"audio" => blob, "alt" => alt}

  defp reply_lexicon(%Prosa{reply_root: nil}), do: {:ok, nil}

  defp reply_lexicon(%Prosa{reply_root: root_uri, reply_parent: parent_uri}) do
    with %Prosa{} = root <- Repo.get(Prosa, root_uri),
         %Prosa{} = parent <- Repo.get(Prosa, parent_uri) do
      {:ok,
       %{
         "root" => %{"uri" => root.uri, "cid" => root.cid},
         "parent" => %{"uri" => parent.uri, "cid" => parent.cid}
       }}
    else
      _sem_mae_ou_raiz -> {:error, :mae_fora_do_indice}
    end
  end

  @doc """
  Apaga uma prosa do pds e do índice.

  Só apaga prosa da própria pessoa: uri fora do repo da sessão é
  `{:error, :prosa_alheia}` e nada sai de casa.
  """
  @spec apagar(Quintal.PDS.session(), uri :: String.t()) :: :ok | {:error, term()}
  def apagar(session, "at://" <> rest = uri) do
    with [did, @prosa, rkey] <- String.split(rest, "/"),
         true <- did == session.did,
         %Prosa{} = prosa <- Repo.get(Prosa, uri),
         :ok <- pds().delete_record(session, @prosa, rkey, []) do
      case Repo.delete(prosa) do
        {:ok, _prosa} -> :ok
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, _do_pds} = error -> error
      _other -> {:error, :prosa_alheia}
    end
  end

  def apagar(_session, _uri), do: {:error, :prosa_alheia}

  @doc "Lista as prosas de uma pessoa, da mais nova para a mais antiga."
  @spec list_por_autor(autor_did :: String.t(), opts :: keyword()) :: [Prosa.t()]
  def list_por_autor(autor_did, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from p in Prosa,
        where: p.autor_did == ^autor_did,
        order_by: [desc: p.created_at],
        limit: ^limit,
        preload: [:autor, :imagens]
    )
  end

  @doc """
  As respostas diretas de uma prosa, da mais antiga para a mais nova
  (briefing 5.4): a thread cresce para baixo, como conversa de varanda.
  """
  @spec respostas(uri :: String.t(), opts :: keyword()) :: [Prosa.t()]
  def respostas(uri, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from p in Prosa,
        where: p.reply_parent == ^uri,
        order_by: [asc: p.created_at],
        limit: ^limit,
        preload: [:autor, :imagens]
    )
  end

  @doc """
  Os handles das prosas mãe de uma lista de uris, em lote:
  `%{uri => handle}`. É o "em resposta a fulana" dos cards de resposta
  no feed. Mãe fora do índice simplesmente não aparece no mapa.
  """
  @spec pais(uris :: [String.t()]) :: %{String.t() => String.t()}
  def pais([]), do: %{}

  def pais(uris) do
    from(p in Prosa,
      join: a in assoc(p, :autor),
      where: p.uri in ^uris,
      select: {p.uri, a.handle}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Remove uma prosa do índice (delete vindo da firehose)."
  @spec desindexar(uri :: String.t()) :: :ok
  def desindexar(uri) do
    Repo.delete_all(from p in Prosa, where: p.uri == ^uri)
    :ok
  end

  @doc """
  Upsert idempotente de uma prosa no índice.

  `value` é o record decodificado: chaves atom snakelized quando vem do
  XRPC (`%{text:, created_at:}`), chaves string no formato do lexicon
  quando vem da escrita otimista (`%{"text" => ...}`).
  """
  @spec indexar(autor_did :: String.t(), %{uri: String.t(), cid: String.t(), value: map()}) ::
          {:ok, Prosa.t()} | {:error, Ecto.Changeset.t()}
  def indexar(autor_did, %{uri: uri, cid: cid, value: value}) do
    attrs = %{
      uri: uri,
      autor_did: autor_did,
      cid: cid,
      texto: campo(value, :text),
      tipo: campo(value, :tipo),
      reply_root: strong_ref_uri(campo(value, :reply), :root),
      reply_parent: strong_ref_uri(campo(value, :reply), :parent),
      langs: campo(value, :langs),
      audio_blob: value |> campo(:audio) |> campo(:audio),
      audio_alt: value |> campo(:audio) |> campo(:alt),
      created_at: parse_datetime(campo(value, :created_at) || campo(value, :createdAt)),
      indexed_at: DateTime.utc_now()
    }

    imagens = imagens_attrs(uri, campo(value, :images))

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:prosa, Prosa.changeset(%Prosa{}, attrs),
      on_conflict: :replace_all,
      conflict_target: :uri
    )
    |> Ecto.Multi.delete_all(:limpa_imagens, from(i in Quintal.ProsaImagem, where: i.prosa_uri == ^uri))
    |> Ecto.Multi.insert_all(:imagens, Quintal.ProsaImagem, imagens)
    |> Repo.transaction()
    |> case do
      {:ok, %{prosa: prosa}} ->
        registra_resposta(prosa)
        registra_mencoes(prosa, campo(value, :facets))
        prosa = Repo.preload(prosa, [:autor, :imagens])
        Phoenix.PubSub.broadcast(Quintal.PubSub, "prosas", {:prosa_nova, prosa})
        {:ok, prosa}

      {:error, :prosa, changeset, _mudancas} ->
        Logger.warning("[#{__MODULE__}] prosa #{uri} fora do índice: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def indexar(_autor_did, record) do
    Logger.warning("[#{__MODULE__}] record inesperado na indexação: #{inspect(record)}")
    {:error, :record_inesperado}
  end

  # Resposta avisa o autor da prosa mãe na página visitas (spec 7.5). O
  # registrar dedupa por (tipo, ref_uri), então vale chamar em todo upsert.
  defp registra_resposta(%Prosa{reply_parent: nil}), do: :ok

  defp registra_resposta(%Prosa{reply_parent: parent_uri, uri: uri, autor_did: autor_did}) do
    case Repo.get(Prosa, parent_uri) do
      %Prosa{autor_did: dono_did} when dono_did != autor_did ->
        Visitas.registrar(dono_did, "resposta", uri, autor_did)

      _sem_mae_no_indice ->
        :ok
    end
  end

  # Menção avisa a pessoa mencionada na página visitas: os dids vêm das
  # features `app.bsky.richtext.facet#mention` do record. A menção some
  # numa edição? a visita fica, o carinho já foi entregue.
  defp registra_mencoes(_prosa, facets) when not is_list(facets), do: :ok

  defp registra_mencoes(%Prosa{uri: uri, autor_did: autor_did}, facets) do
    facets
    |> Enum.flat_map(fn facet -> List.wrap(campo(facet, :features)) end)
    |> Enum.filter(fn feature -> campo(feature, :"$type") == "app.bsky.richtext.facet#mention" end)
    |> Enum.map(fn feature -> campo(feature, :did) end)
    |> Enum.uniq()
    |> Enum.each(fn
      # só gente do quintal tem página visitas; did de fora falharia na fk
      did when is_binary(did) and did != autor_did ->
        if Repo.exists?(from i in Quintal.Identidade, where: i.did == ^did) do
          Visitas.registrar(did, "mencao", uri, autor_did)
        end

      _outro ->
        :ok
    end)
  end

  # Imagens do record (máx. 4, alt obrigatório, spec 10.1): aceita as
  # chaves atom do decode XRPC e as string do lexicon; alt ausente na
  # firehose vira string vazia, nunca derruba a indexação.
  defp imagens_attrs(_uri, imagens) when not is_list(imagens), do: []

  defp imagens_attrs(uri, imagens) do
    imagens
    |> Enum.take(4)
    |> Enum.with_index()
    |> Enum.map(fn {item, posicao} ->
      %{
        prosa_uri: uri,
        posicao: posicao,
        blob: campo(item, :image) || %{},
        alt: campo(item, :alt) || ""
      }
    end)
  end

  # Record values arrive atom-keyed from the XRPC decode and
  # string-keyed from the optimistic write: accept both.
  defp campo(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp campo(_other, _key), do: nil

  defp strong_ref_uri(reply, papel) when is_map(reply) do
    reply |> campo(papel) |> campo(:uri)
  end

  defp strong_ref_uri(_reply, _papel), do: nil

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp pds, do: Quintal.PDS.impl()
end
