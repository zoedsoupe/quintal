defmodule QuintalWeb.HomeLive do
  @moduledoc """
  A porta de entrada do quintal.

  Deslogada: o que é o lugar e o caminho para entrar com a identidade
  atproto. Logada: a visão mínima do app rodando, com o vazio honesto de
  quem ainda não escreveu nada (spec 7.7).
  """

  use QuintalWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    sessao = session["quintal_session"]
    handle = sessao && (get_in(sessao, [:session, :handle]) || get_in(sessao, ["session", "handle"]))

    {:ok, assign(socket, sessao: sessao, handle: handle)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div :if={@sessao}>
        <p>oi, {@handle || "vizinha"}.</p>

        <.vazio titulo="por aqui ainda tá quieto. que tal escrever a primeira prosa?" />

        <.link href="/oauth/logout" class="botao botao--sutil">sair</.link>
      </div>

      <div :if={!@sessao}>
        <.vazio titulo="uma vizinhança de blogs sobre o protocolo atproto. público por padrão, seu por princípio.">
          <form action="/oauth/login" method="get" class="entrar">
            <.campo name="handle" label="seu handle atproto" placeholder="alice.bsky.social" required />
            <.botao type="submit">entrar</.botao>
          </form>
        </.vazio>
      </div>
    </Layouts.app>
    """
  end
end
