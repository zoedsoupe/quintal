defmodule QuintalWeb.CondutaLive do
  @moduledoc """
  O código de conduta do quintal.

  Curto de propósito: regra de vizinhança, escrita pra ser lida, não pra
  ser citada. Ferramentas de governança coletiva ficam pra depois
  (spec 5.2); aqui está o chão mínimo do convívio no alpha.
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
        <h1>código de conduta</h1>

        <p>
          o quintal é pequeno de propósito: uma vizinhança, não uma multidão. o
          convívio se sustenta com poucas regras, todas derivadas de uma só:
          trata as pessoas como vizinhas.
        </p>

        <h2>o esperado</h2>

        <ul class="cadastro__passos">
          <li>escreva como gente, com gente: aqui todo mundo é pessoa, não audiência</li>
          <li>respeite o canto alheio: a parede é do dono, o bom senso é seu</li>
          <li>depoimento é carta de amor, não moeda: escreva o que você sustentaria no olho</li>
        </ul>

        <h2>o que não cabe aqui</h2>

        <ul class="cadastro__passos">
          <li>assédio, perseguição ou ódio contra pessoas ou grupos</li>
          <li>spam, golpe ou propaganda disfarçada de prosa</li>
          <li>conteúdo íntimo de outras pessoas sem consentimento</li>
          <li>qualquer coisa ilegal na jurisdição de onde o quintal está hospedado</li>
        </ul>

        <h2>como funciona a moderação</h2>

        <p>
          no seu canto, você manda: recados podem ser ocultados pelo dono, e o
          record de quem escreveu segue intacto no pds dela. depoimentos só
          aparecem depois de aceitos. o que passar do limite coletivo vai para a
          administração, uma pessoa só no alpha, que pode bloquear contas e
          revogar convites não usados. sem apelação formal por enquanto: é uma
          vizinhança de cinquenta pessoas, não um tribunal.
        </p>

        <h2>denunciar</h2>

        <p>
          viu algo que não cabe aqui? escreva pra administração pelo recado no
          canto do quintal ou por email. denúncias são lidas por uma pessoa, com
          calma e sem automático.
        </p>

        <.link navigate={~p"/"} class="botao">voltar</.link>
      </div>
    </Layouts.app>
    """
  end
end
