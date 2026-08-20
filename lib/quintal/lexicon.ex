defmodule Quintal.Lexicon do
  @moduledoc """
  Valida records contra os lexicons `place.quintal.*` antes da escrita
  no pds: falhar cedo, falhar em casa (spec 9.4). Os schemas lidos são
  os mesmos arquivos servidos em `quintal.place/lexicons/`: fonte
  única, nada de schema duplicado em código.

  Cobre o que os nossos lexicons usam: `required`, `string` (format,
  maxGraphemes, maxLength, knownValues), `array` (maxLength, items de
  objeto ou string), `object`, `blob` e refs locais (`#replyRef`).
  Blobs e refs externas só checam presença de mapa: a forma exata é
  garantida pelo pds no upload.
  """

  @type error :: String.t()

  @doc """
  Valida `record` contra o lexicon da `collection`.

  Retorna `:ok` ou `{:error, [erro]}` com uma entrada por violação.
  Coleção sem lexicon local é erro: a fronteira só escreve o que conhece.
  """
  @spec validate(collection :: String.t(), record :: map()) :: :ok | {:error, [error()]}
  def validate(collection, record) when is_binary(collection) and is_map(record) do
    with {:ok, lexicon} <- load(collection) do
      defs = lexicon["defs"] || %{}
      schema = get_in(defs, ["main", "record"]) || %{}

      case check_object(record, schema, defs, "$") do
        [] -> :ok
        errors -> {:error, errors}
      end
    end
  end

  defp load(nsid) do
    case :persistent_term.get({__MODULE__, nsid}, :miss) do
      :miss ->
        path =
          Path.join([Application.app_dir(:quintal, "priv"), "static", "lexicons", "#{nsid}.json"])

        case File.read(path) do
          {:ok, contents} ->
            lexicon = JSON.decode!(contents)
            :persistent_term.put({__MODULE__, nsid}, lexicon)
            {:ok, lexicon}

          {:error, _reason} ->
            {:error, ["unknown lexicon: #{nsid}"]}
        end

      lexicon ->
        {:ok, lexicon}
    end
  end

  defp check_object(map, schema, defs, path) when is_map(map) do
    properties = schema["properties"] || %{}
    required = schema["required"] || []

    missing =
      for key <- required, not Map.has_key?(map, key) do
        "#{path}: missing required field \"#{key}\""
      end

    unknown =
      for {key, _value} <- map,
          key != "$type",
          not Map.has_key?(properties, key) do
        "#{path}: unknown field \"#{key}\""
      end

    fields =
      Enum.flat_map(properties, fn {key, prop} ->
        case Map.fetch(map, key) do
          {:ok, value} -> check_field(value, prop, defs, "#{path}.#{key}")
          :error -> []
        end
      end)

    missing ++ unknown ++ fields
  end

  defp check_field(value, %{"type" => "string"} = prop, _defs, path) do
    if is_binary(value) do
      check_string(value, prop, path)
    else
      ["#{path}: expected string"]
    end
  end

  defp check_field(value, %{"type" => "integer"}, _defs, path) do
    if is_integer(value), do: [], else: ["#{path}: expected integer"]
  end

  defp check_field(value, %{"type" => "boolean"}, _defs, path) do
    if is_boolean(value), do: [], else: ["#{path}: expected boolean"]
  end

  defp check_field(value, %{"type" => "array"} = prop, defs, path) do
    if is_list(value) do
      too_long =
        case prop["maxLength"] do
          max when is_integer(max) and length(value) > max ->
            ["#{path}: at most #{max} items, got #{length(value)}"]

          _other ->
            []
        end

      items =
        value
        |> Enum.with_index()
        |> Enum.flat_map(fn {item, index} ->
          check_item(item, prop["items"] || %{}, defs, "#{path}[#{index}]")
        end)

      too_long ++ items
    else
      ["#{path}: expected array"]
    end
  end

  defp check_field(value, %{"type" => "object"} = prop, defs, path) do
    if is_map(value) do
      check_object(value, prop, defs, path)
    else
      ["#{path}: expected object"]
    end
  end

  defp check_field(value, %{"type" => "blob"}, _defs, path) do
    if is_map(value), do: [], else: ["#{path}: expected blob reference"]
  end

  defp check_field(value, %{"type" => "ref", "ref" => "#" <> name}, defs, path) do
    case defs[name] do
      %{} = schema when is_map(value) -> check_object(value, schema, defs, path)
      %{} -> ["#{path}: expected object"]
      nil -> []
    end
  end

  # External refs (com.atproto.repo.strongRef etc): shape guaranteed by
  # the network layer, presence of a map is all we check.
  defp check_field(value, %{"type" => "ref"}, _defs, path) do
    if is_map(value), do: [], else: ["#{path}: expected object"]
  end

  # Union (facets bsky + quintal): presença de mapa basta. Os membros
  # da union de facets são objetos sem `$type` próprio (quem tem `$type`
  # são as features dentro), então não dá pra fechar a união por aqui —
  # e client desconhecido ignora feature que não entende, mesmo.
  defp check_field(value, %{"type" => "union"}, _defs, path) do
    if is_map(value), do: [], else: ["#{path}: expected union object"]
  end

  defp check_field(_value, _prop, _defs, _path), do: []

  defp check_item(value, %{"type" => "object"} = prop, defs, path) do
    if is_map(value) do
      check_object(value, prop, defs, path)
    else
      ["#{path}: expected object"]
    end
  end

  defp check_item(value, %{"type" => "string"} = prop, defs, path) do
    check_field(value, %{"type" => "string"} = Map.merge(prop, %{}), defs, path)
  end

  defp check_item(value, %{"type" => "union"}, defs, path) do
    check_field(value, %{"type" => "union"}, defs, path)
  end

  defp check_item(_value, _items, _defs, _path), do: []

  defp check_string(value, prop, path) do
    check_max_graphemes(value, prop["maxGraphemes"], path) ++
      check_max_bytes(value, prop["maxLength"], path) ++
      check_known_values(value, prop["knownValues"], path) ++
      check_format(value, prop["format"], path)
  end

  defp check_max_graphemes(value, max, path) when is_integer(max) do
    count = value |> String.graphemes() |> length()
    if count > max, do: ["#{path}: at most #{max} graphemes, got #{count}"], else: []
  end

  defp check_max_graphemes(_value, _max, _path), do: []

  defp check_max_bytes(value, max, path) when is_integer(max) do
    if byte_size(value) > max, do: ["#{path}: at most #{max} bytes"], else: []
  end

  defp check_max_bytes(_value, _max, _path), do: []

  defp check_known_values(value, values, path) when is_list(values) do
    if value in values, do: [], else: ["#{path}: #{inspect(value)} not in #{inspect(values)}"]
  end

  defp check_known_values(_value, _values, _path), do: []

  defp check_format(value, "did", path) do
    if String.starts_with?(value, "did:"), do: [], else: ["#{path}: expected did"]
  end

  defp check_format(value, "datetime", path) do
    case DateTime.from_iso8601(value) do
      {:ok, _datetime, _offset} -> []
      {:error, _reason} -> ["#{path}: expected ISO 8601 datetime"]
    end
  end

  defp check_format(value, "uri", path) do
    case URI.parse(value) do
      %URI{scheme: scheme} when is_binary(scheme) -> []
      _other -> ["#{path}: expected uri"]
    end
  end

  defp check_format(_value, _format, _path), do: []
end
