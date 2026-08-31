defmodule QuintalWeb.EscreverLive do
  @moduledoc """
  A página de escrita: no mobile, qualquer entrada de texto é página,
  nunca overlay. Um componente, três contextos:

  - `/prosear` (`:prosear`): prosa nova, com chips de tipo. `?tipo=` abre
    direto num tipo: o ensaio é o modo foco e sempre mora aqui, até no
    desktop. `?reply=<uri>` vira resposta: a prosa-mãe aparece num card
    quieto no topo, com o fio da thread. `?editar=<uri>` vira edição: a
    prosa própria volta com o texto de sempre, sem chips nem título
    (tipo, reply e imagens ficam no record como estavam).
  - `/recadar` (`:recado`): recado no livro de visitas de um canto,
    `?para=<handle>`. Texto puro, limite curto, sem chips nem régua.

  Tudo em fluxo de documento: a barra com voltar e o pill de publicar
  desce junto com a página, o teclado abre e o browser rola, sem hack
  de viewport.
  """

  use QuintalWeb, :live_view

  import Ecto.Query, only: [from: 2]
  import QuintalWeb.Formatacao, only: [prosa_path: 2]
  import QuintalWeb.ProsearForm, only: [com_titulo: 2, imagens_dos_anexos: 2, audio_do_anexo: 1, limpa_links: 1]

  alias Quintal.Follows
  alias Quintal.Identidade
  alias Quintal.Prosa
  alias Quintal.Prosas
  alias Quintal.Recados
  alias Quintal.Repo

  require Logger

  @tipos ~w(nota pergunta cronica ensaio lero)

  @impl true
  def mount(params, _session, socket) do
    socket =
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
      |> assign(mencoes: Follows.mencoes(socket.assigns.sessao.did))

    case socket.assigns.live_action do
      :prosear -> monta_prosear(socket, params)
      :recado -> monta_recado(socket, params)
    end
  end

  defp monta_prosear(socket, params) do
    tipo = if params["tipo"] in @tipos, do: params["tipo"], else: "nota"

    cond do
      params["editar"] -> monta_edicao(socket, params["editar"])
      params["reply"] -> monta_resposta(socket, params["reply"], tipo)
      true -> monta_nova(socket, tipo)
    end
  end

  defp monta_nova(socket, tipo) do
    {:ok,
     assign(socket,
       modo: :prosa,
       tipo: tipo,
       mae: nil,
       canto: nil,
       texto_inicial: nil,
       voltar: "/inicio",
       placeholder: nil,
       maxlength: 10_000,
       rotulo: "prosear",
       rascunho: "quintal:rascunho",
       page_title: "prosear"
     )}
  end

  defp monta_resposta(socket, uri, tipo) do
    case Repo.get(Prosa, uri) do
      %Prosa{} = mae ->
        mae = Repo.preload(mae, :autor)

        {:ok,
         assign(socket,
           modo: :resposta,
           tipo: tipo,
           mae: mae,
           canto: nil,
           texto_inicial: nil,
           voltar: prosa_path(mae.uri, mae.autor.handle),
           placeholder: "responder com uma prosa...",
           maxlength: 10_000,
           rotulo: "responder",
           rascunho: "quintal:rascunho:responder:#{mae.uri}",
           page_title: "responder #{mae.autor.handle}"
         )}

      nil ->
        # mãe fora do índice: resposta sem contexto não faz sentido,
        # cai na prosa nova
        {:ok, push_navigate(socket, to: "/prosear")}
    end
  end

  # `?editar=<uri>`: a prosa volta pro composer com o texto de sempre.
  # Chips e título somem (modo :edicao renderiza como resposta): tipo,
  # reply e imagens ficam intocados no record salvo
  defp monta_edicao(socket, uri) do
    prosa = if uri =~ ~r/^at:\/\//, do: Repo.get(Prosa, uri)

    case prosa do
      %Prosa{autor_did: did} when did == socket.assigns.sessao.did ->
        prosa = Repo.preload(prosa, :autor)

        {:ok,
         assign(socket,
           modo: :edicao,
           tipo: prosa.tipo || "nota",
           mae: nil,
           canto: nil,
           editando: prosa,
           texto_inicial: prosa.texto,
           voltar: prosa_path(prosa.uri, prosa.autor.handle),
           placeholder: nil,
           maxlength: 10_000,
           rotulo: "salvar",
           rascunho: "quintal:rascunho:editar:#{prosa.uri}",
           page_title: "editar prosa"
         )}

      _alheia_ou_nada ->
        {:ok, push_navigate(socket, to: "/inicio")}
    end
  end

  defp monta_recado(socket, %{"para" => handle}) do
    sessao = socket.assigns.sessao
    identidade = Repo.one(from i in Identidade, where: i.handle == ^handle)

    cond do
      is_nil(identidade) ->
        {:ok, push_navigate(socket, to: "/inicio")}

      identidade.did == sessao.did ->
        # recado é pros outros; no próprio canto nem o atalho aparece
        {:ok, push_navigate(socket, to: "/canto/#{handle}")}

      true ->
        {:ok,
         assign(socket,
           modo: :recado,
           tipo: "nota",
           mae: nil,
           canto: handle,
           texto_inicial: nil,
           voltar: "/canto/#{handle}",
           placeholder: "deixa um recado pra #{handle}",
           maxlength: 500,
           rotulo: "recadar",
           rascunho: "quintal:rascunho:recado:#{identidade.did}",
           page_title: "recado pra #{handle}"
         )}
    end
  end

  defp monta_recado(socket, _params), do: {:ok, push_navigate(socket, to: "/inicio")}

  @impl true
  def handle_event("validar", _params, socket) do
    # o phx-change existe pras entradas de upload aparecerem; a validação
    # de verdade (alt em toda imagem) acontece no escrever
    {:noreply, socket}
  end

  def handle_event("remover-imagem", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :imagens, ref)}
  end

  def handle_event("remover-audio", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :audio, ref)}
  end

  def handle_event("escrever", %{"texto" => texto} = params, socket) do
    {texto, tirou?} = limpa_links(texto)

    case publicar(socket.assigns.modo, socket, texto, params) do
      {:ok, _registro} ->
        {:noreply,
         socket
         |> put_flash(:info, flash_sucesso(socket.assigns.modo, tirou?))
         |> push_event("composer-publicado", %{})
         |> push_navigate(to: socket.assigns.voltar)}

      {:error, :alt_faltando} ->
        {:noreply, put_flash(socket, :error, "descreve cada imagem pra quem não vê, aí a gente prosa")}

      {:error, :audio_faltando} ->
        {:noreply, put_flash(socket, :error, "lero é prosa falada: grava um áudio antes de prosear")}

      {:error, :mae_fora_do_indice} ->
        {:noreply, put_flash(socket, :error, "a prosa que você respondeu não tá mais aqui. recarrega e tenta de novo?")}

      {:error, reason} ->
        Logger.warning("[#{__MODULE__}] escrever falhou (#{socket.assigns.modo}): #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  defp publicar(:prosa, socket, texto, params) do
    texto = com_titulo(texto, params)

    with {:ok, imagens} <- imagens_dos_anexos(socket, params),
         {:ok, audio} <- audio_do_anexo(socket) do
      Prosas.prosear(socket.assigns.sessao, texto, Map.get(params, "tipo"), imagens, audio)
    end
  end

  defp publicar(:edicao, socket, texto, _params) do
    Prosas.editar(socket.assigns.sessao, socket.assigns.editando.uri, texto)
  end

  defp publicar(:resposta, socket, texto, _params) do
    Prosas.responder(socket.assigns.sessao, socket.assigns.mae, texto)
  end

  defp publicar(:recado, socket, texto, _params) do
    Recados.deixar(socket.assigns.sessao, socket.assigns.canto, texto)
  end

  @links_de_fora ". os links de instagram, tiktok e shorts ficaram de fora, aqui eles não tocam"

  defp flash_sucesso(:recado, _tirou), do: "pronto, seu recado tá no livro de visitas"
  defp flash_sucesso(:edicao, true), do: "pronto, sua prosa tá atualizada" <> @links_de_fora
  defp flash_sucesso(:edicao, _nao), do: "pronto, sua prosa tá atualizada"
  defp flash_sucesso(_modo, true), do: "pronto, sua prosa tá no quintal" <> @links_de_fora
  defp flash_sucesso(_modo, _nao), do: "pronto, sua prosa tá no quintal"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} moldura={false}>
      <.composer
        pagina
        modo={@modo}
        tipo={@tipo}
        mae={@mae}
        canto={@canto}
        texto_inicial={@texto_inicial}
        voltar={@voltar}
        placeholder={@placeholder}
        maxlength={@maxlength}
        rotulo={@rotulo}
        rascunho={@rascunho}
        mencoes={@mencoes}
        uploads={@uploads}
      />
    </Layouts.app>
    """
  end
end
