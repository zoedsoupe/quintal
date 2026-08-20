defmodule QuintalWeb.LexiconsHTML do
  @moduledoc """
  Templates da visão humana dos lexicons em `quintal.place/lexicons`.
  Página de leitura, sem chrome do app: quem chega aqui quer o
  contrato técnico, não o quintal logado.
  """

  use QuintalWeb, :html

  def index(assigns) do
    ~H"""
    <div class="cadastro">
      <h1>os lexicons do quintal</h1>

      <p>
        lexicon é o contrato de formato de um tipo de record: quais campos
        uma prosa ou um recado têm, e o que cada campo vale. os lexicons do
        quintal (as coleções <code>place.quintal.*</code>) são públicos,
        então qualquer um pode construir outro lugar que lê e escreve prosas.
      </p>

      <p>
        cada lexicon abaixo também existe como json cru, no endereço <code>/lexicons/&lt;nsid&gt;.json</code>, e a especificação do
        formato está em <a href="https://atproto.com/specs/lexicon" target="_blank" rel="noopener">
          atproto.com/specs/lexicon
        </a>.
      </p>

      <.lexicon :for={lexicon <- @lexicons} lexicon={lexicon} />
    </div>
    """
  end

  def show(assigns) do
    ~H"""
    <div class="cadastro">
      <.lexicon lexicon={@lexicon} />

      <p><a href="/lexicons" class="botao">todos os lexicons</a></p>
    </div>
    """
  end

  attr :lexicon, :map, required: true

  defp lexicon(assigns) do
    ~H"""
    <section id={@lexicon["id"]}>
      <h2><code>{@lexicon["id"]}</code></h2>

      <p>
        <a href={"/lexicons/#{@lexicon["id"]}"}>página própria</a>
        · <a href={"/lexicons/#{@lexicon["id"]}.json"}>json cru</a>
      </p>

      <.definicao :for={{nome, def_} <- defs(@lexicon)} nome={nome} def={def_} />
    </section>
    """
  end

  attr :nome, :string, required: true
  attr :def, :map, required: true

  defp definicao(assigns) do
    objeto = if assigns.def["type"] == "record", do: assigns.def["record"], else: assigns.def
    assigns = assign(assigns, objeto: objeto, propriedades: objeto["properties"] || %{})

    ~H"""
    <h3><code>#{@nome}</code> ({tipo_do_def(@def)})</h3>

    <p :if={@def["description"]}>{@def["description"]}</p>

    <ul>
      <.propriedade
        :for={{nome, prop} <- Enum.sort(@propriedades)}
        nome={nome}
        prop={prop}
        obrigatorio={nome in (@objeto["required"] || [])}
      />
    </ul>
    """
  end

  attr :nome, :string, required: true
  attr :prop, :map, required: true
  attr :obrigatorio, :boolean, default: false

  defp propriedade(assigns) do
    ~H"""
    <li>
      <code>{@nome}</code>: {resumo(@prop)}{if @obrigatorio, do: " (obrigatório)"}
      <ul :if={subcampos = subcampos(@prop)}>
        <.propriedade
          :for={{nome, prop} <- subcampos}
          nome={nome}
          prop={prop}
          obrigatorio={nome in (@prop["items"]["required"] || @prop["required"] || [])}
        />
      </ul>
    </li>
    """
  end

  defp defs(%{"defs" => defs}) do
    {main, rest} = Map.pop(defs, "main")
    Enum.reject(if(main, do: [{"main", main}], else: []) ++ Enum.sort(rest), fn {_n, d} -> is_nil(d) end)
  end

  defp tipo_do_def(%{"type" => "record", "key" => key}), do: "record, chave #{key}"
  defp tipo_do_def(%{"type" => type}), do: type

  # campos aninhados de array de objeto ou objeto com properties próprias
  defp subcampos(%{"type" => "array", "items" => %{"properties" => props}}), do: Enum.sort(props)
  defp subcampos(%{"properties" => props}) when map_size(props) > 0, do: Enum.sort(props)
  defp subcampos(_prop), do: nil

  defp resumo(%{"type" => type} = prop) do
    base =
      case type do
        "string" -> "texto"
        "integer" -> "inteiro"
        "boolean" -> "booleano"
        "blob" -> "arquivo"
        "object" -> "objeto"
        "array" -> "lista de #{resumo_itens(prop["items"] || %{})}"
        "ref" -> "referência a #{prop["ref"]}"
        "union" -> "um de: #{Enum.join(prop["refs"] || [], ", ")}"
        outro -> outro
      end

    Enum.join([base | restricoes(prop)], ", ")
  end

  defp resumo_itens(%{"type" => "object"}), do: "objeto"
  defp resumo_itens(%{"type" => "ref", "ref" => ref}), do: "referência a #{ref}"
  defp resumo_itens(%{"type" => "union", "refs" => refs}), do: "um de: #{Enum.join(refs, ", ")}"
  defp resumo_itens(%{"type" => "string"} = prop), do: "texto" <> restricoes_inline(prop)
  defp resumo_itens(%{"type" => type}), do: type
  defp resumo_itens(_outro), do: "valor"

  defp restricoes_inline(prop) do
    case restricoes(prop) do
      [] -> ""
      lista -> " (#{Enum.join(lista, ", ")})"
    end
  end

  defp restricoes(%{"type" => "array", "maxLength" => max}), do: ["até #{max} itens"]

  defp restricoes(prop) do
    Enum.filter(
      [
        prop["format"] && "formato #{prop["format"]}",
        prop["maxGraphemes"] && "até #{prop["maxGraphemes"]} grafemas",
        prop["maxLength"] && "até #{prop["maxLength"]} bytes",
        prop["knownValues"] && "valores: #{Enum.join(prop["knownValues"], ", ")}",
        not is_nil(prop["minimum"]) && "mínimo #{prop["minimum"]}",
        prop["maxSize"] && "até #{div(prop["maxSize"], 1_000_000)} MB",
        prop["accept"] && "tipos: #{Enum.join(prop["accept"], ", ")}"
      ],
      & &1
    )
  end
end
