defmodule QuintalWeb.CondutaLive do
  @moduledoc """
  As regrinhas de convivência do quintal.

  Curtas de propósito: combinado de vizinhança, escrito em primeira
  pessoa, porque o quintal é um projeto pessoal compartilhado com
  amigas e afetos. Ferramentas de governança coletiva ficam pra depois
  (spec 5.2); aqui está o chão mínimo do convívio no alpha, incluindo a
  parte que não fica subentendida: o quintal é um espaço coletivo e
  comunitário, e transfobia não cabe nele.
  """

  use QuintalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    sessao = socket.assigns.sessao
    novidade = if sessao, do: Quintal.Visitas.novidade?(sessao.did), else: false

    {:ok, assign(socket, novidade: novidade, page_title: "regrinhas de convivência")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <div class="cadastro">
        <h1>regrinhas de convivência</h1>

        <p>
          o quintal é um cantinho de internet construído por mim,
          <a href="https://zoedsoupe.zeetech.io" target="_blank" rel="noopener">zoey</a>,
          e dividido com amigas e afetos: um lugar quentinho de escrever e
          ler, pequeno e feito à mão. o convívio aqui se segura com poucas
          regrinhas, e todas nascem da mesma vontade: que quem chega se
          sinta em casa, segura e querida. e como o lugar é comum, cuidar
          dele é tarefa de todo mundo que mora aqui.
        </p>

        <h2>o que deixa o quintal gostoso</h2>

        <ul class="cadastro__passos">
          <li>escreva como você fala com quem você gosta: aqui todo mundo é gente</li>
          <li>visite os cantos com carinho: cada um tem dona ou dono, e a parede é deles</li>
          <li>depoimento é carta de amor: escreva aquilo que você diria olhando nos olhos</li>
          <li>chame cada pessoa pelo nome e pelos pronomes que ela pedir, sem cerimônia e sem debate</li>
        </ul>

        <h2>o que não cabe aqui</h2>

        <ul class="cadastro__passos">
          <li>
            transfobia, homofobia, racismo, capacitismo ou qualquer ódio
            mirado em pessoas ou grupos
          </li>
          <li>assédio ou perseguição, em público, por recado ou por fora</li>
          <li>spam, golpe ou propaganda vestida de prosa</li>
          <li>conteúdo íntimo de outras pessoas sem consentimento</li>
          <li>qualquer coisa ilegal na jurisdição de onde o quintal está hospedado</li>
        </ul>

        <h2>uma nota sobre transfobia</h2>

        <p>
          essa parte eu escrevo em primeira pessoa porque ela é sobre mim e
          sobre muita gente que eu amo: o quintal existe também pra que
          gente trans, travesti e não-binária tenha um lugar
          comum na internet onde possa simplesmente existir e escrever, sem
          precisar se explicar pra ninguém. então deixo dito com toda a
          clareza do mundo: transfobia aqui não é opinião, e a existência de
          nenhuma pessoa vira pauta de debate. errar nome ou pronome de
          propósito, questionar a identidade de alguém ou usar prosa, recado
          e depoimento pra mirar gente trans é motivo de saída do quintal,
          sem etapas intermediárias. se você passou por algo assim aqui
          dentro, me escreve: quem lê sou eu, e eu escuto de verdade.
        </p>

        <h2>como funciona a moderação</h2>

        <p>
          no seu canto, quem manda é você: recados podem ser ocultados e
          depoimentos só aparecem depois do seu aceite. o record de quem
          escreveu segue intacto no pds dela, porque as palavras pertencem a
          quem escreve. o que passar do limite do coletivo chega até mim: por
          enquanto a administração é uma pessoa só (eu, zoey), que pode
          bloquear contas e revogar convites não usados. ainda não temos
          apelação formal; somos uma vizinhança pequena se organizando com
          cuidado, e qualquer decisão dessas vem acompanhada de conversa.
        </p>

        <h2>denunciar</h2>

        <p>
          viu algo que machuca o quintal? me conta: deixa um recado no canto
          do quintal ou manda um email. cada denúncia é lida por uma pessoa,
          com calma, sem robô e sem resposta automática.
        </p>

        <.link navigate={~p"/"} class="botao">voltar</.link>
      </div>
    </Layouts.app>
    """
  end
end
