defmodule QuintalWeb.ContaLive do
  @moduledoc """
  A página de conta: quem está conectada, os convites da cota, a
  exportação de um clique e a saída.

  Configuração de canto (tema, blocos) continua morando no modo
  arrumar, no lugar (briefing 3); aqui é o que diz respeito à
  identidade e aos dados, não à decoração.
  """

  use QuintalWeb, :live_view

  alias Quintal.Convites
  alias Quintal.Identidade
  alias Quintal.Repo

  @impl true
  def mount(_params, _session, socket) do
    did = socket.assigns.sessao.did
    identidade = Repo.get(Identidade, did)

    {:ok,
     assign(socket,
       page_title: "conta",
       novidade: false,
       identidade: identidade,
       fundadora?: Convites.fundadora?(did),
       convites: Convites.disponiveis(did),
       convites_restantes: Convites.restantes(did)
     )}
  end

  @impl true
  def handle_event("gerar_convite", _params, socket) do
    case Convites.gerar(socket.assigns.sessao.did) do
      {:ok, convite} ->
        {:noreply,
         socket
         |> update(:convites, &[convite | &1])
         |> assign(convites_restantes: Convites.restantes(socket.assigns.sessao.did))}

      {:error, :cota_esgotada} ->
        {:noreply, put_flash(socket, :error, "sua cota de convites acabou por enquanto")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  defp convites_linha(1), do: "você ainda pode chamar 1 pessoa pro quintal"
  defp convites_linha(n), do: "você ainda pode chamar #{n} pessoas pro quintal"

  defp pds_host(nil), do: nil

  defp pds_host(%Identidade{pds_url: url}) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _outro -> url
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <div class="conta">
        <h1>conta</h1>

        <section class="conta__secao">
          <h2 class="conta__titulo">conta conectada</h2>
          <div class="conta__card">
            <div class="conta__linha">
              <span class="conta__handle">{@sessao.handle}</span>
            </div>
            <div class="conta__linha">
              <code class="conta__did">{@sessao.did}</code>
              <button
                type="button"
                class="icone-botao"
                phx-click={JS.dispatch("quintal:copiar", detail: %{texto: @sessao.did})}
                aria-label={"copiar did #{@sessao.did}"}
              >
                <Lucideicons.copy aria-hidden="true" />
              </button>
            </div>
            <p :if={pds_host(@identidade)} class="conta__nota">
              suas prosas, recados e canto moram no seu pds:
              <a href={@identidade.pds_url} target="_blank" rel="noopener">{pds_host(@identidade)}</a>
            </p>
          </div>
        </section>

        <section class="conta__secao">
          <h2 class="conta__titulo">convites</h2>
          <div class="conta__card">
            <p :if={@fundadora?} class="conta__nota">você fundou o quintal, chame quem quiser</p>
            <p :if={!@fundadora? && @convites_restantes > 0} class="conta__nota">
              {convites_linha(@convites_restantes)}
            </p>
            <p :if={!@fundadora? && @convites_restantes == 0} class="conta__nota">
              sua cota de convites acabou por enquanto
            </p>

            <div :for={convite <- @convites} class="conta__linha">
              <code>{convite.codigo}</code>
              <button
                type="button"
                class="icone-botao"
                phx-click={JS.dispatch("quintal:copiar", detail: %{texto: convite.codigo})}
                aria-label={"copiar código #{convite.codigo}"}
              >
                <Lucideicons.copy aria-hidden="true" />
              </button>
            </div>

            <.botao
              :if={@fundadora? || @convites_restantes > 0}
              variante={:sutil}
              phx-click="gerar_convite"
            >
              gerar um convite
            </.botao>
          </div>
        </section>

        <section class="conta__secao">
          <h2 class="conta__titulo">exportar</h2>
          <div class="conta__card">
            <div class="conta__linha">
              <span>suas prosas, recados e canto, num zip</span>
              <a href="/conta/exportar" class="icone-botao" aria-label="baixar seus dados" download>
                <Lucideicons.download aria-hidden="true" />
              </a>
            </div>
          </div>
        </section>

        <section class="conta__secao">
          <div class="conta__card">
            <.link href="/oauth/logout" class="conta__sair">sair</.link>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
