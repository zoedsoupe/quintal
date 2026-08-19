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
  Uma prosa na lista ou na leitura. `tipo: :pergunta` ganha ênfase
  visual; os demais tipos não mudam a apresentação (spec 10.1). O slot
  `acoes` leva ações do dono (apagar), à direita do meta.
  """
  attr :autor, :string, required: true
  attr :data, :string, required: true
  attr :tipo, :atom, default: :nota, values: [:nota, :pergunta, :cronica, :ensaio]
  attr :class, :string, default: nil
  slot :acoes
  slot :inner_block, required: true

  def prosa(assigns) do
    ~H"""
    <article class={["prosa", @tipo == :pergunta && "prosa--pergunta", @class]}>
      <header class="prosa__meta">
        <span class="prosa__autor">{@autor}</span>
        <time>{@data}</time>
        <span :if={@acoes != []} class="prosa__acoes">{render_slot(@acoes)}</span>
      </header>
      <div class="prosa__texto">{render_slot(@inner_block)}</div>
    </article>
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
