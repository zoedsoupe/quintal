defmodule QuintalWeb.HomeLive do
  @moduledoc """
  A porta de entrada do quintal.

  Deslogada (briefing 5.1): uma tela, uma ação. logo, nome em fraunces,
  uma linha de apresentação e entrar com atproto. Logada (briefing 5.2):
  o composer mora aqui, no topo, e embaixo o feed cronológico da
  vizinhança, paginado por cursor, com fim declarado. Sem contadores,
  sem ranqueamento: a vizinhança é sua e de mais ninguém.
  """

  use QuintalWeb, :live_view

  import QuintalWeb.Formatacao,
    only: [tempo_relativo: 1, trecho: 1, prosa_path: 2, imagens_card: 1]

  alias Quintal.Feed
  alias Quintal.Prosas
  alias Quintal.Visitas

  @feed_pagina 20

  @impl true
  def mount(_params, _session, socket) do
    # a sessão chega pelo SessaoHook (on_mount do live_session :default)
    sessao = socket.assigns.sessao
    handle = sessao && Map.get(sessao, :handle)
    feed = if sessao, do: Feed.list(sessao.did, limit: @feed_pagina), else: []
    novidade = if sessao, do: Visitas.novidade?(sessao.did), else: false

    {:ok,
     socket
     |> allow_upload(:imagens,
       accept: ~w(image/jpeg image/png image/webp),
       max_entries: 4,
       max_file_size: 2_000_000
     )
     |> assign(
       handle: handle,
       novidade: novidade,
       feed: feed,
       feed_cursor: proxima_pagina(feed),
       contagens: %{},
       pais: %{}
     )
     |> enriquecer(feed)}
  end

  @impl true
  def handle_event("validar", _params, socket) do
    # o form precisa de um phx-change para as entradas de upload
    # aparecerem; a validação de verdade (alt em toda imagem) acontece
    # no prosear, antes de qualquer byte sair de casa
    {:noreply, socket}
  end

  def handle_event("remover-imagem", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :imagens, ref)}
  end

  def handle_event("prosear", %{"texto" => texto} = params, socket) do
    with {:ok, imagens} <- imagens_dos_anexos(socket, params),
         {:ok, prosa} <- Prosas.prosear(socket.assigns.sessao, texto, Map.get(params, "tipo"), imagens) do
      {:noreply,
       socket
       |> put_flash(:info, "pronto, sua prosa tá no quintal")
       |> update(:feed, &[prosa | &1])
       |> push_event("prosear-publicado", %{})}
    else
      {:error, :alt_faltando} ->
        {:noreply, put_flash(socket, :error, "descreve cada imagem pra quem não vê, aí a gente prosa")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("apagar", %{"uri" => uri}, socket) do
    case Prosas.apagar(socket.assigns.sessao, uri) do
      :ok ->
        {:noreply, update(socket, :feed, &Enum.reject(&1, fn prosa -> prosa.uri == uri end))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("mais", _params, socket) do
    pagina = Feed.list(socket.assigns.sessao.did, limit: @feed_pagina, cursor: socket.assigns.feed_cursor)

    {:noreply,
     socket
     |> update(:feed, &(&1 ++ pagina))
     |> assign(feed_cursor: proxima_pagina(pagina))
     |> enriquecer(pagina)}
  end

  # Só há próxima página se a atual veio cheia.
  defp proxima_pagina(pagina) do
    if length(pagina) == @feed_pagina do
      pagina |> List.last() |> Feed.cursor()
    end
  end

  # contagens de respostas e handles das mães, em lote e sem N+1: o
  # card sussurra "3 respostas" e amarra o "em resposta a" das respostas
  defp enriquecer(socket, feed) do
    uris = Enum.map(feed, & &1.uri)

    pais_uris =
      feed |> Enum.map(& &1.reply_parent) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    socket
    |> update(:contagens, &Map.merge(&1, Prosas.contar_respostas(uris)))
    |> update(:pais, &Map.merge(&1, Prosas.pais(pais_uris)))
  end

  # cada anexo sobe como blob pro pds da pessoa e vira um item `images`
  # do record (spec 10.1); sem alt em alguma, nada sai de casa
  defp imagens_dos_anexos(socket, params) do
    case uploaded_entries(socket, :imagens) do
      {[], []} ->
        {:ok, []}

      {entradas, _em_progresso} ->
        alts = Map.new(entradas, &{&1.ref, String.trim(params["alt-#{&1.ref}"] || "")})

        if Enum.any?(entradas, &(alts[&1.ref] == "")) do
          {:error, :alt_faltando}
        else
          arquivos =
            consume_uploaded_entries(socket, :imagens, fn %{path: path}, entry ->
              {:ok, %{bin: File.read!(path), tipo: entry.client_type, alt: alts[entry.ref]}}
            end)

          subir_imagens(socket.assigns.sessao, arquivos)
        end
    end
  end

  defp subir_imagens(sessao, arquivos) do
    Enum.reduce_while(arquivos, {:ok, []}, fn %{bin: bin, tipo: tipo, alt: alt}, {:ok, acc} ->
      case Quintal.PDS.impl().upload_blob(sessao, bin, tipo) do
        {:ok, resposta} -> {:cont, {:ok, acc ++ [%{"image" => blob_lexicon(resposta), "alt" => alt}]}}
        {:error, _reason} = erro -> {:halt, erro}
      end
    end)
  end

  # a resposta do uploadBlob chega decodificada pelo proto_rune; o record
  # precisa do blob no formato do lexicon, com chaves string
  defp blob_lexicon(resposta) do
    blob = resposta[:blob] || resposta["blob"] || resposta

    %{
      "$type" => "blob",
      "ref" => %{"$link" => get_in(blob, [:ref, :"$link"]) || get_in(blob, ["ref", "$link"])},
      "mimeType" => blob[:mime_type] || blob["mimeType"],
      "size" => blob[:size] || blob["size"]
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <div :if={@sessao}>
        <form
          id="prosear"
          phx-submit="prosear"
          phx-change="validar"
          phx-hook="Prosear"
          class="prosear"
        >
          <span class="prosear__alca" aria-hidden="true"></span>
          <div class="prosear__fundo" data-fecha aria-hidden="true"></div>

          <div class="prosear__linha">
            <span
              class="prosa-card__avatar prosear__avatar"
              style={"--matiz: #{:erlang.phash2(@handle || "eu", 360)}"}
              aria-hidden="true"
            ></span>
            <.campo
              name="texto"
              area
              aria-label="nova prosa"
              placeholder="o que tá passando no seu quintal?"
              rows="1"
              maxlength="10000"
              required
            />
          </div>
          <p class="prosear__rascunho" hidden>deixou uma prosa pela metade aqui</p>

          <div :if={@uploads.imagens.entries != []} class="prosear__anexos">
            <div :for={entry <- @uploads.imagens.entries} class="prosear__anexo">
              <.live_img_preview entry={entry} class="prosear__thumb" />
              <.campo
                name={"alt-#{entry.ref}"}
                aria-label="descrição da imagem"
                placeholder="descreve essa imagem pra quem não vê"
                required
              />
              <button
                type="button"
                class="icone-botao"
                phx-click="remover-imagem"
                phx-value-ref={entry.ref}
                aria-label="tirar imagem"
              >
                <Lucideicons.x aria-hidden="true" />
              </button>
            </div>
          </div>

          <div class="prosear__rodape">
            <div class="prosear__tipos" role="radiogroup" aria-label="tipo da prosa">
              <label :for={{valor, rotulo} <- tipos()}>
                <input type="radio" name="tipo" value={valor} checked={valor == "nota"} />
                {rotulo}
              </label>
            </div>

            <div class="prosear__ferramentas">
              <label class="icone-botao prosear__clipe" aria-label="anexar imagem">
                <Lucideicons.paperclip aria-hidden="true" />
                <.live_file_input upload={@uploads.imagens} class="sr-only" />
              </label>
              <p class="prosear__contador" hidden></p>
              <span class="prosear__atalho" aria-hidden="true">ctrl+enter pra prosear</span>
              <span class="prosear__anel" aria-hidden="true"></span>
              <.botao type="submit">prosear</.botao>
            </div>
          </div>
        </form>

        <section class="feed">
          <.vazio
            :if={@feed == []}
            pose={:sentado}
            titulo="por aqui ainda tá quieto. que tal escrever a primeira prosa?"
          />

          <div :for={prosa <- @feed} class="feed__item">
            <% {texto, cortou?} = trecho(prosa.texto) %>
            <% autor = autor_de(prosa, @handle) %>
            <.prosa
              autor={autor}
              data={tempo_relativo(prosa.created_at)}
              path={prosa_path(prosa.uri, autor)}
              cortou={cortou?}
              respostas={Map.get(@contagens, prosa.uri, 0)}
              em_resposta={prosa.reply_parent && Map.get(@pais, prosa.reply_parent)}
              imagens={imagens_card(prosa)}
            >
              <:acoes :if={prosa.autor_did == @sessao.did}>
                <button
                  type="button"
                  class="icone-botao"
                  phx-click="apagar"
                  phx-value-uri={prosa.uri}
                  data-confirm="apagar essa prosa? ela sai do seu pds também."
                  aria-label="apagar prosa"
                >
                  <Lucideicons.trash_2 aria-hidden="true" />
                </button>
              </:acoes>
              {texto}
            </.prosa>
          </div>

          <p :if={@feed_cursor} class="feed__mais">
            <.botao variante={:sutil} phx-click="mais">mais prosas</.botao>
          </p>

          <p :if={@feed != [] && !@feed_cursor} class="feed__fim">
            você viu tudo do seu quintal por hoje. vai tomar um café.
          </p>
        </section>

        <nav class="rodape">
          <.link href="/oauth/logout">sair</.link>
        </nav>
      </div>

      <div :if={!@sessao} class="boas-vindas">
        <img class="boas-vindas__axo" src="/images/axo-front-gretting.png" alt="" aria-hidden="true" />
        <h1 class="boas-vindas__marca">quintal</h1>
        <p class="boas-vindas__linha">seu canto na vizinhança</p>

        <%!-- alpha fechado (spec 6): o convite é a porta principal,
             o login é caminho quieto pra quem já mora aqui --%>
        <.link navigate={~p"/convite"} class="botao botao--primario">tenho um convite</.link>

        <form action="/oauth/login" method="get" class="entrar">
          <.campo
            name="handle"
            label="já mora aqui? entra com teu handle"
            placeholder="alice.bsky.social"
            required
          />
          <.botao variante={:fantasma} type="submit">entrar com atproto</.botao>
          <.link navigate={~p"/cadastro"} class="cadastro__link">não tenho conta ainda</.link>
        </form>

        <nav class="rodape">
          <.link navigate={~p"/faq"}>que lugar é esse?</.link>
          <.link navigate={~p"/conduta"}>regrinhas de convivência</.link>
          <a href="https://github.com/zoedsoupe/quintal" target="_blank" rel="noopener">código aberto</a>
        </nav>
      </div>
    </Layouts.app>
    """
  end

  # tipo é metadado interno, nunca rótulo (spec 10.1): no composer vira
  # pill quieta, no card não aparece.
  defp tipos, do: [{"nota", "nota"}, {"pergunta", "pergunta"}, {"cronica", "crônica"}, {"ensaio", "ensaio"}]

  # a prosa recém-proseada ainda não tem a identidade carregada: mostra
  # o próprio handle até o eco da firehose confirmar no índice.
  defp autor_de(%{autor: %{handle: handle}}, _eu), do: handle
  defp autor_de(_prosa, eu), do: eu || "eu"
end
