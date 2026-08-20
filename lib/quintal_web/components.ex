defmodule QuintalWeb.Components do
  @moduledoc """
  Componentes base do quintal.

  O chrome da interface é todo minúsculo (spec 7.1). O texto das prosas
  pertence ao autor: os componentes de leitura não tocam em caixa nem
  conteúdo. O axô aparece no máximo uma vez por tela e nunca dentro do
  fluxo de leitura (spec 7.6), por isso mora só no estado vazio.
  """

  use Phoenix.Component

  alias Phoenix.HTML.FormField

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
          <p :for={paragrafo <- paragrafos(@texto)}>{paragrafo}</p>
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

  # parágrafos em bloco: quebra em linha em branco, sem indentação de
  # primeira linha. quebras simples dentro do parágrafo viram espaço
  defp paragrafos(texto) do
    texto
    |> String.split(~r/\n\s*\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
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

  @doc """
  O selo do compromisso de escrita humana (spec 5.1): o ícone de mão
  escrevendo, quieto, com tooltip explicando o compromisso (briefing 4.9).
  """
  attr :class, :string, default: nil

  def selo(assigns) do
    ~H"""
    <span
      class={["selo", @class]}
      title="essa pessoa assinou o compromisso de escrita humana"
    >
      <Lucideicons.signature aria-hidden="true" />
      <span class="sr-only">compromisso de escrita humana</span>
    </span>
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
