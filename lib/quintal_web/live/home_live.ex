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

  import QuintalWeb.Formatacao, only: [tempo_relativo: 1, tipo: 1]

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
     assign(socket,
       handle: handle,
       novidade: novidade,
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
         |> update(:feed, &[prosa | &1])
         |> push_event("prosear-publicado", %{})}

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

  # Só há próxima página se a atual veio cheia.
  defp proxima_pagina(pagina) do
    if length(pagina) == @feed_pagina do
      pagina |> List.last() |> Feed.cursor()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <div :if={@sessao}>
        <form id="prosear" phx-submit="prosear" phx-hook="Prosear" class="prosear">
          <.campo
            name="texto"
            area
            aria-label="nova prosa"
            placeholder="o que tá passando no seu quintal?"
            rows="1"
            maxlength="10000"
            required
          />
          <p class="prosear__rascunho" hidden>deixou uma prosa pela metade aqui</p>
          <div class="prosear__rodape">
            <div class="prosear__tipos" role="radiogroup" aria-label="tipo da prosa">
              <label :for={{valor, rotulo} <- tipos()}>
                <input type="radio" name="tipo" value={valor} checked={valor == "nota"} />
                {rotulo}
              </label>
            </div>
            <p class="prosear__contador" hidden></p>
            <.botao type="submit">prosear</.botao>
          </div>
        </form>

        <section class="feed">
          <.vazio
            :if={@feed == []}
            pose={:sentado}
            titulo="por aqui ainda tá quieto. que tal escrever a primeira prosa?"
          />

          <.prosa
            :for={prosa <- @feed}
            autor={autor_de(prosa, @handle)}
            data={tempo_relativo(prosa.created_at)}
            tipo={tipo(prosa.tipo)}
          >
            {prosa.texto}
          </.prosa>

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
  # pill quieta, na prosa só a pergunta ganha ênfase visual.
  defp tipos, do: [{"nota", "nota"}, {"pergunta", "pergunta"}, {"cronica", "crônica"}, {"ensaio", "ensaio"}]

  # a prosa recém-proseada ainda não tem a identidade carregada: mostra
  # o próprio handle até o eco da firehose confirmar no índice.
  defp autor_de(%{autor: %{handle: handle}}, _eu), do: handle
  defp autor_de(_prosa, eu), do: eu || "eu"
end
