defmodule QuintalWeb.Layouts do
  @moduledoc """
  Layouts do quintal.

  `app/1` é o chrome da aplicação: marca minúscula, navegação mínima e
  o conteúdo na medida de leitura. O axô não mora aqui: mascote no
  chrome fixo vira anúncio (spec 7.6).

  Navegação (briefing 3): quatro destinos e só. No desktop, links
  textuais na barra superior fina; no mobile, barra inferior fixa com
  ícones e rótulos minúsculos, ao alcance do polegar. Novidade em
  visitas é um pontinho lilás quieto, nunca badge vermelho (briefing 2.8).
  """

  use QuintalWeb, :html

  embed_templates "layouts/*"

  @doc """
  O chrome da aplicação em volta do conteúdo.

  `:sessao` é a sessão atproto (nil deslogada, sem nav). `:novidade`
  acende o ponto lilás no ícone de visitas.
  """
  attr :flash, :map, default: %{}
  attr :sessao, :any, default: nil
  attr :novidade, :boolean, default: false
  slot :inner_block, required: true

  def app(assigns) do
    # a sessão é um struct opaco do proto_rune: acesso defensivo ao handle
    assigns = assign(assigns, :handle, assigns.sessao && Map.get(assigns.sessao, :handle))

    ~H"""
    <div class="chrome">
      <header class="chrome__topo">
        <.link navigate={~p"/"} class="chrome__marca">quintal</.link>

        <nav :if={@sessao} class="chrome__nav">
          <.link navigate={~p"/"}>início</.link>
          <.link navigate={~p"/passear"}>passear</.link>
          <.link navigate={~p"/visitas"}>visitas</.link>
          <.link :if={@handle} navigate={~p"/canto/#{@handle}"}>canto</.link>
        </nav>
      </header>

      <p :if={msg = Phoenix.Flash.get(@flash, :info)} class="flash flash--info">{msg}</p>
      <p :if={msg = Phoenix.Flash.get(@flash, :error)} class="flash flash--erro">{msg}</p>

      <main class="conteudo">
        {render_slot(@inner_block)}
      </main>

      <nav :if={@sessao} class="nav-movel" aria-label="navegação principal">
        <.link navigate={~p"/"} class="nav-movel__item">
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
