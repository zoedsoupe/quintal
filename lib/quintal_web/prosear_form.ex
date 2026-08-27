defmodule QuintalWeb.ProsearForm do
  @moduledoc """
  Os bastidores do ato de escrever, divididos entre a home (card inline
  no desktop) e a página de escrita (`/prosear`, `/recadar`): título de
  ensaio virando heading markdown e anexos subindo como blobs pro pds da
  pessoa antes do record sair de casa.
  """

  import Phoenix.LiveView, only: [uploaded_entries: 2, consume_uploaded_entries: 3]

  # ensaio tem título opcional e o record não tem campo pra ele: vira o
  # heading markdown que abre o texto (h2, o nível que o card já estiliza)
  def com_titulo(texto, %{"tipo" => "ensaio", "titulo" => titulo}) do
    case String.trim(titulo || "") do
      "" -> texto
      titulo -> "## #{titulo}\n\n#{texto}"
    end
  end

  def com_titulo(texto, _params), do: texto

  # cada anexo sobe como blob pro pds da pessoa e vira um item `images`
  # do record (spec 10.1); sem alt em alguma, nada sai de casa
  def imagens_dos_anexos(socket, params) do
    case uploaded_entries(socket, :imagens) do
      {[], []} ->
        {:ok, []}

      {entradas, _em_progresso} ->
        alts = Map.new(entradas, &{&1.ref, String.trim(params["alt-#{&1.ref}"] || "")})

        if Enum.any?(entradas, &(alts[&1.ref] == "")) do
          {:error, :alt_faltando}
        else
          subir_anexos(socket, alts)
        end
    end
  end

  defp subir_anexos(socket, alts) do
    arquivos =
      consume_uploaded_entries(socket, :imagens, fn %{path: path}, entry ->
        {:ok, %{bin: File.read!(path), tipo: entry.client_type, alt: alts[entry.ref]}}
      end)

    subir_imagens(socket.assigns.sessao, arquivos)
  end

  defp subir_imagens(sessao, arquivos) do
    Enum.reduce_while(arquivos, {:ok, []}, fn %{bin: bin, tipo: tipo, alt: alt}, {:ok, acc} ->
      case Quintal.PDS.impl().upload_blob(sessao, bin, tipo) do
        {:ok, resposta} -> {:cont, {:ok, acc ++ [%{"image" => blob_lexicon(resposta), "alt" => alt}]}}
        {:error, _reason} = erro -> {:halt, erro}
      end
    end)
  end

  # a resposta do uploadBlob chega decodificada pelo proto_rune; o record
  # precisa do blob no formato do lexicon, com chaves string
  def blob_lexicon(resposta) do
    blob = resposta[:blob] || resposta["blob"] || resposta

    %{
      "$type" => "blob",
      "ref" => %{"$link" => get_in(blob, [:ref, :"$link"]) || get_in(blob, ["ref", "$link"])},
      "mimeType" => blob[:mime_type] || blob["mimeType"],
      "size" => blob[:size] || blob["size"]
    }
  end
end
