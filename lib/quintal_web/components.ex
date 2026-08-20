defmodule QuintalWeb.Components do
  @moduledoc """
  Componentes base do quintal.

  O chrome da interface é todo minúsculo (spec 7.1). O texto das prosas
  pertence ao autor: os componentes de leitura não tocam em caixa nem
  conteúdo. O axô aparece no máximo uma vez por tela e nunca dentro do
  fluxo de leitura (spec 7.6), por isso mora só no estado vazio.
  """

  use Phoenix.Component
  use QuintalWeb, :verified_routes

  alias Phoenix.HTML.FormField
  alias QuintalWeb.Markdown

  @doc """
  Botão do chrome. `variante` é `:primario` (default), `:fantasma`,
  `:sutil` ou `:destrutivo` (vinho fechado, sempre com confirmação em
  linguagem humana no `data-confirm`). Renderiza `<button>` ou, com
  `navigate`/`href`, um link com cara de botão.
  """
  attr :variante, :atom, default: :primario, values: [:primario, :fantasma, :sutil, :destrutivo]
  attr :rest, :global, include: ~w(type disabled navigate href phx-click phx-value-url phx-value-uri data-confirm)
  slot :inner_block, required: true

  def botao(assigns) do
    ~H"""
    <button class={"botao botao--#{@variante}"} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Campo de formulário com label e erro. Recebe um `Phoenix.HTML.FormField`
  (`field={@form[:email]}`) ou `name`/`value` soltos. Com `area: true`
  vira `<textarea>`.
  """
  attr :field, FormField
  attr :name, :string
  attr :value, :any, default: nil
  attr :label, :string, default: nil
  attr :area, :boolean, default: false
  attr :errors, :list, default: []
  attr :rest, :global, include: ~w(type placeholder rows maxlength required autofocus aria-label autocomplete)

  def campo(%{field: %FormField{} = field} = assigns) do
    assigns
    |> assign(:errors, Enum.map(field.errors, &translate_error/1))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> campo()
  end

  def campo(assigns) do
    ~H"""
    <div class="campo">
      <label :if={@label} class="campo__label" for={@name}>{@label}</label>
      <textarea :if={@area} id={@name} name={@name} class="campo__area" {@rest}>{@value}</textarea>
      <input :if={!@area} id={@name} name={@name} value={@value} class="campo__input" {@rest} />
      <p :for={erro <- @errors} class="campo__erro">{erro}</p>
    </div>
    """
  end

  @doc """
  O gesto de escrita do quintal, em duas superfícies (regra: no mobile,
  entrada de texto é página, nunca overlay).
  `pagina: false` é o card inline da home no desktop: linha colapsada
  que expande no foco, com chips de nota, pergunta e crônica. O ensaio
  não é radio aqui: é um link com cara de pill pra `/prosear?tipo=ensaio`,
  o modo foco.

  `pagina: true` é a página cheia (`EscreverLive`), parametrizada por
  `modo`: `:prosa` (4 chips, toolbar com clipe, título de ensaio que
  aparece via CSS), `:resposta` (card da prosa-mãe com fio, sem chips)
  e `:recado` (card do canto, texto puro com limite curto). Tudo em
  fluxo de documento: top bar com voltar, contador e o pill de publicar.
  """
  attr :pagina, :boolean, default: false
  attr :modo, :atom, default: :prosa, values: [:prosa, :resposta, :recado]
  attr :tipo, :string, default: "nota"
  attr :mae, :any, default: nil
  attr :canto, :any, default: nil
  attr :voltar, :string, default: "/"
  attr :placeholder, :string, default: nil
  attr :maxlength, :integer, default: 10_000
  attr :rotulo, :string, default: "prosear"
  attr :rascunho, :string, default: "quintal:rascunho"
  attr :uploads, :any, required: true

  def composer(assigns) do
    # placeholder vem de fora (resposta, recado) ou do tipo da prosa
    placeholder =
      assigns.placeholder ||
        case Enum.find(tipos(), fn {valor, _rotulo, _ph} -> valor == assigns.tipo end) do
          {_valor, _rotulo, placeholder} -> placeholder
          nil -> "como foi seu dia?"
        end

    assigns = assign(assigns, :placeholder, placeholder)

    ~H"""
    <form
      :if={!@pagina}
      id="prosear"
      phx-submit="prosear"
      phx-change="validar"
      phx-hook="Composer"
      class="prosear"
      data-rascunho="quintal:rascunho"
    >
      <div class="prosear__topo">
        <div class="prosear__tipos" role="radiogroup" aria-label="tipo da prosa">
          <label :for={{valor, rotulo, placeholder} <- tipos_inline()}>
            <input
              type="radio"
              name="tipo"
              value={valor}
              checked={valor == "nota"}
              data-placeholder={placeholder}
            />
            {rotulo}
          </label>
          <%!-- ensaio é modo foco, não tipo do card: um link com cara de
               pill leva pra página de escrita --%>
          <.link navigate={~p"/prosear?tipo=ensaio"} class="prosear__tipo-link">ensaio</.link>
        </div>
      </div>

      <.campo
        name="texto"
        area
        aria-label="nova prosa"
        placeholder="como foi seu dia?"
        rows="1"
        maxlength="10000"
        required
      />
      <p class="prosear__rascunho" hidden>deixou uma prosa pela metade aqui</p>
      <.md_ferramentas />

      <div :if={@uploads.imagens.entries != []} class="prosear__anexos">
        <.anexos uploads={@uploads} />
      </div>

      <div class="prosear__rodape">
        <div class="prosear__ferramentas">
          <label class="icone-botao prosear__clipe" aria-label="anexar imagem">
            <Lucideicons.paperclip aria-hidden="true" />
            <.live_file_input upload={@uploads.imagens} class="sr-only" />
          </label>
          <p class="prosear__contador" hidden></p>
          <span class="prosear__atalho" aria-hidden="true">ctrl+enter pra prosear</span>
          <svg class="prosear__progresso" viewBox="0 0 24 24" aria-hidden="true">
            <circle class="prosear__progresso-trilha" cx="12" cy="12" r="9" />
            <circle class="prosear__progresso-arco" cx="12" cy="12" r="9" />
          </svg>
          <.botao type="submit">prosear</.botao>
        </div>
      </div>
    </form>

    <form
      :if={@pagina}
      id="escrever"
      phx-submit="escrever"
      phx-change="validar"
      phx-hook="Composer"
      class="prosear prosear--pagina"
      data-rascunho={@rascunho}
    >
      <div class="prosear__barra">
        <.link navigate={@voltar} class="prosear__voltar">voltar</.link>
        <div class="prosear__barra-lado">
          <p class="prosear__contador" hidden></p>
          <.botao type="submit">{@rotulo}</.botao>
        </div>
      </div>

      <div :if={@mae} class="prosear__mae">
        <p class="prosear__mae-autor">{@mae.autor.handle}</p>
        <p class="prosear__mae-texto">{@mae.texto}</p>
      </div>

      <div :if={@canto} class="prosear__canto">
        <p class="prosear__canto-nome">{@canto}</p>
        <p class="prosear__canto-linha">
          livro de visitas aberto: aparece na hora, o dono pode ocultar depois
        </p>
      </div>

      <div :if={@modo == :prosa} class="prosear__tipos" role="radiogroup" aria-label="tipo da prosa">
        <label :for={{valor, rotulo, placeholder} <- tipos()}>
          <input
            type="radio"
            name="tipo"
            value={valor}
            checked={valor == @tipo}
            data-placeholder={placeholder}
          />
          {rotulo}
        </label>
      </div>

      <input
        :if={@modo == :prosa}
        type="text"
        id="titulo"
        name="titulo"
        class="prosear__titulo"
        placeholder="título, se quiser"
        maxlength="120"
        aria-label="título do ensaio"
      />

      <div :if={@modo != :recado} class="prosear__regua">
        <.md_ferramentas />
        <label :if={@modo == :prosa} class="icone-botao prosear__clipe" aria-label="anexar imagem">
          <Lucideicons.paperclip aria-hidden="true" />
          <.live_file_input upload={@uploads.imagens} class="sr-only" />
        </label>
      </div>

      <.campo
        name="texto"
        area
        aria-label={@rotulo}
        placeholder={@placeholder}
        rows="1"
        maxlength={@maxlength}
        required
      />
      <p class="prosear__rascunho" hidden>deixou uma prosa pela metade aqui</p>

      <div :if={@modo == :prosa && @uploads.imagens.entries != []} class="prosear__anexos">
        <.anexos uploads={@uploads} />
      </div>
    </form>
    """
  end

  # os anexos com alt obrigatório, divididos entre o card e a página.
  # erro de upload vira frase amiga, nunca silêncio (briefing 4.7)
  attr :uploads, :any, required: true

  defp anexos(assigns) do
    ~H"""
    <p :for={erro <- upload_errors(@uploads.imagens)} class="campo__erro">{erro_imagem(erro)}</p>
    <div :for={entry <- @uploads.imagens.entries} class="prosear__anexo">
      <.live_img_preview :if={entry.valid?} entry={entry} class="prosear__thumb" />
      <.campo
        :if={entry.valid?}
        name={"alt-#{entry.ref}"}
        aria-label="descrição da imagem"
        placeholder="descreve essa imagem pra quem não vê"
        required
      />
      <button
        type="button"
        class="icone-botao"
        phx-click="remover-imagem"
        phx-value-ref={entry.ref}
        aria-label="tirar imagem"
      >
        <Lucideicons.x aria-hidden="true" />
      </button>
      <p :for={erro <- upload_errors(@uploads.imagens, entry)} class="campo__erro">
        {erro_imagem(erro)}
      </p>
    </div>
    """
  end

  defp erro_imagem(:too_large), do: "essa imagem passa de 2MB. comprime ela e tenta de novo"
  defp erro_imagem(:too_many_files), do: "uma prosa leva no máximo 4 imagens"
  defp erro_imagem(:not_accepted), do: "só rola jpeg, png ou webp"
  defp erro_imagem(_outro), do: "ih, essa imagem não subiu. tenta de novo?"

  # tipo é metadado interno, nunca rótulo (spec 10.1): no composer vira
  # pill quieta com placeholder próprio, no card não aparece.
  defp tipos do
    [
      {"nota", "nota", "como foi seu dia?"},
      {"pergunta", "pergunta", "o que tá te intrigando?"},
      {"cronica", "crônica", "conta o que você viu hoje"},
      {"ensaio", "ensaio", "escreve sem pressa"}
    ]
  end

  # no card inline da home o ensaio não é radio: é porta pro modo foco
  defp tipos_inline, do: Enum.take(tipos(), 3)

  @doc """
  Uma prosa no feed, no canto ou na thread: o card de leitura.

  Nome do canto em peso 600 e tempo em sussurro, sem avatar: a
  identidade da casa é o nome. O tipo da prosa é metadado interno e
  nunca vira rótulo no card (spec 10.1).

  `em_resposta` traz o handle da prosa mãe e acende o fio lilás que
  conecta o card para cima. `path` é a página de leitura: o "continuar
  lendo" e o "responder" apontam para lá. Sem métricas em lugar nenhum:
  o rodapé é uma linha só com essas duas ações quietas.
  """
  attr :autor, :string, required: true
  attr :data, :string, required: true
  attr :texto, :string, required: true
  attr :path, :string, default: nil
  attr :cortou, :boolean, default: false
  attr :em_resposta, :string, default: nil
  attr :responder, :boolean, default: true
  attr :class, :string, default: nil
  attr :imagens, :list, default: []
  slot :acoes

  def prosa(assigns) do
    ~H"""
    <article class={["prosa-card", @class]}>
      <p :if={@em_resposta} class="prosa-card__fio">
        em resposta a <span class="prosa-card__fio-autor">{@em_resposta}</span>
      </p>

      <div class="prosa-card__corpo">
        <header class="prosa-card__cabeca">
          <div class="prosa-card__identidade">
            <span class="prosa-card__autor">{@autor}</span>
            <time class="prosa-card__tempo">{@data}</time>
          </div>
          <span :if={@acoes != []} class="prosa-card__acoes">{render_slot(@acoes)}</span>
        </header>

        <div class="prosa-card__texto">
          {Markdown.render(@texto)}
        </div>

        <div :if={@imagens != []} class="prosa-card__imagens">
          <img :for={img <- @imagens} src={img.src} alt={img.alt} loading="lazy" />
        </div>

        <footer :if={@path} class="prosa-card__rodape">
          <.link :if={@cortou} navigate={@path} class="prosa-card__continua">
            continuar lendo
          </.link>
          <.link :if={@responder} navigate={@path} class="prosa-card__responder">responder</.link>
        </footer>
      </div>
    </article>
    """
  end

  @doc """
  A régua de formatação markdown dos composers: insere markers no
  textarea (o texto continua sendo a fonte), nunca um editor rico.
  Cada botão carrega `data-md-wrap`, `data-md-prefix` ou
  `data-md-link`; o hook (`Composer` nos proseares, `MdToolbar` nos
  forms soltos) faz o gesto e devolve o foco pro campo.
  """
  def md_ferramentas(assigns) do
    ~H"""
    <div class="md-ferramentas" role="toolbar" aria-label="formatação do texto">
      <button type="button" class="icone-botao" data-md-wrap="**" aria-label="negrito" title="negrito">
        <Lucideicons.bold aria-hidden="true" />
      </button>
      <button
        type="button"
        class="icone-botao"
        data-md-wrap="*"
        aria-label="itálico"
        title="itálico"
      >
        <Lucideicons.italic aria-hidden="true" />
      </button>
      <button type="button" class="icone-botao" data-md-wrap="~~" aria-label="riscado" title="riscado">
        <Lucideicons.strikethrough aria-hidden="true" />
      </button>
      <button type="button" class="icone-botao" data-md-wrap="`" aria-label="código" title="código">
        <Lucideicons.code aria-hidden="true" />
      </button>
      <button type="button" class="icone-botao" data-md-link aria-label="link" title="link">
        <Lucideicons.link aria-hidden="true" />
      </button>
      <button
        type="button"
        class="icone-botao"
        data-md-prefix="## "
        aria-label="título"
        title="título"
      >
        <Lucideicons.heading_2 aria-hidden="true" />
      </button>
      <button
        type="button"
        class="icone-botao"
        data-md-prefix="> "
        aria-label="citação"
        title="citação"
      >
        <Lucideicons.quote aria-hidden="true" />
      </button>
      <button type="button" class="icone-botao" data-md-prefix="- " aria-label="lista" title="lista">
        <Lucideicons.list aria-hidden="true" />
      </button>
    </div>
    """
  end

  @doc "Um recado no livro de visitas de um canto."
  attr :autor, :string, required: true
  attr :data, :string, required: true
  slot :inner_block, required: true

  def recado(assigns) do
    ~H"""
    <div class="recado">
      <header class="recado__meta">
        <span>{@autor}</span>
        <time>{@data}</time>
      </header>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @axo_poses %{
    sentado: "/images/axo-sitting.png",
    dormindo: "/images/axo-slepping.png",
    acenando: "/images/axo-front-gretting.png",
    lupa: "/images/axo-with-glass.png",
    nadando: "/images/axo-swimming.png"
  }

  @doc """
  Estado vazio com o axô (briefing 4.8): uma pose, uma frase de
  microcopy, uma ação. Nunca uma tela morta, nunca mais de um axô
  por tela (spec 7.6).
  """
  attr :titulo, :string, required: true
  attr :pose, :atom, default: :sentado, values: [:sentado, :dormindo, :acenando, :lupa, :nadando]
  slot :inner_block

  def vazio(assigns) do
    assigns =
      assigns
      |> assign_new(:inner_block, fn -> [] end)
      |> assign(:axo_src, @axo_poses[assigns.pose])

    ~H"""
    <div class="vazio">
      <img class="axo" src={@axo_src} alt="" aria-hidden="true" />
      <p>{@titulo}</p>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp translate_error({msg, opts}) do
    Gettext.dgettext(QuintalWeb.Gettext, "errors", msg, opts)
  end
end
