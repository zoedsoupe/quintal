defmodule QuintalWeb.ProsearForm do
  @moduledoc """
  Os bastidores do ato de escrever, divididos entre a home (card inline
  no desktop) e a página de escrita (`/prosear`, `/recadar`): título de
  ensaio virando heading markdown, anexos subindo como blobs pro pds da
  pessoa antes do record sair de casa e links de fora que não tocam
  aqui (instagram, tiktok, shorts) saindo do texto.
  """

  import Phoenix.LiveView, only: [uploaded_entries: 2, consume_uploaded_entries: 3, allow_upload: 3]

  # links que não entram no quintal: embed fechado, tracking pesado.
  # shorts é a única porta do youtube que fica de fora
  @bloqueados ~r/https?:\/\/(?:[\w-]+\.)?(?:instagram\.com|tiktok\.com)\S*|https?:\/\/(?:[\w-]+\.)?youtube\.com\/shorts\/\S*/

  @doc """
  Abre os dois anexos do ato de escrever, com os mesmos limites em toda
  parte: até 4 imagens de 2MB e um áudio de 20MB.
  """
  def permitir_anexos(socket) do
    socket
    |> allow_upload(:imagens,
      accept: ~w(image/jpeg image/png image/webp),
      max_entries: 4,
      max_file_size: 2_000_000
    )
    |> allow_upload(:audio,
      accept: ~w(audio/mpeg audio/mp4 audio/ogg audio/webm audio/wav),
      max_entries: 1,
      max_file_size: 20_000_000
    )
  end

  @doc """
  Tira do texto os links que o quintal não embute (instagram, tiktok,
  shorts) e devolve `{texto, tirou?}`. O `tirou?` vira flash, porque
  mexer no texto da pessoa sem avisar não rola.
  """
  def limpa_links(texto) when is_binary(texto) do
    if Regex.match?(@bloqueados, texto) do
      limpo =
        texto
        |> String.replace(@bloqueados, "")
        |> String.replace(~r/\n{3,}/, "\n\n")
        |> String.trim()

      {limpo, true}
    else
      {texto, false}
    end
  end

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

  # o áudio é 0..1 por prosa: sobe como blob pro pds e vira o campo
  # `audio` do record; sem anexo o campo nem existe. o lexicon aceita
  # `alt` opcional, e a UI de descrição entra quando pedir
  def audio_do_anexo(socket) do
    case uploaded_entries(socket, :audio) do
      {[], []} ->
        {:ok, nil}

      # submit chegou com o upload ainda em voo (rede lenta, preflight
      # atrasado): falha amiga em vez de derrubar a LiveView
      {[], _em_progresso} ->
        {:error, :audio_faltando}

      {[_entry | _], _em_progresso} ->
        [%{bin: bin, tipo: tipo}] =
          consume_uploaded_entries(socket, :audio, fn %{path: path}, entry ->
            {:ok, %{bin: File.read!(path), tipo: entry.client_type}}
          end)

        case Quintal.PDS.impl().upload_blob(socket.assigns.sessao, bin, tipo) do
          {:ok, resposta} -> {:ok, %{"audio" => blob_lexicon(resposta)}}
          {:error, _reason} = erro -> erro
        end
    end
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

  @erros %{
    alt_faltando: "descreve a imagem pra quem não vê, aí a gente proseia",
    audio_faltando: "lero é prosa falada: grava um áudio antes de prosear",
    audio_so_lero: "áudio é do lero só: troca o tipo ou tira o áudio",
    mae_fora_do_indice: "a prosa que você respondeu não tá mais aqui. recarrega e tenta de novo?"
  }

  @generico "ih, algo deu errado. tenta de novo?"

  @doc """
  A frase que a pessoa lê quando o ato de escrever falha. Mesma tabela
  nas três superfícies: home, página de escrita e thread.
  """
  def erro(razao), do: Map.get(@erros, razao, @generico)
end
