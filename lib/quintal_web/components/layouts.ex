defmodule QuintalWeb.Layouts do
  @moduledoc """
  Layouts do quintal.

  `app/1` é o chrome da aplicação: marca minúscula, navegação mínima e
  o conteúdo na medida de leitura. O axô não mora aqui: mascote no
  chrome fixo vira anúncio (spec 7.6).

  Navegação (briefing 3): quatro destinos e só. No desktop, três
  links textuais na barra superior fina (o canto chega pelo menu da
  conta); no mobile, barra inferior fixa com ícones e rótulos
  minúsculos, ao alcance do polegar. Novidade em
  visitas é um pontinho lilás quieto, nunca badge vermelho (briefing 2.8).

  O menu da conta (meu canto, conta, sair) mora num `<details>` quieto
  com o handle como gatilho, à direita da barra superior, visível
  também no mobile, onde a barra inferior não tem espaço para ele.

  `moldura: false` tira o chrome (barra superior e nav inferior fixa):
  é a página de escrita, onde nada fica fixo na tela.
  """

  use QuintalWeb, :html

  embed_templates "layouts/*"

  @doc """
  O chrome da aplicação em volta do conteúdo.

  `:sessao` é a sessão atproto (nil deslogada, sem nav). `:novidade`
  acende o ponto lilás no ícone de visitas. `:moldura` false omite a
  barra superior e a nav inferior (página de escrita).
  """
  attr :flash, :map, default: %{}
  attr :sessao, :any, default: nil
  attr :novidade, :boolean, default: false
  attr :moldura, :boolean, default: true
  slot :inner_block, required: true

  def app(assigns) do
    # a sessão é um struct opaco do proto_rune: acesso defensivo ao handle
    assigns = assign(assigns, :handle, assigns.sessao && Map.get(assigns.sessao, :handle))

    ~H"""
    <div class="chrome">
      <a href="#conteudo" class="pula-conteudo">pular pro conteúdo</a>

      <header :if={@moldura} class="chrome__topo">
        <.link navigate={if @sessao, do: ~p"/inicio", else: ~p"/"} class="chrome__marca">quintal</.link>

        <div :if={@sessao} class="chrome__lado">
          <nav class="chrome__nav">
            <.link navigate={~p"/inicio"}>início</.link>
            <.link navigate={~p"/passear"}>passear</.link>
            <.link navigate={~p"/visitas"} class="chrome__nav-visitas">
              visitas <span :if={@novidade} class="nav-movel__ponto"></span>
            </.link>
          </nav>

          <details :if={@handle} class="menu-conta">
            <summary class="menu-conta__gatilho">
              {@handle}
              <Lucideicons.chevron_down aria-hidden="true" />
            </summary>
            <nav class="menu-conta__lista" aria-label="conta">
              <.link navigate={~p"/canto/#{@handle}"}>meu canto</.link>
              <.link navigate={~p"/conta"}>conta</.link>
              <.link href={~p"/oauth/logout"} method="post">sair</.link>
            </nav>
          </details>
        </div>
      </header>

      <p :if={msg = Phoenix.Flash.get(@flash, :info)} class="flash flash--info" role="status">
        {msg}
      </p>
      <p :if={msg = Phoenix.Flash.get(@flash, :error)} class="flash flash--erro" role="alert">
        {msg}
      </p>

      <main id="conteudo" class="conteudo" tabindex="-1">
        {render_slot(@inner_block)}
      </main>

      <nav :if={@moldura && @sessao} class="nav-movel" aria-label="navegação principal">
        <.link navigate={~p"/inicio"} class="nav-movel__item">
          <Lucideicons.home aria-hidden="true" />
          <span>início</span>
        </.link>
        <.link navigate={~p"/passear"} class="nav-movel__item">
          <Lucideicons.compass aria-hidden="true" />
          <span>passear</span>
        </.link>
        <.link navigate={~p"/visitas"} class="nav-movel__item">
          <span class="nav-movel__icone">
            <Lucideicons.mail aria-hidden="true" />
            <span :if={@novidade} class="nav-movel__ponto"></span>
          </span>
          <span>visitas</span>
        </.link>
        <.link :if={@handle} navigate={~p"/canto/#{@handle}"} class="nav-movel__item">
          <Lucideicons.user_round aria-hidden="true" />
          <span>canto</span>
        </.link>
      </nav>
    </div>
    """
  end
end
