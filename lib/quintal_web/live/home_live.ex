defmodule QuintalWeb.HomeLive do
  @moduledoc """
  O início de quem mora no quintal (briefing 5.2): o composer no topo
  e embaixo o feed cronológico da vizinhança, paginado por cursor, com
  fim declarado. Sem contadores, sem ranqueamento: a vizinhança é sua
  e de mais ninguém.

  Só existe logada, atrás da portaria no live_session `:privado`.
  Deslogada, a porta de entrada é o `LandingLive` em `/`.
  """

  use QuintalWeb, :live_view

  import QuintalWeb.Formatacao,
    only: [tempo_relativo: 1, trecho: 1, prosa_path: 2, imagens_card: 1]

  import QuintalWeb.ProsearForm, only: [com_titulo: 2, imagens_dos_anexos: 2]

  alias Quintal.Cantos
  alias Quintal.Feed
  alias Quintal.Prosas
  alias Quintal.Visitas

  @feed_pagina 20

  @impl true
  def mount(_params, _session, socket) do
    sessao = socket.assigns.sessao
    feed = Feed.list(sessao.did, limit: @feed_pagina)

    {:ok,
     socket
     |> allow_upload(:imagens,
       accept: ~w(image/jpeg image/png image/webp),
       max_entries: 4,
       max_file_size: 2_000_000
     )
     |> assign(
       handle: sessao.handle,
       novidade: Visitas.novidade?(sessao.did),
       feed: feed,
       feed_cursor: proxima_pagina(feed),
       pais: %{},
       nomes: %{}
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
    texto = com_titulo(texto, params)

    with {:ok, imagens} <- imagens_dos_anexos(socket, params),
         {:ok, prosa} <- Prosas.prosear(socket.assigns.sessao, texto, Map.get(params, "tipo"), imagens) do
      {:noreply,
       socket
       |> put_flash(:info, "pronto, sua prosa tá no quintal")
       |> update(:feed, &[prosa | &1])
       |> push_event("composer-publicado", %{})}
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

  # handles das mães, em lote e sem N+1: o card amarra o "em resposta
  # a" das respostas. nomes de exibição na mesma viagem.
  defp enriquecer(socket, feed) do
    pais_uris =
      feed |> Enum.map(& &1.reply_parent) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    dids = feed |> Enum.map(& &1.autor_did) |> Enum.uniq()

    socket
    |> update(:pais, &Map.merge(&1, Prosas.pais(pais_uris)))
    |> update(:nomes, &Map.merge(&1, Cantos.nomes(dids)))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <div class="home">
        <%!-- no mobile a escrita é página, nunca overlay: a linha
             colapsada é só a porta pra /prosear. no desktop o card
             inline expande no fluxo do feed --%>
        <.link navigate={~p"/prosear"} class="prosear-atalho">
          <span class="prosear-atalho__placeholder">como foi seu dia?</span>
        </.link>

        <.composer uploads={@uploads} />

        <section class="feed" id="feed" phx-hook="FeedNovidade">
          <.vazio
            :if={@feed == []}
            pose={:sentado}
            titulo="por aqui ainda tá quieto. que tal escrever a primeira prosa? ou passear para achar vizinhos."
          >
            <div class="vazio__acoes">
              <.link navigate={~p"/prosear"} class="botao botao--fantasma">
                escrever a primeira prosa
              </.link>
              <.link navigate={~p"/passear"}>passear com o axô</.link>
            </div>
          </.vazio>

          <div
            :for={prosa <- @feed}
            class="feed__item"
            data-criado={DateTime.to_iso8601(prosa.created_at)}
          >
            <% {texto, cortou?} = trecho(prosa.texto) %>
            <% handle = handle_de(prosa, @handle) %>
            <% autor = Map.get(@nomes, prosa.autor_did, handle) %>
            <.prosa
              autor={autor}
              data={tempo_relativo(prosa.created_at)}
              texto={texto}
              path={prosa_path(prosa.uri, handle)}
              cortou={cortou?}
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
          <.link href="/oauth/logout" method="post">sair</.link>
        </nav>
      </div>
    </Layouts.app>
    """
  end

  # o handle da prosa: a recém-proseada ainda não tem a identidade
  # carregada, mostra o próprio até o eco da firehose confirmar no
  # índice. nome de exibição é só pra mostrar, nunca entra em url.
  defp handle_de(%{autor: %{handle: handle}}, _eu), do: handle
  defp handle_de(_prosa, eu), do: eu || "eu"
end
