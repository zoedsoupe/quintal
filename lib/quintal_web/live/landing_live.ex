defmodule QuintalWeb.LandingLive do
  @moduledoc """
  A porta de entrada do quintal (briefing 5.1): uma tela, uma ação.
  Logo, nome em fraunces, uma linha de apresentação e entrar com
  atproto.

  Só existe deslogada: com sessão, a porta vira redirect para o
  `/inicio`, onde moram o composer e o feed (briefing 5.2). O redirect
  é página cheia de propósito: as duas páginas moram em live_sessions
  diferentes (`:default` pública, `:privado` atrás da portaria).
  """

  use QuintalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.sessao do
      {:ok, redirect(socket, to: ~p"/inicio")}
    else
      {:ok, assign(socket, page_title: "quintal", novidade: false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade} moldura={false}>
      <div class="boas-vindas">
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
end
