defmodule QuintalWeb.ContaLive do
  @moduledoc """
  A página de conta: os convites da cota, a conexão com o pds, os
  dados e a saída.

  Uma coluna quieta de seções agrupadas, cada uma um cartão de borda
  suave. Identidade tipográfica, sem avatar. Perfil (bio) e aparência
  (tema, blocos) moram no modo arrumar do canto (briefing 3); aqui é
  o administrativo: convites, conexão, dados, saída.
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
       versao: Application.spec(:quintal, :vsn) |> to_string(),
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

  defp convites_linha(1), do: "1 convite restante"
  defp convites_linha(n), do: "#{n} convites restantes"

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
        <h1 class="conta__pagina">conta</h1>

        <section class="conta__secao" aria-labelledby="conta-convites">
          <h2 id="conta-convites" class="conta__titulo">convites</h2>
          <div class="conta__card">
            <div class="conta__linha">
              <span :if={@fundadora?} class="conta__valor">você fundou o quintal, chame quem quiser</span>
              <span :if={!@fundadora? && @convites_restantes > 0} class="conta__valor">
                {convites_linha(@convites_restantes)}
              </span>
              <span :if={!@fundadora? && @convites_restantes == 0} class="conta__valor">
                sua cota de convites acabou por enquanto
              </span>
              <button
                :if={@convites != []}
                type="button"
                class="conta__link"
                phx-click={JS.dispatch("quintal:copiar", detail: %{texto: hd(@convites).codigo})}
              >
                copiar código
              </button>
            </div>

            <div :for={convite <- @convites} class="conta__linha conta__linha--codigo">
              <code>{convite.codigo}</code>
              <button
                type="button"
                class="conta__link"
                phx-click={JS.dispatch("quintal:copiar", detail: %{texto: convite.codigo})}
                aria-label={"copiar código #{convite.codigo}"}
              >
                copiar
              </button>
            </div>

            <button
              :if={@fundadora? || @convites_restantes > 0}
              type="button"
              class="conta__link"
              phx-click="gerar_convite"
            >
              gerar um convite
            </button>
          </div>
        </section>

        <section class="conta__secao" aria-labelledby="conta-conexao">
          <h2 id="conta-conexao" class="conta__titulo">conexão</h2>
          <div class="conta__card">
            <div class="conta__campo">
              <span class="conta__rotulo">handle</span>
              <span class="conta__mono">{@sessao.handle}</span>
            </div>
            <div :if={pds_host(@identidade)} class="conta__campo">
              <span class="conta__rotulo">pds</span>
              <span class="conta__mono">{pds_host(@identidade)}</span>
            </div>
          </div>
        </section>

        <section class="conta__secao" aria-labelledby="conta-sobre">
          <h2 id="conta-sobre" class="conta__titulo">sobre o quintal</h2>
          <div class="conta__card conta__card--lista">
            <%!-- href, não navigate: essas páginas moram no live_session
                 público, navegar cruzando sessões derruba o socket --%>
            <a href="/faq" class="conta__item">dúvidas</a>
            <a href="/conduta" class="conta__item">convivência</a>
            <a
              href="https://github.com/zoedsoupe/quintal"
              target="_blank"
              rel="noopener"
              class="conta__item"
            >
              código-fonte
            </a>
            <a href="/conta/exportar" class="conta__item">exportar meus dados</a>
            <p class="conta__versao">quintal v{@versao}</p>
          </div>
        </section>

        <section class="conta__secao">
          <div class="conta__card conta__card--lista">
            <a href="/oauth/logout" class="conta__item conta__item--sair">sair</a>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
