defmodule QuintalWeb.HomeLive do
  @moduledoc """
  A porta de entrada do quintal.

  Deslogada: o que é o lugar e o caminho para entrar com a identidade
  atproto. Logada (m2): prosear, ler as próprias prosas, seguir cantos
  e ler o feed cronológico da vizinhança, paginado por cursor. Sem
  contadores, sem ranqueamento: a vizinhança é sua e de mais ninguém.
  """

  use QuintalWeb, :live_view

  alias Quintal.Feed
  alias Quintal.Follows
  alias Quintal.Prosas

  @feed_pagina 20

  @impl true
  def mount(_params, session, socket) do
    sessao =
      with did when is_binary(did) <- session["quintal_did"],
           {:ok, sessao} <- Quintal.Auth.impl().current_session(did) do
        sessao
      else
        _ -> nil
      end

    handle = sessao && Map.get(sessao, :handle)
    prosas = if sessao, do: Prosas.list_por_autor(sessao.did), else: []
    vizinhanca = if sessao, do: Follows.vizinhanca(sessao.did), else: []
    feed = if sessao, do: Feed.list(sessao.did, limit: @feed_pagina), else: []

    {:ok,
     assign(socket,
       sessao: sessao,
       handle: handle,
       prosas: prosas,
       vizinhanca: vizinhanca,
       feed: feed,
       feed_cursor: proxima_pagina(feed)
     )}
  end

  @impl true
  def handle_event("prosear", %{"texto" => texto} = params, socket) do
    case Prosas.prosear(socket.assigns.sessao, texto, Map.get(params, "tipo")) do
      {:ok, prosa} ->
        {:noreply,
         socket
         |> put_flash(:info, "pronto, sua prosa tá no quintal")
         |> update(:prosas, &[prosa | &1])}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("apagar", %{"uri" => uri}, socket) do
    case Prosas.apagar(socket.assigns.sessao, uri) do
      :ok ->
        {:noreply, update(socket, :prosas, &Enum.reject(&1, fn prosa -> prosa.uri == uri end))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("seguir", %{"quem" => quem}, socket) do
    case Follows.seguir(socket.assigns.sessao, quem) do
      {:ok, _follow} ->
        {:noreply,
         socket
         |> put_flash(:info, "agora esse canto tá na sua vizinhança")
         |> assign(vizinhanca: Follows.vizinhanca(socket.assigns.sessao.did))
         |> recarrega_feed()}

      {:error, :canto_desconhecido} ->
        {:noreply, put_flash(socket, :error, "o axô procurou, procurou... e não achou esse canto")}

      {:error, :auto_follow} ->
        {:noreply, put_flash(socket, :error, "esse canto já é o seu")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("deixar_de_seguir", %{"uri" => uri}, socket) do
    case Follows.deixar_de_seguir(socket.assigns.sessao, uri) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "esse canto saiu da sua vizinhança")
         |> assign(vizinhanca: Follows.vizinhanca(socket.assigns.sessao.did))
         |> recarrega_feed()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("mais", _params, socket) do
    pagina = Feed.list(socket.assigns.sessao.did, limit: @feed_pagina, cursor: socket.assigns.feed_cursor)

    {:noreply,
     socket
     |> update(:feed, &(&1 ++ pagina))
     |> assign(feed_cursor: proxima_pagina(pagina))}
  end

  defp recarrega_feed(socket) do
    feed = Feed.list(socket.assigns.sessao.did, limit: @feed_pagina)
    assign(socket, feed: feed, feed_cursor: proxima_pagina(feed))
  end

  # Só há próxima página se a atual veio cheia.
  defp proxima_pagina(pagina) do
    if length(pagina) == @feed_pagina do
      pagina |> List.last() |> Feed.cursor()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div :if={@sessao}>
        <p>oi, {@handle || "vizinha"}.</p>

        <form phx-submit="prosear" class="prosear">
          <.campo
            name="texto"
            area
            label="nova prosa"
            placeholder="o que tá passando no quintal?"
            rows="4"
            maxlength="10000"
            required
          />
          <div class="prosear__rodape">
            <select name="tipo" class="prosear__tipo" aria-label="tipo da prosa">
              <option value="nota">nota</option>
              <option value="pergunta">pergunta</option>
              <option value="cronica">crônica</option>
              <option value="ensaio">ensaio</option>
            </select>
            <.botao type="submit">prosear</.botao>
          </div>
        </form>

        <section class="vizinhanca">
          <h2>sua vizinhança</h2>

          <form phx-submit="seguir" class="seguir">
            <.campo name="quem" label="seguir um canto" placeholder="maria.bsky.social" required />
            <.botao type="submit">seguir esse canto</.botao>
          </form>

          <ul :if={@vizinhanca != []} class="vizinhanca__lista">
            <li :for={follow <- @vizinhanca}>
              {follow.seguido.handle}
              <.botao
                variante={:sutil}
                phx-click="deixar_de_seguir"
                phx-value-uri={follow.uri}
              >
                deixar de seguir
              </.botao>
            </li>
          </ul>
        </section>

        <section class="feed">
          <h2>a vizinhança</h2>

          <.vazio :if={@feed == []} titulo="por aqui ainda tá quieto. que tal seguir um canto?" />

          <.prosa
            :for={prosa <- @feed}
            autor={prosa.autor.handle}
            data={formatar_data(prosa.created_at)}
            tipo={tipo(prosa.tipo)}
          >
            {prosa.texto}
          </.prosa>

          <.botao :if={@feed_cursor} variante={:sutil} phx-click="mais">mais prosas</.botao>
        </section>

        <section class="minhas-prosas">
          <h2>suas prosas</h2>

          <.vazio
            :if={@prosas == []}
            titulo="por aqui ainda tá quieto. que tal escrever a primeira prosa?"
          />

          <.prosa
            :for={prosa <- @prosas}
            autor={@handle || "eu"}
            data={formatar_data(prosa.created_at)}
            tipo={tipo(prosa.tipo)}
          >
            <:acoes>
              <.botao
                variante={:sutil}
                phx-click="apagar"
                phx-value-uri={prosa.uri}
                data-confirm="apagar essa prosa? ela sai do seu pds também."
              >
                apagar
              </.botao>
            </:acoes>
            {prosa.texto}
          </.prosa>
        </section>

        <.link href="/oauth/logout" class="botao botao--sutil">sair</.link>
      </div>

      <div :if={!@sessao}>
        <.vazio titulo="uma vizinhança de blogs sobre o protocolo atproto. público por padrão, seu por princípio.">
          <form action="/oauth/login" method="get" class="entrar">
            <.campo name="handle" label="seu handle atproto" placeholder="alice.bsky.social" required />
            <.botao type="submit">entrar</.botao>
            <.link navigate={~p"/cadastro"} class="cadastro__link">não tenho conta ainda</.link>
          </form>
          <nav class="rodape">
            <.link navigate={~p"/faq"}>perguntas frequentes</.link>
            <.link navigate={~p"/conduta"}>código de conduta</.link>
          </nav>
        </.vazio>
      </div>
    </Layouts.app>
    """
  end

  defp formatar_data(%DateTime{} = data), do: Calendar.strftime(data, "%d/%m/%Y %H:%M")
  defp formatar_data(_outra), do: ""

  # tipo é metadado interno, nunca rótulo (spec 10.1): só muda a ênfase
  # visual da pergunta.
  defp tipo(tipo) when tipo in ~w(nota pergunta cronica ensaio), do: String.to_atom(tipo)
  defp tipo(_outro), do: :nota
end
