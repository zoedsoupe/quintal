defmodule QuintalWeb.FaqLive do
  @moduledoc """
  A página "que lugar é esse?": o que é o quintal, quem é o axô, o
  compromisso de escrita humana e os dois vocabulários, o da vizinhança
  e o técnico.

  As palavras técnicas do atproto vêm explicadas com uma analogia
  simples por termo, sem abuso: o resto é link para a documentação do
  protocolo, para quem quiser descer mais um andar.
  """

  use QuintalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    sessao = socket.assigns.sessao
    novidade = if sessao, do: Quintal.Visitas.novidade?(sessao.did), else: false

    {:ok, assign(socket, novidade: novidade, page_title: "que lugar é esse?")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <div class="cadastro">
        <h1>que lugar é esse?</h1>

        <p>
          as respostas curtas sobre o quintal, o axô e as palavras esquisitas
          que aparecem por aqui. se ficar faltando alguma coisa, me pergunta.
        </p>

        <h2>o que é o quintal?</h2>

        <p>
          o quintal é um lugarzinho de blogs pessoais que eu construí pra mim
          e pras pessoas que eu amo. cada pessoa tem seu canto, escreve suas
          prosas, recebe recados e escolhe quem quer ler. o feed é cronológico
          pra sempre, e aqui não existe ranqueamento, contador de seguidores,
          like nem anúncio. a entrada é por convite, porque o quintal é
          pequeno de propósito, e eu gosto dele assim.
        </p>

        <p>
          é um projeto comunitário e de código aberto, mantido por pessoas,
          sem empresa por trás: quem mora aqui também ajuda a cuidar.
        </p>

        <h2>quem é o axô?</h2>

        <p>
          o axô é um axolote, o mascote do quintal. axolotes regeneram partes
          do corpo, e por aqui seus dados também: você pode levar tudo e
          replantar em qualquer lugar. o nome é trocadilho com "achou",
          porque é o axô quem descobre cantos novos pra você no passear.
        </p>

        <h2>o compromisso de escrita humana</h2>

        <p>
          quem entra no quintal assina um compromisso: aqui se escreve com as
          próprias palavras, sem despejar texto gerado por máquina como se
          fosse seu. quem assina leva um selo quieto no canto. funciona na
          confiança: eu acredito em você, e você honra o combinado.
        </p>

        <h2>as palavras da vizinhança</h2>

        <ul class="cadastro__passos">
          <li>
            <strong>canto</strong>: sua home pessoal, com perfil, prosas,
            recados, cumadis e links
          </li>
          <li>
            <strong>prosa</strong>: a unidade de escrita. vale nota de duas
            linhas e ensaio longo
          </li>
          <li><strong>recado</strong>: entrada no livro de visitas de um canto</li>
          <li>
            <strong>depoimento</strong>: testemunho público sobre uma pessoa,
            que só aparece no canto dela depois de aceito
          </li>
          <li>
            <strong>cumadi</strong>: um canto que você lê e recomenda. sua
            lista de cumadis é pública por escolha, o "quem eu leio" do quintal
          </li>
          <li>
            <strong>vizinhança</strong>: seu grafo de leitura, quem você
            segue. ela é só sua, ninguém mais vê
          </li>
          <li>
            <strong>passear</strong>: a descoberta serendipita com o axô, um
            canto de cada vez
          </li>
          <li>
            <strong>visitas</strong>: a página de notificações quietas: quem
            passou por aqui desde sua última visita
          </li>
        </ul>

        <h2>as palavras técnicas</h2>

        <p>
          o quintal roda em cima de um protocolo aberto chamado atproto, o mesmo
          do bluesky. ele vem com algumas palavras estranhas. aqui vão elas, em
          linguagem de vizinhança.
        </p>

        <h3>o que é um pds?</h3>

        <p>
          pds é o servidor onde ficam seus dados. pensa num apê alugado: suas
          coisas moram lá, a chave é sua, e se você não gostar de quem cuida
          do prédio, leva tudo pra outro local sem perder nada. o bluesky te empresta uma
          casinha de graça; mas você também pode montar o seu!
          <a href="https://atproto.com/guides/self-hosting" target="_blank" rel="noopener">
            guia de auto-hospedagem
          </a>
        </p>

        <h3>o que é um record?</h3>

        <p>
          cada prosa, recado ou configuração do seu canto é uma ficha guardada no
          seu armário. quem escreve guarda: seu recado no mural de outra pessoa
          continua sendo uma ficha sua, no seu armário.
        </p>

        <h3>o que são handle e did?</h3>

        <p>
          handle é o nome na porta (<code>voce.bsky.social</code>), fácil de ler e
          possível de trocar. did é o número de identidade por baixo dele, que
          nunca muda. é ele que garante que você continua sendo você quando muda
          de nome ou de armário.
        </p>

        <h3>o que é o quintal, tecnicamente?</h3>

        <p>
          um appview: uma vitrine. o quintal lê as fichas que estão nos armários
          das pessoas e arruma elas bonitinhas em cantos, feeds e livros de
          visitas. ele não guarda suas prosas, guarda um índice pra encontrar
          elas rápido. apaga o quintal, suas prosas continuam no seu armário.
        </p>

        <h3>por que o quintal não pede senha?</h3>

        <p>
          a entrada é pela portaria do seu pds, via oauth. você autoriza lá, e o
          quintal recebe uma chave temporária que só abre as gavetas do quintal
          (as coleções <code>place.quintal.*</code>). a chave do resto do armário,
          seu bluesky, por exemplo, a gente nunca pede.
        </p>

        <h3>posso ir embora?</h3>

        <p>
          a hora que quiser, e nada fica refém. seus dados já são seus por
          arquitetura: é só apontar outro appview pro mesmo armário. o
          protocolo garante a saída livre por desenho, sem depender de
          promessa minha.
        </p>

        <h3>quero o detalhe técnico</h3>

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
