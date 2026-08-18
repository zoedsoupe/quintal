defmodule QuintalWeb.Layouts do
  @moduledoc """
  Layouts do quintal.

  `app/1` é o chrome da aplicação: marca minúscula, navegação mínima e
  o conteúdo na medida de leitura. O axô não mora aqui: mascote no
  chrome fixo vira anúncio (spec 7.6).
  """

  use QuintalWeb, :html

  embed_templates "layouts/*"

  @doc """
  O chrome da aplicação em volta do conteúdo.
  """
  attr :flash, :map, default: %{}
  slot :inner_block, required: true, required: true

  def app(assigns) do
    ~H"""
    <div class="chrome">
      <header class="chrome__topo">
        <.link navigate={~p"/"} class="chrome__marca">quintal</.link>
      </header>

      <p :if={msg = Phoenix.Flash.get(@flash, :info)} class="flash flash--info">{msg}</p>
      <p :if={msg = Phoenix.Flash.get(@flash, :error)} class="flash flash--erro">{msg}</p>

      <main class="conteudo">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end
end
