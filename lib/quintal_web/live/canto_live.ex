defmodule QuintalWeb.CantoLive do
  @moduledoc """
  O canto: a casa da pessoa (briefing 5.3).

  Visitação: cabeçalho quieto com o nome do canto em fraunces, bio de
  uma linha, links em sussurro, e os blocos na ordem que o dono
  escolheu (bio, prosas, recados, cumadis que recomendo, links). O
  tema do canto (papel, madrugada, gloss) e a cor de acento vivem num
  wrapper com `data-theme`, de onde as variáveis cascateiam (spec 7.2).

  Modo arrumar (só no próprio canto, logado): edição in place, nunca um
  painel distante. Swatches dos três presets, cor de acento, olho para
  ocultar bloco, setas no mobile e drag and drop no desktop. Salvar é
  automático a cada mudança, com um "guardado" quieto que aparece e some.
  """

  use QuintalWeb, :live_view

  import Ecto.Query, only: [from: 2]

  import QuintalWeb.Formatacao,
    only: [tempo_relativo: 1, trecho: 1, prosa_path: 2, imagens_card: 1]

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

  require Logger

  @blocos_todos ~w(bio prosas recados quem-eu-leio links)
  @blocos_default ~w(bio prosas recados quem-eu-leio links)
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
          Cantos.get(dono.did) ||
            %Canto{dono_did: dono.did, tema: "papel", blocos: @blocos_default, links: []}

        seguindo =
          if sessao && !proprio? do
            Enum.find(Follows.vizinhanca(sessao.did), &(&1.seguido_did == dono.did))
          end

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
           contagens: Prosas.contar_respostas(Enum.map(prosas, & &1.uri)),
           pais:
             prosas
             |> Enum.map(& &1.reply_parent)
             |> Enum.reject(&is_nil/1)
             |> Enum.uniq()
             |> Prosas.pais(),
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
         |> push_event("limpar-campo", %{id: "texto"})}

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

  def handle_event("arrumar", _params, socket) do
    {:noreply, update(socket, :arrumar, &(!&1))}
  end

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
         |> assign(canto: canto)
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
      />

      <div
        :if={@encontrou}
        class="canto-tema"
        data-theme={if @canto.tema != "papel", do: @canto.tema}
        style={@canto.cor && "--acento: #{@canto.cor}"}
      >
        <div :if={@arrumar} class="arrumar__barra">
          <button
            :for={{tema, preset} <- presets()}
            type="button"
            class={["arrumar__tema", @canto.tema == tema && "arrumar__tema--selecionado"]}
            style={"background: #{preset.fundo}; border-color: #{preset.acento}"}
            phx-click="tema"
            phx-value-tema={tema}
            aria-label={"tema #{tema}"}
          ></button>

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

          <.botao variante={:sutil} phx-click="arrumar" class="arrumar__pronto">pronto</.botao>
        </div>

        <header class="canto__cabeca">
          <h1 class="canto__nome">{@dono.handle}</h1>
          <p :if={@canto.bio} class="canto__bio">{@canto.bio}</p>

          <p :if={@canto.links != []} class="canto__links">
            <a :for={link <- @canto.links} href={link.url} target="_blank" rel="noopener">
              {link.titulo}
            </a>
          </p>

          <div class="canto__acoes">
            <.botao :if={@sessao && !@proprio? && !@seguindo} variante={:fantasma} phx-click="seguir">
              seguir esse canto
            </.botao>
            <.botao
              :if={@sessao && !@proprio? && @seguindo}
              variante={:sutil}
              phx-click="deixar_de_seguir"
            >
              você lê esse canto
            </.botao>
            <.botao :if={@proprio? && !@arrumar} variante={:sutil} phx-click="arrumar">
              arrumar o canto
            </.botao>
          </div>
        </header>

        <div class="canto-blocos" id="canto-blocos" phx-hook={@arrumar && "ArrumarBlocos"}>
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
              <button
                type="button"
                class="icone-botao"
                phx-click="mover-bloco"
                phx-value-bloco={bloco}
                phx-value-direcao="sobe"
                aria-label="subir bloco"
              >
                <Lucideicons.chevron_up aria-hidden="true" />
              </button>
              <button
                type="button"
                class="icone-botao"
                phx-click="mover-bloco"
                phx-value-bloco={bloco}
                phx-value-direcao="desce"
                aria-label="descer bloco"
              >
                <Lucideicons.chevron_down aria-hidden="true" />
              </button>
            </div>

            <%= case bloco do %>
              <% "bio" -> %>
                <p :if={@canto.bio} class="canto-bio__texto">{@canto.bio}</p>
                <p :if={@arrumar && !@canto.bio} class="canto-bio__texto canto-bio__texto--vazio">
                  sua bio aparece aqui
                </p>
              <% "prosas" -> %>
                <div class="feed">
                  <div :for={prosa <- @prosas} class="feed__item">
                    <% {texto, cortou?} = trecho(prosa.texto) %>
                    <.prosa
                      autor={@dono.handle}
                      data={tempo_relativo(prosa.created_at)}
                      path={prosa_path(prosa.uri, @dono.handle)}
                      cortou={cortou?}
                      respostas={Map.get(@contagens, prosa.uri, 0)}
                      em_resposta={prosa.reply_parent && Map.get(@pais, prosa.reply_parent)}
                      imagens={imagens_card(prosa)}
                    >
                      <:acoes :if={@proprio?}>
                        <button
                          type="button"
                          class="icone-botao"
                          phx-click="apagar_prosa"
                          phx-value-uri={prosa.uri}
                          data-confirm="apagar essa prosa? ela sai do seu pds também."
                          aria-label="apagar prosa"
                        >
                          <Lucideicons.trash_2 aria-hidden="true" />
                        </button>
                      </:acoes>
                      {texto}
                    </.prosa>
                  </div>
                </div>
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
                      {recado.texto}
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

                  <p :if={length(@recados) > @recados_visiveis} class="recados__mais">
                    <.botao variante={:sutil} phx-click="mais_recados">ver mais recados</.botao>
                  </p>

                  <form :if={@sessao} phx-submit="deixar_recado" class="recados__form">
                    <.campo
                      name="texto"
                      area
                      aria-label="deixar um recado"
                      placeholder="deixar um recado"
                      maxlength="500"
                      required
                    />
                    <.botao type="submit">deixar um recado</.botao>
                  </form>
                  <p :if={!@sessao} class="recados__convite">
                    <.link navigate={~p"/"}>entra com atproto</.link> pra deixar um recado
                  </p>
                </div>
              <% "quem-eu-leio" -> %>
                <h2 class="canto-bloco__titulo">cumadis que recomendo</h2>
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

                <div :if={@depoimentos != []} class="depoimentos">
                  <blockquote :for={depoimento <- @depoimentos} class="depoimento">
                    <p>{depoimento.texto}</p>
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
                  <form :if={@depoimento_form} phx-submit="deixar_depoimento">
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
                    <.botao variante={:fantasma} type="submit">enviar depoimento</.botao>
                  </form>
                </div>
              <% "links" -> %>
                <ul class="canto-links">
                  <li :for={link <- @canto.links}>
                    <a href={link.url} target="_blank" rel="noopener">{link.titulo}</a>
                  </li>
                </ul>
            <% end %>
          </section>
        </div>

        <nav :if={@proprio? && !@arrumar} class="rodape">
          <.link navigate={~p"/conta"}>conta</.link>
        </nav>
      </div>
    </Layouts.app>
    """
  end
end
