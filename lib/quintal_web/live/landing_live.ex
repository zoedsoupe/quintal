defmodule QuintalWeb.LandingLive do
  @moduledoc """
  A porta de entrada do quintal: login como caminho principal, convite
  como alternativa para quem está chegando e passeio para visitantes.

  Só existe deslogada: com sessão, a porta vira redirect para o
  `/inicio`, onde moram o composer e o feed (briefing 5.2). O redirect
  é página cheia de propósito: as duas páginas moram em live_sessions
  diferentes (`:default` pública, `:privado` atrás da portaria).
  """

  use QuintalWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    if socket.assigns.sessao do
      {:ok, redirect(socket, to: ~p"/inicio")}
    else
      {:ok,
       assign(socket,
         page_title: "quintal",
         novidade: false,
         convite: session["convite"]
       )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      sessao={@sessao}
      novidade={@novidade}
      moldura={false}
      erro_inline={true}
    >
      <div class="boas-vindas">
        <img
          class="boas-vindas__axo"
          src="/images/axo-front-gretting.png"
          alt=""
          aria-hidden="true"
          width="415"
          height="421"
        />
        <h1 class="boas-vindas__marca">quintal</h1>
        <p class="boas-vindas__linha">seu canto na vizinhança</p>

        <section class="boas-vindas__login" aria-labelledby="boas-vindas-login">
          <h2 id="boas-vindas-login">
            {if @convite, do: "seu convite tá guardado", else: "já mora no quintal?"}
          </h2>
          <form action="/oauth/login" method="get" class="entrar">
            <.campo
              name="handle"
              label="seu handle atproto"
              placeholder="alice.bsky.social"
              required
              autofocus={!!@convite}
              errors={if erro = Phoenix.Flash.get(@flash, :error), do: [erro], else: []}
            />
            <.botao variante={:primario} type="submit">entrar com atproto</.botao>
          </form>
        </section>

        <nav class="boas-vindas__links" aria-label="outras páginas do quintal">
          <.link :if={!@convite} navigate={~p"/convite"}>tenho um convite</.link>
          <.link :if={@convite} navigate={~p"/cadastro"}>criar conta atproto</.link>
          <.link navigate={~p"/passear"}>passear com o axô</.link>
          <.link navigate={~p"/faq"}>que lugar é esse?</.link>
          <.link navigate={~p"/conduta"}>regrinhas de convivência</.link>
        </nav>
      </div>
    </Layouts.app>
    """
  end
end
