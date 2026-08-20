defmodule QuintalWeb.CantoLive do
  @moduledoc """
  O canto: a casa da pessoa (briefing 5.3).

  Visitação: cabeçalho quieto com o nome do canto em fraunces (o `nome`
  de exibição quando existe, o handle sempre em sussurro), bio de uma
  linha, links em sussurro, e os blocos na ordem que o dono escolheu
  (prosas, recados, cumadis que recomendo). Bio e links moram no
  cabeçalho, fora do rodízio de blocos. Depoimentos aceitos moram em
  seção própria no fim, não pendurados em outro bloco. O tema do canto
  (papel, madrugada, gloss) e a cor de acento vivem num wrapper com
  `data-theme`, de onde as variáveis cascateiam (spec 7.2).

  Modo arrumar (só no próprio canto, logado): edição in place, nunca um
  painel distante. Nome e bio se editam no próprio cabeçalho; pill
  flutuante na base com os três presets como swatches nomeados, cor de
  acento e o "pronto"; os blocos vestem borda tracejada lilás, com
  alça de arrastar e olho no hover (desktop) e setas no mobile. Salvar
  é automático a cada mudança, com um "guardado" quieto que aparece e
  some.
  """

  use QuintalWeb, :live_view

  import Ecto.Query, only: [from: 2]

  import QuintalWeb.Formatacao,
    only: [tempo_relativo: 1, data_curta: 1, primeira_frase: 1, prosa_path: 2]

  alias Quintal.Blogrolls
  alias Quintal.Canto
  alias Quintal.Cantos
  alias Quintal.Depoimentos
  alias Quintal.Follows
  alias Quintal.Identidade
  alias Quintal.Prosas
  alias Quintal.Recados
  alias Quintal.Repo
  alias Quintal.Visitas
  alias QuintalWeb.Markdown

  require Logger

  # bio e links saíram do rodízio: moram no cabeçalho, sempre visíveis.
  # records antigos ainda podem trazê-los em blocos, o filtro trata disso.
  @blocos_todos ~w(prosas recados quem-eu-leio)
  @blocos_default ~w(prosas recados quem-eu-leio)
  @recados_pagina 20

  # swatches do modo arrumar: fundo e acento de cada preset (spec 7.2)
  @presets %{
    "papel" => %{fundo: "#faf6f1", acento: "#8b7bb8"},
    "madrugada" => %{fundo: "#14101c", acento: "#b9a7e0"},
    "gloss" => %{fundo: "#fff5fa", acento: "#ff6fb5"}
  }

  @impl true
  def mount(%{"handle" => handle}, _session, socket) do
    sessao = socket.assigns.sessao
    novidade = if sessao, do: Visitas.novidade?(sessao.did), else: false

    case Repo.one(from i in Identidade, where: i.handle == ^handle) do
      nil ->
        {:ok,
         assign(socket,
           novidade: novidade,
           encontrou: false,
           page_title: "canto não encontrado"
         )}

      %Identidade{} = dono ->
        viewer_did = sessao && sessao.did
        proprio? = sessao != nil && sessao.did == dono.did

        canto =
          normaliza_blocos(
            Cantos.get(dono.did) || %Canto{dono_did: dono.did, tema: "papel", blocos: @blocos_default, links: []}
          )

        seguindo = seguindo(sessao, proprio?, dono.did)

        prosas = Prosas.list_por_autor(dono.did, limit: 20)

        {:ok,
         assign(socket,
           novidade: novidade,
           encontrou: true,
           page_title: "canto de #{dono.handle}",
           dono: dono,
           canto: canto,
           proprio?: proprio?,
           arrumar: false,
           guardado_seq: 0,
           seguindo: seguindo,
           prosas: prosas,
           recados: Recados.listar_por_canto(dono.did, viewer_did),
           recados_visiveis: @recados_pagina,
           depoimentos: Depoimentos.aceitos(dono.did),
           depoimento_form: false,
           blogroll_items: blogroll_items(dono.did)
         )}
    end
  end

  @impl true
  def handle_event("apagar_prosa", %{"uri" => uri}, socket) do
    case Prosas.apagar(socket.assigns.sessao, uri) do
      :ok ->
        {:noreply, update(socket, :prosas, &Enum.reject(&1, fn prosa -> prosa.uri == uri end))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("mais_recados", _params, socket) do
    {:noreply, update(socket, :recados_visiveis, &(&1 + @recados_pagina))}
  end

  def handle_event("deixar_recado", %{"texto" => texto}, socket) do
    case Recados.deixar(socket.assigns.sessao, socket.assigns.dono.handle, texto) do
      {:ok, recado} ->
        {:noreply,
         socket
         |> update(:recados, &[recado | &1])
         |> push_event("composer-publicado", %{})}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("ocultar_recado", %{"uri" => uri}, socket) do
    case Recados.ocultar(socket.assigns.sessao, uri) do
      {:ok, _recado} -> {:noreply, marcar_recado(socket, uri, true)}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("mostrar_recado", %{"uri" => uri}, socket) do
    case Recados.mostrar(socket.assigns.sessao, uri) do
      {:ok, _recado} -> {:noreply, marcar_recado(socket, uri, false)}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("seguir", _params, socket) do
    case Follows.seguir(socket.assigns.sessao, socket.assigns.dono.handle) do
      {:ok, follow} ->
        {:noreply, assign(socket, seguindo: follow)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("deixar_de_seguir", _params, socket) do
    case Follows.deixar_de_seguir(socket.assigns.sessao, socket.assigns.seguindo.uri) do
      :ok ->
        {:noreply, assign(socket, seguindo: nil)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("abrir_depoimento", _params, socket) do
    {:noreply, assign(socket, depoimento_form: true)}
  end

  def handle_event("deixar_depoimento", %{"texto" => texto}, socket) do
    case Depoimentos.deixar(socket.assigns.sessao, socket.assigns.dono.handle, texto) do
      {:ok, _depoimento} ->
        {:noreply,
         socket
         |> assign(depoimento_form: false)
         |> put_flash(:info, "pronto, seu depoimento espera o aceite do canto")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  def handle_event("arrumar", _params, %{assigns: %{proprio?: true}} = socket) do
    {:noreply, update(socket, :arrumar, &(!&1))}
  end

  def handle_event("arrumar", _params, socket), do: {:noreply, socket}

  def handle_event("tema", %{"tema" => tema}, socket) do
    if socket.assigns.proprio? do
      guardar(socket, %{tema: tema})
    else
      {:noreply, socket}
    end
  end

  def handle_event("cor", %{"cor" => cor}, socket) do
    if socket.assigns.proprio? do
      guardar(socket, %{cor: cor})
    else
      {:noreply, socket}
    end
  end

  # nome e bio se editam no próprio cabeçalho, em autosave como o resto
  def handle_event("cabeca", %{"nome" => nome, "bio" => bio}, socket) do
    if socket.assigns.proprio? do
      guardar(socket, %{nome: nome, bio: bio})
    else
      {:noreply, socket}
    end
  end

  def handle_event("alternar-bloco", %{"bloco" => bloco}, socket) do
    if socket.assigns.proprio? do
      blocos = socket.assigns.canto.blocos

      novos =
        if bloco in blocos do
          List.delete(blocos, bloco)
        else
          blocos ++ [bloco]
        end

      guardar(socket, %{blocos: novos})
    else
      {:noreply, socket}
    end
  end

  def handle_event("mover-bloco", %{"bloco" => bloco, "direcao" => direcao}, socket) do
    if socket.assigns.proprio? do
      canto = socket.assigns.canto
      visiveis = canto.blocos

      novos =
        canto
        |> ordem_blocos(true)
        |> mover(bloco, direcao)
        |> Enum.filter(&(&1 in visiveis))

      guardar(socket, %{blocos: novos})
    else
      {:noreply, socket}
    end
  end

  # drag and drop do desktop (hook ArrumarBlocos): a ordem chega com
  # cada bloco renderizado, inclusive os ocultos do modo arrumar
  def handle_event("reordenar", %{"ordem" => ordem}, socket) do
    if socket.assigns.proprio? do
      visiveis = socket.assigns.canto.blocos
      guardar(socket, %{blocos: Enum.filter(ordem, &(&1 in visiveis))})
    else
      {:noreply, socket}
    end
  end

  def handle_event("blogroll_remove", %{"did" => did}, socket) do
    items = Enum.reject(socket.assigns.blogroll_items, &(&1.did == did))
    atualizar_blogroll(socket, items)
  end

  def handle_event("blogroll_add", %{"handle" => handle, "note" => note}, socket) do
    handle = handle |> String.trim() |> String.trim_leading("@")

    case Repo.one(from i in Identidade, where: i.handle == ^handle) do
      nil ->
        {:noreply, put_flash(socket, :error, "esse canto ainda não mora no quintal")}

      %Identidade{} = identidade ->
        note = if String.trim(note) == "", do: nil, else: String.trim(note)
        items = socket.assigns.blogroll_items ++ [%{did: identidade.did, note: note, handle: identidade.handle}]
        payload = Enum.map(items, &%{did: &1.did, note: &1.note})

        case Blogrolls.atualizar(socket.assigns.sessao, payload) do
          {:ok, _blogroll} ->
            {:noreply,
             socket
             |> assign(blogroll_items: items)
             |> push_event("limpar-campo", %{id: "handle"})
             |> push_event("limpar-campo", %{id: "note"})}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
        end
    end
  end

  # autosave do modo arrumar: cada mudança já é a versão guardada
  defp guardar(socket, attrs) do
    case Cantos.arrumar(socket.assigns.sessao, attrs) do
      {:ok, canto} ->
        {:noreply,
         socket
         |> assign(canto: normaliza_blocos(canto))
         |> update(:guardado_seq, &(&1 + 1))
         |> push_event("aplicar-tema", %{tema: canto.tema, cor: canto.cor})}

      {:error, reason} ->
        Logger.warning("[#{__MODULE__}] falha ao arrumar o canto: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  defp atualizar_blogroll(socket, items) do
    payload = Enum.map(items, &%{did: &1.did, note: &1.note})

    case Blogrolls.atualizar(socket.assigns.sessao, payload) do
      {:ok, _blogroll} ->
        {:noreply, assign(socket, blogroll_items: items)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ih, algo deu errado. tenta de novo?")}
    end
  end

  defp marcar_recado(socket, uri, oculto) do
    update(socket, :recados, &Enum.map(&1, fn recado -> marca_oculto(recado, uri, oculto) end))
  end

  defp marca_oculto(%{uri: uri} = recado, uri, oculto), do: %{recado | oculto: oculto}
  defp marca_oculto(recado, _uri, _oculto), do: recado

  # no card o tipo é metadado; no índice do canto ele vira chip miúdo,
  # com o acento que o valor do lexicon não tem
  defp rotulo_tipo("cronica"), do: "crônica"
  defp rotulo_tipo(tipo), do: tipo

  # o follow da pessoa logada nesse canto, se existe: uma query, sem
  # carregar a vizinhança inteira pra testar uma ponta
  defp seguindo(nil, _proprio?, _dono_did), do: nil
  defp seguindo(_sessao, true, _dono_did), do: nil

  defp seguindo(sessao, false, dono_did) do
    Repo.one(
      from f in Quintal.Follow,
        where: f.seguidor_did == ^sessao.did and f.seguido_did == ^dono_did
    )
  end

  # blogroll com os dids resolvidos para handle via índice de identidades
  defp blogroll_items(dono_did) do
    items =
      case Blogrolls.get(dono_did) do
        nil -> []
        blogroll -> blogroll.items
      end

    dids = Enum.map(items, & &1.did)

    handles =
      Map.new(Repo.all(from i in Identidade, where: i.did in ^dids, select: {i.did, i.handle}))

    Enum.map(items, fn item ->
      %{did: item.did, note: item.note, handle: Map.get(handles, item.did, item.did)}
    end)
  end

  # blocos que a interface conhece: records antigos podem trazer "bio"
  # de quando ela era bloco; hoje ela mora no cabeçalho
  defp normaliza_blocos(%Canto{blocos: blocos} = canto) when is_list(blocos) do
    %{canto | blocos: Enum.filter(blocos, &(&1 in @blocos_todos))}
  end

  defp normaliza_blocos(canto), do: canto

  # no modo arrumar todos os blocos aparecem (os ocultos, esmaecidos, no
  # fim), para o dono ver o que está escondido; na visitação, só os visíveis
  defp ordem_blocos(canto, true), do: canto.blocos ++ (@blocos_todos -- canto.blocos)
  defp ordem_blocos(canto, false), do: canto.blocos

  defp mover(ordem, bloco, direcao) do
    delta = if direcao == "sobe", do: -1, else: 1

    case Enum.find_index(ordem, &(&1 == bloco)) do
      nil ->
        ordem

      i ->
        j = i + delta

        if j >= 0 && j < length(ordem) do
          ordem
          |> List.replace_at(i, Enum.at(ordem, j))
          |> List.replace_at(j, bloco)
        else
          ordem
        end
    end
  end

  # o recado recém-deixado ainda não tem a identidade carregada: mostra
  # o próprio handle até o eco da firehose confirmar no índice
  defp autor_recado(%{autor: %{handle: handle}}, _eu), do: handle
  defp autor_recado(_recado, eu), do: eu

  # em ~H, `@presets` vira lookup de assign: o attr precisa de helper
  defp presets, do: @presets

  defp acento_padrao(tema), do: @presets[tema].acento

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} sessao={@sessao} novidade={@novidade}>
      <.vazio
        :if={!@encontrou}
        pose={:lupa}
        titulo="o axô procurou, procurou... e não achou esse canto"
      >
        <.link navigate={~p"/inicio"} class="botao botao--fantasma">voltar pro início</.link>
      </.vazio>

      <div
        :if={@encontrou}
        class="canto-tema"
        data-theme={if @canto.tema != "papel", do: @canto.tema}
        style={@canto.cor && "--acento: #{@canto.cor}"}
      >
        <div :if={@arrumar} class="arrumar__barra">
          <div class="arrumar__temas">
            <button
              :for={{tema, preset} <- presets()}
              type="button"
              class={["arrumar__tema", @canto.tema == tema && "arrumar__tema--selecionado"]}
              phx-click="tema"
              phx-value-tema={tema}
              aria-pressed={@canto.tema == tema}
            >
              <span
                class="arrumar__mini"
                style={"background: #{preset.fundo}; border-color: #{preset.acento}"}
                aria-hidden="true"
              ></span>
              {tema}
            </button>
          </div>

          <input
            type="color"
            name="cor"
            class="arrumar__cor"
            aria-label="cor de acento"
            value={@canto.cor || acento_padrao(@canto.tema)}
            phx-change="cor"
            phx-debounce="300"
          />

          <span :if={@guardado_seq > 0} id={"guardado-#{@guardado_seq}"} class="guardado">
            guardado
          </span>

          <.botao phx-click="arrumar" class="arrumar__pronto">pronto</.botao>
        </div>

        <header class="canto__cabeca">
          <div class="canto__titulo">
            <div class="canto__identidade">
              <h1 class="canto__nome">{@canto.nome || @dono.handle}</h1>
              <p :if={@canto.nome} class="canto__handle">{@dono.handle}</p>
            </div>
            <div class="canto__acoes">
              <.botao
                :if={@sessao && !@proprio? && !@seguindo}
                variante={:fantasma}
                phx-click="seguir"
              >
                seguir esse canto
              </.botao>
              <.botao
                :if={@sessao && !@proprio? && @seguindo}
                variante={:sutil}
                phx-click="deixar_de_seguir"
                data-confirm="deixar de ler esse canto? as prosas dele somem do seu início."
              >
                você lê esse canto
              </.botao>
              <.botao :if={@proprio? && !@arrumar} variante={:fantasma} phx-click="arrumar">
                arrumar o canto
              </.botao>
            </div>
          </div>

          <%!-- nome e bio se editam aqui mesmo, no lugar: o canto se
               arruma como é visto, nunca num painel distante --%>
          <form :if={@arrumar} phx-change="cabeca" phx-debounce="600" class="canto__cabeca-form">
            <.campo
              name="nome"
              label="nome do canto (só aparece no quintal)"
              value={@canto.nome}
              placeholder={@dono.handle}
              maxlength="60"
            />
            <.campo
              name="bio"
              area
              label="bio"
              value={@canto.bio}
              placeholder="uma linha sobre você, pra quem passar saber quem mora aqui"
              rows="2"
              maxlength="500"
            />
          </form>

          <div :if={!@arrumar && @canto.bio} class="canto__bio">{Markdown.render(@canto.bio)}</div>

          <p :if={@canto.links != []} class="canto__links">
            <a :for={link <- @canto.links} href={link.url} target="_blank" rel="noopener">
              {link.titulo}
            </a>
          </p>
        </header>

        <div
          class={["canto-blocos", @arrumar && "canto-blocos--arrumando"]}
          id="canto-blocos"
          phx-hook={@arrumar && "ArrumarBlocos"}
        >
          <section
            :for={bloco <- ordem_blocos(@canto, @arrumar)}
            class={["canto-bloco", @arrumar && bloco not in @canto.blocos && "canto-bloco--oculto"]}
            data-bloco={bloco}
            draggable={@arrumar && "true"}
          >
            <div :if={@arrumar} class="canto-bloco__controles">
              <span class="canto-bloco__alca" aria-hidden="true">
                <Lucideicons.grip_vertical />
              </span>
              <span class="canto-bloco__grupo">
                <button
                  type="button"
                  class="icone-botao canto-bloco__seta"
                  phx-click="mover-bloco"
                  phx-value-bloco={bloco}
                  phx-value-direcao="sobe"
                  aria-label="subir bloco"
                >
                  <Lucideicons.chevron_up aria-hidden="true" />
                </button>
                <button
                  type="button"
                  class="icone-botao canto-bloco__seta"
                  phx-click="mover-bloco"
                  phx-value-bloco={bloco}
                  phx-value-direcao="desce"
                  aria-label="descer bloco"
                >
                  <Lucideicons.chevron_down aria-hidden="true" />
                </button>
                <button
                  type="button"
                  class="icone-botao"
                  phx-click="alternar-bloco"
                  phx-value-bloco={bloco}
                  aria-label={if bloco in @canto.blocos, do: "ocultar bloco", else: "mostrar bloco"}
                >
                  <Lucideicons.eye_off :if={bloco in @canto.blocos} aria-hidden="true" />
                  <Lucideicons.eye :if={bloco not in @canto.blocos} aria-hidden="true" />
                </button>
              </span>
            </div>

            <%= case bloco do %>
              <% "prosas" -> %>
                <ul class="indice">
                  <li :for={prosa <- @prosas} class="indice__item">
                    <.link
                      navigate={prosa_path(prosa.uri, @dono.handle)}
                      class="indice__linha"
                    >
                      <time class="indice__data">{data_curta(prosa.created_at)}</time>
                      <span class="indice__frase">{Markdown.render_inline(primeira_frase(prosa.texto))}</span>
                      <span :if={prosa.tipo not in [nil, "nota"]} class="indice__tipo">{rotulo_tipo(
                        prosa.tipo
                      )}</span>
                    </.link>
                    <button
                      :if={@arrumar}
                      type="button"
                      class="icone-botao indice__apagar"
                      phx-click="apagar_prosa"
                      phx-value-uri={prosa.uri}
                      data-confirm="apagar essa prosa? ela sai do seu pds também."
                      aria-label="apagar prosa"
                    >
                      <Lucideicons.trash_2 aria-hidden="true" />
                    </button>
                  </li>
                </ul>
              <% "recados" -> %>
                <h2 class="canto-bloco__titulo">recados</h2>
                <div class="recados">
                  <div
                    :for={recado <- Enum.take(@recados, @recados_visiveis)}
                    class={["recados__item", recado.oculto && "recado--oculto"]}
                  >
                    <.recado
                      autor={autor_recado(recado, @sessao && Map.get(@sessao, :handle))}
                      data={tempo_relativo(recado.created_at)}
                    >
                      {Markdown.render(recado.texto)}
                    </.recado>
                    <button
                      :if={@proprio?}
                      type="button"
                      class="icone-botao recados__olho"
                      phx-click={if recado.oculto, do: "mostrar_recado", else: "ocultar_recado"}
                      phx-value-uri={recado.uri}
                      aria-label={if recado.oculto, do: "mostrar recado", else: "ocultar recado"}
                    >
                      <Lucideicons.eye :if={recado.oculto} aria-hidden="true" />
                      <Lucideicons.eye_off :if={!recado.oculto} aria-hidden="true" />
                    </button>
                  </div>

                  <p :if={@recados == []} class="recados__vazio">
                    ainda não tem recados por aqui. o livro de visitas tá aberto.
                  </p>

                  <p :if={length(@recados) > @recados_visiveis} class="recados__mais">
                    <.botao variante={:sutil} phx-click="mais_recados">ver mais recados</.botao>
                  </p>

                  <%!-- no mobile o recado é página (/recadar?para=);
                       no desktop o form inline cresce no fluxo --%>
                  <.link
                    :if={@sessao && !@proprio?}
                    navigate={~p"/recadar?para=#{@dono.handle}"}
                    class="prosear-atalho recados__atalho"
                  >
                    <span class="prosear-atalho__placeholder">escreve aqui teu recado...</span>
                  </.link>

                  <form
                    :if={@sessao && !@proprio?}
                    id="recado"
                    phx-submit="deixar_recado"
                    phx-hook="Composer"
                    class="prosear recados__form"
                    data-rascunho={"quintal:rascunho:recado:#{@dono.did}"}
                  >
                    <.campo
                      name="texto"
                      area
                      aria-label="deixar um recado"
                      placeholder="escreve aqui teu recado..."
                      rows="1"
                      maxlength="500"
                      required
                    />
                    <.md_ferramentas />
                    <div class="prosear__rodape">
                      <div class="prosear__ferramentas">
                        <span class="prosear__atalho" aria-hidden="true">ctrl+enter pra deixar</span>
                        <.botao type="submit">recadar</.botao>
                      </div>
                    </div>
                  </form>
                  <p :if={!@sessao} class="recados__convite">
                    <.link href={~p"/"}>entra com atproto</.link> pra deixar um recado
                  </p>
                </div>
              <% "quem-eu-leio" -> %>
                <h2 class="canto-bloco__titulo">cumadis que recomendo</h2>
                <p :if={@blogroll_items == [] && !@arrumar} class="quem-leio__vazio">
                  ainda não tem ninguém aqui. recomendar alguém é o jeito mais bonito de
                  apresentar a vizinhança.
                </p>
                <ul class="quem-leio">
                  <li :for={item <- @blogroll_items}>
                    <.link navigate={~p"/canto/#{item.handle}"}>{item.handle}</.link>
                    <span :if={item.note} class="quem-leio__nota">{item.note}</span>
                    <button
                      :if={@arrumar}
                      type="button"
                      class="icone-botao"
                      phx-click="blogroll_remove"
                      phx-value-did={item.did}
                      aria-label={"tirar #{item.handle} das cumadis"}
                    >
                      <Lucideicons.x aria-hidden="true" />
                    </button>
                  </li>
                </ul>

                <form :if={@arrumar} phx-submit="blogroll_add" class="quem-leio__form">
                  <.campo
                    name="handle"
                    label="handle do canto"
                    placeholder="fulana.bsky.social"
                    required
                  />
                  <.campo name="note" label="nota (opcional)" placeholder="leio sempre" />
                  <.botao variante={:fantasma} type="submit">adicionar</.botao>
                </form>
            <% end %>
          </section>
        </div>

        <%!-- depoimentos não são bloco: não entram no rodízio nem somem
             com ele. parede própria no fim do canto --%>
        <section :if={@depoimentos != [] || (@sessao && !@proprio?)} class="canto-bloco">
          <h2 class="canto-bloco__titulo">depoimentos</h2>

          <div :if={@depoimentos != []} class="depoimentos">
            <blockquote :for={depoimento <- @depoimentos} class="depoimento">
              {Markdown.render(depoimento.texto)}
              <footer>
                <.link navigate={~p"/canto/#{depoimento.autor.handle}"}>
                  {depoimento.autor.handle}
                </.link>
              </footer>
            </blockquote>
          </div>

          <div :if={@sessao && !@proprio?} class="depoimento-form">
            <.botao :if={!@depoimento_form} variante={:sutil} phx-click="abrir_depoimento">
              deixar um depoimento
            </.botao>
            <form
              :if={@depoimento_form}
              id="depoimento"
              phx-submit="deixar_depoimento"
              phx-hook="MdToolbar"
            >
              <div class="campo">
                <label class="campo__label" for="depoimento-texto">seu depoimento</label>
                <textarea
                  id="depoimento-texto"
                  name="texto"
                  class="campo__area"
                  rows="3"
                  maxlength="1000"
                  required
                  placeholder="o dono do canto aceita antes de pendurar na parede"
                ></textarea>
              </div>
              <.md_ferramentas />
              <.botao variante={:fantasma} type="submit">enviar depoimento</.botao>
            </form>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
