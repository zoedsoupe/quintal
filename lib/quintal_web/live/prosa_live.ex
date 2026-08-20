defmodule QuintalWeb.ProsaLive do
  @moduledoc """
  A página de leitura de uma prosa: a medida de 68ch, fraunces e nada na
  tela além da prosa e do essencial (spec 7.3, "a página de leitura é o
  produto"). Notas curtas também abrem aqui, mas é nas crônicas e
  ensaios que a página paga o clique do "continua lendo aqui".
  """

  use QuintalWeb, :live_view

  import Ecto.Query, only: [from: 2]
  import QuintalWeb.Formatacao, only: [tempo_relativo: 1, tipo: 1]

  alias Quintal.Identidade
  alias Quintal.Prosa
  alias Quintal.Repo
  alias Quintal.Visitas

  @prosa "place.quintal.feed.prosa"

  @impl true
  def mount(%{"handle" => handle, "rkey" => rkey}, _session, socket) do
    sessao = socket.assigns.sessao
    novidade = if sessao, do: Visitas.novidade?(sessao.did), else: false

    prosa =
      with %Identidade{did: did} <- Repo.one(from i in Identidade, where: i.handle == ^handle),
           %Prosa{} = prosa <- Repo.get(Prosa, "at://#{did}/#{@prosa}/#{rkey}") do
        Repo.preload(prosa, :autor)
      else
        _nao_achou -> nil
      end

    {:ok,
     assign(socket,
       novidade: novidade,
       handle: handle,
       prosa: prosa,
       page_title: if(prosa, do: "prosa de #{handle}", else: "prosa não encontrada")
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <.vazio
        :if={!@prosa}
        pose={:lupa}
        titulo="o axô procurou, procurou... e não achou essa prosa"
      />

      <article
        :if={@prosa}
        class={["prosa-pagina", tipo(@prosa.tipo) == :pergunta && "prosa--pergunta"]}
      >
        <header class="prosa-pagina__meta">
          <.link navigate={~p"/canto/#{@handle}"} class="prosa-pagina__autor">
            {@handle}
          </.link>
          <time>{tempo_relativo(@prosa.created_at)}</time>
        </header>

        <div class="prosa-pagina__texto">{@prosa.texto}</div>

        <nav class="rodape">
          <.link navigate={~p"/canto/#{@handle}"}>mais prosas de {@handle}</.link>
        </nav>
      </article>
    </Layouts.app>
    """
  end
end
