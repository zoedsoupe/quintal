defmodule QuintalWeb.CadastroLive do
  @moduledoc """
  Página de cadastro para quem ainda não tem identidade atproto.

  O quintal é byo-pds: a conta não é criada aqui, é criada num pds
  (bsky.social, self-hosted, qualquer um) e a identidade volta pronta
  para entrar. Esta página explica isso com um micro tutorial e devolve
  a pessoa para o login. Quem tem convite começa pela portaria em
  `/convite`.
  """

  use QuintalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    sessao = socket.assigns.sessao
    novidade = if sessao, do: Quintal.Visitas.novidade?(sessao.did), else: false

    {:ok, assign(socket, novidade: novidade)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <div class="cadastro">
        <h1>criar conta</h1>

        <p>
          o quintal não guarda senhas nem contas: sua identidade mora num <em>pds</em>
          (personal data server), que é seu, e o quintal só
          conversa com ele. quem já tem conta no bluesky já tem tudo pronto.
        </p>

        <p>
          não sabe o que é isso? sem problema: a página
          <.link navigate={~p"/faq"}>que lugar é esse?</.link>
          explica tudo direitinho, sem tecnicês.
        </p>

        <h2>criando num pds existente</h2>

        <ol class="cadastro__passos">
          <li>
            abra <a href="https://bsky.social" target="_blank" rel="noopener">bsky.social</a>
            e clique em <em>criar conta</em>
          </li>
          <li>escolha seu handle, ele vira seu endereço (tipo <code>voce.bsky.social</code>)</li>
          <li>não precisa usar o app do bluesky, a conta já funciona aqui</li>
          <li>volte e entre com o handle na página inicial</li>
        </ol>

        <h2>hospedando seu próprio pds</h2>

        <p>
          se você quer suas chaves na sua infraestrutura, o pds é
          auto-hospedável. o guia oficial é
          <a
            href="https://atproto.com/guides/self-hosting"
            target="_blank"
            rel="noopener"
          >
            self-hosting no atproto.com
          </a>
          e a referência do protocolo está em <a
            href="https://atproto.com"
            target="_blank"
            rel="noopener"
          >atproto.com</a>.
          depois é só entrar com seu handle normalmente.
        </p>

        <.link navigate={~p"/"} class="botao">voltar e entrar</.link>

        <nav class="rodape">
          <.link navigate={~p"/faq"}>que lugar é esse?</.link>
          <.link navigate={~p"/conduta"}>regrinhas de convivência</.link>
        </nav>
      </div>
    </Layouts.app>
    """
  end
end
