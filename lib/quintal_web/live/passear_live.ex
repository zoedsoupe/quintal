defmodule QuintalWeb.PassearLive do
  @moduledoc """
  O passear (briefing 5.6; marco m4): quase vazio de propósito. O axô
  com a lupa, uma frase e um botão grande. Cada toque descobre um canto
  inteiro, com nome, handle, bio e links quando existem. Uma descoberta
  por vez, sempre: ritual, não catálogo.
  """

  use QuintalWeb, :live_view

  import QuintalWeb.Formatacao, only: [avatar_url: 2]

  alias Quintal.Cantos
  alias Quintal.Passear
  alias Quintal.Visitas

  @impl true
  def mount(_params, _session, socket) do
    sessao = socket.assigns.sessao
    novidade = if sessao, do: Visitas.novidade?(sessao.did), else: false

    {:ok,
     assign(socket,
       novidade: novidade,
       page_title: "passear",
       descoberta: nil,
       canto: nil,
       nome: nil,
       vistas: [],
       esgotado: false,
       sem_cantos: false
     )}
  end

  @impl true
  def handle_event("passear", _params, socket) do
    viewer_did = socket.assigns.sessao && socket.assigns.sessao.did
    sortear(socket, viewer_did, socket.assigns.vistas)
  end

  def handle_event("recomecar", _params, socket) do
    viewer_did = socket.assigns.sessao && socket.assigns.sessao.did
    sortear(socket, viewer_did, [])
  end

  def handle_event("ir_direto", %{"handle" => handle}, socket) do
    handle = handle |> String.trim() |> String.trim_leading("@") |> String.downcase()

    if handle == "" do
      {:noreply, socket}
    else
      # sem resolver aqui: se o handle não existir, o CantoLive já
      # responde com o axô de lupa
      {:noreply, push_navigate(socket, to: ~p"/canto/#{handle}")}
    end
  end

  defp sortear(socket, viewer_did, vistas) do
    case Passear.canto_aleatorio(viewer_did, vistas) do
      nil when vistas != [] ->
        {:noreply, assign(socket, descoberta: nil, canto: nil, esgotado: true, sem_cantos: false)}

      nil ->
        {:noreply, assign(socket, descoberta: nil, canto: nil, esgotado: false, sem_cantos: true)}

      descoberta ->
        canto = Cantos.get(descoberta.did) || %Quintal.Canto{}
        nome = [descoberta.did] |> Cantos.nomes() |> Map.get(descoberta.did)

        {:noreply,
         assign(socket,
           descoberta: descoberta,
           canto: canto,
           nome: nome,
           vistas: [descoberta.did | vistas],
           esgotado: false,
           sem_cantos: false
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <h1 class="sr-only">passear</h1>

      <div :if={!@descoberta && !@esgotado && !@sem_cantos} class="passear">
        <img
          class="passear__axo"
          src="/images/axo-with-glass.png"
          alt=""
          aria-hidden="true"
          width="414"
          height="418"
        />
        <p class="passear__linha">o axô acha um canto pra você conhecer</p>
        <.botao phx-click="passear">passear</.botao>

        <form phx-submit="ir_direto" class="passear__direto">
          <.campo
            name="handle"
            label="já sabe o caminho? vai direto pro canto"
            placeholder="fulano.bsky.social"
            autocomplete="off"
          />
          <.botao variante={:fantasma} type="submit">visitar</.botao>
        </form>
      </div>

      <.vazio
        :if={@sem_cantos}
        pose={:lupa}
        titulo="o axô nadou o quintal inteiro e não achou ninguém por aqui ainda"
      >
        <.link navigate={~p"/"} class="botao botao--fantasma">voltar pro quintal</.link>
      </.vazio>

      <.vazio
        :if={@esgotado}
        pose={:lupa}
        titulo="você já passeou por todos os cantos de hoje"
      >
        <.botao variante={:fantasma} phx-click="recomecar">recomeçar o passeio</.botao>
      </.vazio>

      <article :if={@descoberta} class="passeio passeio__canto">
        <header class="passeio__cabecalho">
          <.avatar
            src={avatar_url(@descoberta, @canto.avatar)}
            initial={@canto.nome || @descoberta.handle}
            class="passeio__avatar"
          />
          <div>
            <h2 class="passeio__nome">
              <.link navigate={~p"/canto/#{@descoberta.handle}"}>
                {@canto.nome || @nome || @descoberta.handle}
              </.link>
            </h2>
            <p class="passeio__handle">{@descoberta.handle}</p>
          </div>
        </header>

        <p :if={@canto.bio} class="passeio__bio">{@canto.bio}</p>

        <nav :if={@canto.links != []} class="passeio__links" aria-label="links do canto">
          <a :for={link <- @canto.links} href={link.url} target="_blank" rel="noopener">
            {link.titulo}
          </a>
        </nav>

        <div class="passeio__caminhos">
          <.link navigate={~p"/canto/#{@descoberta.handle}"} class="botao botao--primario">
            visitar esse canto
          </.link>
          <.botao variante={:fantasma} phx-click="passear">outro canto</.botao>
        </div>
      </article>
    </Layouts.app>
    """
  end
end
