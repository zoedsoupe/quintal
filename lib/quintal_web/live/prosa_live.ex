defmodule QuintalWeb.ProsaLive do
  @moduledoc """
  A página de leitura de uma prosa: a medida de 68ch, fraunces e nada na
  tela além da prosa e do essencial (spec 7.3, "a página de leitura é o
  produto"). Notas curtas também abrem aqui, mas é nas crônicas e
  ensaios que a página paga o clique do "continuar lendo".

  Abaixo da prosa, uma hairline e a thread (briefing 5.4): respostas em
  ordem cronológica, no mesmo formato de card do feed, e no fim um
  composer de resposta. Resposta não é comentário: é uma prosa com
  `reply`, e clicar nela abre a página dela.

  O "li até aqui" é uma visita de leitura: nunca rastreamos leitura, a
  visita nasce do gesto do leitor.
  """

  use QuintalWeb, :live_view

  import Ecto.Query, only: [from: 2]

  import QuintalWeb.Formatacao,
    only: [tempo_relativo: 1, prosa_path: 2, imagens_card: 1]

  alias Quintal.Cantos
  alias Quintal.Identidade
  alias Quintal.Prosa
  alias Quintal.Prosas
  alias Quintal.Repo
  alias Quintal.Visitas
  alias QuintalWeb.Markdown

  @prosa "place.quintal.feed.prosa"

  @impl true
  def mount(%{"handle" => handle, "rkey" => rkey}, _session, socket) do
    sessao = socket.assigns.sessao
    novidade = if sessao, do: Visitas.novidade?(sessao.did), else: false

    prosa =
      with %Identidade{did: did} <- Repo.one(from i in Identidade, where: i.handle == ^handle),
           %Prosa{} = prosa <- Repo.get(Prosa, "at://#{did}/#{@prosa}/#{rkey}") do
        Repo.preload(prosa, [:autor, :imagens])
      else
        _nao_achou -> nil
      end

    thread = if prosa, do: Prosas.respostas(prosa.uri), else: []

    dids = Enum.reject([prosa && prosa.autor_did | Enum.map(thread, & &1.autor_did)], &is_nil/1)

    {:ok,
     assign(socket,
       novidade: novidade,
       handle: handle,
       prosa: prosa,
       thread: thread,
       nomes: Cantos.nomes(dids),
       visita_deixada: visita_deixada?(prosa, sessao),
       page_title: if(prosa, do: "prosa de #{handle}", else: "prosa não encontrada")
     )}
  end

  @impl true
  def handle_event("deixar_visita", _params, socket) do
    %{prosa: prosa, sessao: sessao} = socket.assigns

    case Visitas.registrar(prosa.autor_did, "leitura", prosa.uri, sessao.did) do
      :ok ->
        {:noreply, assign(socket, visita_deixada: true)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("responder", %{"texto" => texto}, socket) do
    case Prosas.responder(socket.assigns.sessao, socket.assigns.prosa, texto) do
      {:ok, resposta} ->
        {:noreply,
         socket
         |> put_flash(:info, "pronto, sua prosa tá no quintal")
         |> update(:thread, &(&1 ++ [resposta]))
         |> push_event("composer-publicado", %{})}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("apagar", %{"uri" => uri}, socket) do
    case Prosas.apagar(socket.assigns.sessao, uri) do
      :ok ->
        {:noreply, update(socket, :thread, &Enum.reject(&1, fn prosa -> prosa.uri == uri end))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  # nunca rastreamos leitura: a visita nasce do gesto do leitor
  defp visita_deixada?(%Prosa{uri: uri}, %{did: did}), do: Visitas.leitura_marcada?(uri, did)
  defp visita_deixada?(_prosa, _sessao), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <.vazio
        :if={!@prosa}
        pose={:lupa}
        titulo="o axô procurou, procurou... e não achou essa prosa"
      >
        <.link navigate={~p"/inicio"} class="botao botao--fantasma">voltar pro início</.link>
      </.vazio>

      <article :if={@prosa} class="prosa-pagina">
        <header class="prosa-pagina__meta">
          <.link navigate={~p"/canto/#{@handle}"} class="prosa-pagina__autor">
            {Map.get(@nomes, @prosa.autor_did, @handle)}
          </.link>
          <time>{tempo_relativo(@prosa.created_at)}</time>
        </header>

        <div class="prosa-pagina__texto">
          {Markdown.render(@prosa.texto)}
        </div>

        <div :if={imagens_card(@prosa) != []} class="prosa-pagina__imagens">
          <img :for={img <- imagens_card(@prosa)} src={img.src} alt={img.alt} loading="lazy" />
        </div>
      </article>

      <section :if={@prosa} class="thread" aria-label="respostas">
        <.prosa
          :for={resposta <- @thread}
          autor={Map.get(@nomes, resposta.autor_did, resposta.autor.handle)}
          data={tempo_relativo(resposta.created_at)}
          texto={resposta.texto}
          path={prosa_path(resposta.uri, resposta.autor.handle)}
          imagens={imagens_card(resposta)}
        >
          <:acoes :if={@sessao && resposta.autor_did == @sessao.did}>
            <button
              type="button"
              class="icone-botao"
              phx-click="apagar"
              phx-value-uri={resposta.uri}
              data-confirm="apagar essa prosa? ela sai do seu pds também."
              aria-label="apagar prosa"
            >
              <Lucideicons.trash_2 aria-hidden="true" />
            </button>
          </:acoes>
        </.prosa>

        <%!-- no mobile a resposta é página (/prosear?reply=), com a
             mãe à vista; no desktop o form inline cresce no fluxo --%>
        <.link
          :if={@sessao}
          navigate={"/prosear?reply=#{URI.encode_www_form(@prosa.uri)}"}
          class="prosear-atalho thread__responder"
        >
          <span class="prosear-atalho__placeholder">responder com uma prosa...</span>
        </.link>

        <form
          :if={@sessao}
          id="responder"
          phx-submit="responder"
          phx-hook="Composer"
          class="prosear thread__responder"
          data-rascunho={"quintal:rascunho:responder:#{@prosa.uri}"}
        >
          <.campo
            name="texto"
            area
            aria-label="responder com uma prosa"
            placeholder="responder com uma prosa..."
            rows="1"
            maxlength="10000"
            required
          />
          <.md_ferramentas />
          <div class="prosear__rodape">
            <div class="prosear__ferramentas">
              <span class="prosear__atalho" aria-hidden="true">ctrl+enter pra responder</span>
              <.botao type="submit">responder</.botao>
            </div>
          </div>
        </form>

        <nav class="rodape">
          <.link navigate={~p"/canto/#{@handle}"}>mais prosas de {@handle}</.link>
          <span :if={@visita_deixada} class="rodape__visita">visita deixada</span>
          <.botao
            :if={pode_visitar?(@sessao, @prosa) && !@visita_deixada}
            variante={:sutil}
            phx-click="deixar_visita"
          >
            li até aqui
          </.botao>
        </nav>
      </section>
    </Layouts.app>
    """
  end

  defp pode_visitar?(%{did: did}, %Prosa{autor_did: autor_did}), do: did != autor_did
  defp pode_visitar?(_sessao, _prosa), do: false
end
