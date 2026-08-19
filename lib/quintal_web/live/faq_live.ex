defmodule QuintalWeb.FaqLive do
  @moduledoc """
  As palavras técnicas do quintal explicadas para quem não é técnica.

  Uma analogia simples por termo, sem abuso: o resto é link para a
  documentação do protocolo, para quem quiser descer mais um andar.
  """

  use QuintalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="cadastro">
        <h1>perguntas frequentes</h1>

        <p>
          o quintal roda em cima de um protocolo aberto chamado atproto, o mesmo
          do bluesky. ele vem com algumas palavras estranhas. aqui vão elas, em
          linguagem de vizinhança.
        </p>

        <h2>o que é um pds?</h2>

        <p>
          pds é o servidor onde ficam seus dados. pensa num armário alugado: suas
          coisas moram lá, a chave é sua, e se você não gostar do dono do prédio,
          leva tudo pra outro prédio sem perder nada. o bluesky te empresta um
          armário de graça; você também pode montar o seu.
          <a href="https://atproto.com/guides/self-hosting" target="_blank" rel="noopener">
            guia de auto-hospedagem
          </a>
        </p>

        <h2>o que é um record?</h2>

        <p>
          cada prosa, recado ou configuração do seu canto é uma ficha guardada no
          seu armário. quem escreve guarda: seu recado no mural de outra pessoa
          continua sendo uma ficha sua, no seu armário.
        </p>

        <h2>o que são handle e did?</h2>

        <p>
          handle é o nome na porta (<code>voce.bsky.social</code>), fácil de ler e
          possível de trocar. did é o número de identidade por baixo dele, que
          nunca muda. é ele que garante que você continua sendo você quando muda
          de nome ou de armário.
        </p>

        <h2>o que é o quintal, tecnicamente?</h2>

        <p>
          um appview: uma vitrine. o quintal lê as fichas que estão nos armários
          das pessoas e arruma elas bonitinhas em cantos, feeds e livros de
          visitas. ele não guarda suas prosas, guarda um índice pra encontrar
          elas rápido. apaga o quintal, suas prosas continuam no seu armário.
        </p>

        <h2>por que o quintal não pede senha?</h2>

        <p>
          a entrada é pela portaria do seu pds, via oauth. você autoriza lá, e o
          quintal recebe uma chave temporária que só abre as gavetas do quintal
          (as coleções <code>place.quintal.*</code>). a chave do resto do armário,
          seu bluesky, por exemplo, a gente nunca pede.
        </p>

        <h2>posso ir embora?</h2>

        <p>
          a hora que quiser, e nada fica refém. seus dados já são seus por
          arquitetura: é só apontar outro appview pro mesmo armário. o protocolo
          garante a saída livre por desenho, não por promessa.
        </p>

        <h2>quero o detalhe técnico</h2>

        <p>
          a especificação do protocolo está em <a
            href="https://atproto.com/specs/atp"
            target="_blank"
            rel="noopener"
          >atproto.com/specs</a>,
          os guias em
          <a href="https://atproto.com/guides/overview" target="_blank" rel="noopener">atproto.com/guides</a>
          e os lexicons do quintal são públicos em <a
            href="https://quintal.place/lexicons/place.quintal.feed.prosa"
            target="_blank"
            rel="noopener"
          >quintal.place/lexicons</a>.
        </p>

        <.link navigate={~p"/"} class="botao">voltar</.link>
      </div>
    </Layouts.app>
    """
  end
end
