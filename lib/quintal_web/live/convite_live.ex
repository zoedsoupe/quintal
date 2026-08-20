defmodule QuintalWeb.ConviteLive do
  @moduledoc """
  A tela de convite (briefing 5.7, passo 1; marco m4): o axô acenando,
  a frase de portaria e um campo único para o código. O POST vai para o
  `ConviteController`, que valida e guarda o código na sessão — ele
  entra junto no primeiro acesso oauth.

  Uma tela, uma ação (briefing 2.1): nada de landing page, quem chega
  aqui já foi convidada por um humano.
  """

  use QuintalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "convite")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={false}>
      <div class="convite">
        <img class="convite__axo" src="/images/axo-front-gretting.png" alt="" aria-hidden="true" />
        <h1>o quintal é pequeno de propósito. você foi convidade.</h1>

        <form action="/convite" method="post" class="convite__form">
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
          <.campo
            name="codigo"
            label="seu código de convite"
            placeholder="axo-0000"
            required
            autofocus
            autocomplete="off"
          />
          <.botao type="submit">entrar com o convite</.botao>
        </form>

        <p class="convite__linha">
          depois do código, você entra com sua identidade atproto. sem conta ainda?
          <.link navigate={~p"/cadastro"}>criar num pds</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end
end
