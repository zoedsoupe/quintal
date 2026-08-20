defmodule QuintalWeb.BoasVindasLive do
  @moduledoc """
  O onboarding depois do primeiro acesso (briefing 5.7): do código ao
  primeiro canto sem formulário cansativo. O passo 1 (o convite) mora no
  `ConviteLive`, antes do oauth; aqui ficam os passos que precisam de
  sessão, porque arrumar o canto é escrita no pds.

  Passo 2, seu canto: a bio de uma linha, opcional. Passo 3, o tema:
  os três presets como swatches visuais, escolha com um toque, e o
  "entrar no quintal" cai na home com o composer esperando. Sem tour,
  sem tooltip em sequência: o produto é pequeno o suficiente para se
  explicar sozinho.
  """

  use QuintalWeb, :live_view

  alias Quintal.Cantos

  # swatches grandes do onboarding: mesma paleta do modo arrumar
  @presets %{
    "papel" => %{fundo: "#faf6f1", acento: "#8b7bb8", tinta: "#2e2833"},
    "madrugada" => %{fundo: "#14101c", acento: "#b9a7e0", tinta: "#ece6f2"},
    "gloss" => %{fundo: "#fff5fa", acento: "#ff6fb5", tinta: "#3d2b3a"}
  }

  @impl true
  def mount(_params, _session, socket) do
    canto = Cantos.get(socket.assigns.sessao.did)

    {:ok,
     assign(socket,
       page_title: "boas vindas",
       passo: :canto,
       tema: (canto && canto.tema) || "papel"
     )}
  end

  @impl true
  def handle_event("guardar_bio", %{"bio" => bio}, socket) do
    bio = String.trim(bio)

    if bio != "" do
      Cantos.arrumar(socket.assigns.sessao, %{bio: bio})
    end

    {:noreply, assign(socket, passo: :tema)}
  end

  def handle_event("tema", %{"tema" => tema}, socket) do
    case Cantos.arrumar(socket.assigns.sessao, %{tema: tema}) do
      {:ok, canto} ->
        {:noreply,
         socket
         |> assign(tema: canto.tema)
         |> push_event("aplicar-tema", %{tema: canto.tema, cor: canto.cor})}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("entrar", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  defp presets, do: @presets

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={false}>
      <div :if={@passo == :canto} class="boas-vindas-onboarding">
        <h1>seu canto</h1>
        <p class="boas-vindas-onboarding__linha">
          uma linha sobre você, pra quem passar saber quem mora aqui. opcional, dá pra mudar depois.
        </p>

        <form phx-submit="guardar_bio" class="boas-vindas-onboarding__form">
          <.campo
            name="bio"
            area
            aria-label="bio de uma linha"
            placeholder="escrevo sobre plantas, código e domingos"
            rows="2"
            maxlength="500"
            autofocus
          />
          <div class="boas-vindas-onboarding__acoes">
            <.botao type="submit">guardar e continuar</.botao>
            <.botao variante={:sutil} phx-click="guardar_bio" phx-value-bio="">pular</.botao>
          </div>
        </form>
      </div>

      <div :if={@passo == :tema} class="boas-vindas-onboarding">
        <h1>a cara do seu canto</h1>
        <p class="boas-vindas-onboarding__linha">
          três jeitos de arrumar a casa. dá pra trocar quando quiser.
        </p>

        <div class="tema-opcoes" role="radiogroup" aria-label="tema do canto">
          <button
            :for={{tema, preset} <- presets()}
            type="button"
            class={["tema-opcao", @tema == tema && "tema-opcao--selecionado"]}
            style={"background: #{preset.fundo}"}
            phx-click="tema"
            phx-value-tema={tema}
            aria-pressed={@tema == tema}
          >
            <span class="tema-opcao__linha" style={"background: #{preset.tinta}"}></span>
            <span
              class="tema-opcao__linha tema-opcao__linha--curta"
              style={"background: #{preset.tinta}"}
            ></span>
            <span class="tema-opcao__pill" style={"background: #{preset.acento}"}></span>
            <span class="tema-opcao__nome" style={"color: #{preset.tinta}"}>{tema}</span>
          </button>
        </div>

        <.botao phx-click="entrar">entrar no quintal</.botao>
      </div>
    </Layouts.app>
    """
  end
end
