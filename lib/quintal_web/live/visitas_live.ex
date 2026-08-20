defmodule QuintalWeb.VisitasLive do
  @moduledoc """
  A página visitas (briefing 5.5): "alguém passou por aqui?" sem
  ansiedade.

  Uma linha de resumo desde a última passada, os eventos agrupados por
  dia com cabeçalhos em sussurro, e os depoimentos pendentes com
  aceitar e deixar quieto inline. O resumo zera a cada visita e não
  existe contador permanente: a página é um registro de carinho, não
  uma caixa de entrada com dívidas.
  """

  use QuintalWeb, :live_view

  import QuintalWeb.Formatacao, only: [prosa_path: 2]

  alias Quintal.Depoimentos
  alias Quintal.Visitas

  @meses ~w(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro)

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.sessao do
      nil ->
        {:ok, redirect(socket, to: ~p"/")}

      sessao ->
        did = sessao.did
        resumo = Visitas.resumo(did)
        eventos = Visitas.eventos_desde_ultima(did)
        pendentes = Depoimentos.pendentes(did)
        Visitas.marcar_lido(did)

        {:ok,
         assign(socket,
           page_title: "visitas",
           novidade: false,
           resumo: resumo,
           dias: agrupar_por_dia(eventos),
           pendentes: pendentes,
           vazia: zerado?(resumo) && pendentes == []
         )}
    end
  end

  @impl true
  def handle_event("aceitar", %{"uri" => uri}, socket) do
    case Depoimentos.aceitar(socket.assigns.sessao, uri) do
      {:ok, _depoimento} ->
        {:noreply,
         socket
         |> put_flash(:info, "depoimento pendurado na parede do seu canto")
         |> update(:pendentes, &Enum.reject(&1, fn d -> d.uri == uri end))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("deixar_quieto", %{"uri" => uri}, socket) do
    case Depoimentos.deixar_quieto(socket.assigns.sessao, uri) do
      {:ok, _depoimento} ->
        {:noreply, update(socket, :pendentes, &Enum.reject(&1, fn d -> d.uri == uri end))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  defp zerado?(resumo) do
    resumo.recado == 0 && resumo.resposta == 0 && resumo.novo_leitor == 0 &&
      resumo.depoimento == 0 && resumo.leitura == 0
  end

  # agrupamento por dia, cabeçalhos em sussurro: "hoje", "ontem", "12 de agosto"
  defp agrupar_por_dia(eventos) do
    hoje = Date.utc_today()

    eventos
    |> Enum.group_by(fn evento -> DateTime.to_date(evento.created_at) end)
    |> Enum.sort_by(fn {dia, _eventos} -> dia end, {:desc, Date})
    |> Enum.map(fn {dia, eventos} -> {rotulo_dia(dia, hoje), eventos} end)
  end

  defp rotulo_dia(dia, hoje) do
    cond do
      dia == hoje -> "hoje"
      dia == Date.add(hoje, -1) -> "ontem"
      true -> "#{dia.day} de #{Enum.at(@meses, dia.month - 1)}"
    end
  end

  # a linha de resumo: só as partes com movimento, no plural certo
  defp linha_resumo(resumo) do
    [
      contagem(resumo.recado, "recado", "recados"),
      contagem(resumo.resposta, "resposta", "respostas"),
      contagem(resumo.leitura, "prosa lida", "prosas lidas"),
      leitores(resumo.novo_leitor),
      contagem(resumo.depoimento, "depoimento", "depoimentos")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp contagem(0, _singular, _plural), do: nil
  defp contagem(1, singular, _plural), do: "1 #{singular}"
  defp contagem(n, _singular, plural), do: "#{n} #{plural}"

  defp leitores(0), do: nil
  defp leitores(1), do: "1 vizinho novo te lendo"
  defp leitores(n), do: "#{n} vizinhos novos te lendo"

  # o destino do evento: resposta abre a prosa resposta (que carrega o
  # fio pra mãe), leitura abre a prosa lida. recado, depoimento e
  # novo leitor já resolvem no canto de quem passou.
  defp path_evento(evento, meu_handle) do
    case to_string(evento.tipo) do
      "resposta" -> prosa_path(evento.ref_uri, evento.autor.handle)
      "leitura" -> prosa_path(evento.ref_uri, meu_handle)
      _outro -> nil
    end
  end

  # linha única por evento (briefing 4.6)
  defp frase_evento(tipo) do
    case to_string(tipo) do
      "recado" -> "deixou um recado"
      "resposta" -> "respondeu sua prosa"
      "leitura" -> "leu sua prosa"
      "novo_leitor" -> "começou a ler seu canto"
      "depoimento" -> "te deixou um depoimento, quer pendurar na parede?"
      _outro -> "passou pelo seu canto"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <div class="visitas">
        <h1>visitas</h1>

        <.vazio
          :if={@vazia}
          pose={:dormindo}
          titulo="ninguém passou por aqui desde sua última visita. aproveita o silêncio."
        />

        <div :if={!@vazia}>
          <p :if={linha_resumo(@resumo) != ""} class="visitas__resumo">{linha_resumo(@resumo)}</p>

          <section :if={@pendentes != []} class="visitas__pendentes">
            <div :for={depoimento <- @pendentes} class="visita-pendente">
              <blockquote class="visita-pendente__texto">{depoimento.texto}</blockquote>
              <p class="visita-pendente__meta">
                <.link navigate={~p"/canto/#{depoimento.autor.handle}"}>
                  {depoimento.autor.handle}
                </.link>
              </p>
              <div class="visita-pendente__acoes">
                <.botao variante={:fantasma} phx-click="aceitar" phx-value-uri={depoimento.uri}>
                  aceitar
                </.botao>
                <.botao variante={:sutil} phx-click="deixar_quieto" phx-value-uri={depoimento.uri}>
                  deixar quieto
                </.botao>
              </div>
            </div>
          </section>

          <section :for={{dia, eventos} <- @dias} class="visitas__grupo">
            <h2 class="visitas__dia">{dia}</h2>
            <ul class="visitas__lista">
              <li :for={evento <- eventos}>
                <.link navigate={~p"/canto/#{evento.autor.handle}"}>{evento.autor.handle}</.link>
                <% path = path_evento(evento, @sessao.handle) %>
                <.link :if={path} navigate={path} class="visitas__evento">
                  {frase_evento(evento.tipo)}
                </.link>
                <span :if={!path}>{frase_evento(evento.tipo)}</span>
              </li>
            </ul>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
