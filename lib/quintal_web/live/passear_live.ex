defmodule QuintalWeb.PassearLive do
  @moduledoc """
  O passear (briefing 5.6; marco m4): quase vazio de propósito. O axô
  com a lupa, uma frase e um botão grande. Cada toque sorteia uma carta
  de descoberta: um trecho de prosa, o nome do canto e dois caminhos
  quietos, "visitar esse canto" e "de novo". Uma descoberta por vez,
  sempre: ritual, não catálogo.
  """

  use QuintalWeb, :live_view

  alias Quintal.Cantos
  alias Quintal.Passear
  alias Quintal.Visitas
  alias QuintalWeb.Markdown

  @trecho 400

  @impl true
  def mount(_params, _session, socket) do
    sessao = socket.assigns.sessao
    novidade = if sessao, do: Visitas.novidade?(sessao.did), else: false

    {:ok, assign(socket, novidade: novidade, page_title: "passear", carta: nil, nome: nil)}
  end

  @impl true
  def handle_event("passear", _params, socket) do
    viewer_did = socket.assigns.sessao && socket.assigns.sessao.did

    case Passear.prosa_aleatoria(viewer_did) do
      nil ->
        {:noreply, socket |> assign(carta: nil) |> put_flash(:error, "ih, algo deu errado. tenta de novo?")}

      carta ->
        nome = [carta.autor_did] |> Cantos.nomes() |> Map.get(carta.autor_did)
        {:noreply, assign(socket, carta: carta, nome: nome)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <div :if={!@carta} class="passear">
        <img class="passear__axo" src="/images/axo-with-glass.png" alt="" aria-hidden="true" />
        <p class="passear__linha">o axô acha um canto pra você conhecer</p>
        <.botao phx-click="passear">passear</.botao>
      </div>

      <div :if={@carta} class="passear passeio">
        <blockquote class="passeio__trecho">
          {Markdown.render(trecho(@carta.texto))}
        </blockquote>
        <p class="passeio__autor">do canto de {@nome || @carta.autor.handle}</p>

        <div class="passeio__caminhos">
          <.link navigate={~p"/canto/#{@carta.autor.handle}"} class="botao botao--primario">
            visitar esse canto
          </.link>
          <.botao variante={:fantasma} phx-click="passear">de novo</.botao>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # trecho quieto de no máximo ~400 grafemes, cortado em grafeema e não
  # em byte, para não mutilar emoji nem acento na carta
  defp trecho(texto) do
    if texto |> String.graphemes() |> length() > @trecho do
      texto |> String.graphemes() |> Enum.take(@trecho) |> IO.iodata_to_binary() |> Kernel.<>("...")
    else
      texto
    end
  end
end
