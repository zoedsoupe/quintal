# Seed de dev do quintal: uma vizinhança pequena e viva pra navegar as
# telas (feed, canto, prosa/thread, visitas, conta) sem depender do
# firehose.
#
#     mix run priv/repo/seeds.exs
#
# Idempotente: os upserts por uri/dono reescrevem em vez de duplicar, e o
# convite só é gerado se ainda não houver.

defmodule Quintal.Seeds.Dev do
  @moduledoc false

  import Ecto.Query

  alias Quintal.Blogrolls
  alias Quintal.Canto
  alias Quintal.Cantos
  alias Quintal.Convites
  alias Quintal.Depoimento
  alias Quintal.Depoimentos
  alias Quintal.Follows
  alias Quintal.Identidade
  alias Quintal.Prosas
  alias Quintal.Recados
  alias Quintal.Repo
  alias Quintal.Visitas

  @linda "did:plc:devlinda"
  @beto "did:plc:devbeto"
  @clara "did:plc:devclara"
  @dora "did:plc:devdora"

  @prosa "place.quintal.feed.prosa"

  def run do
    identidades()
    cantos()
    prosas()
    follows()
    recados()
    depoimentos()
    blogroll()
    convite()
    :ok
  end

  defp identidades do
    identidade(@linda, "linda.dev")
    identidade(@beto, "beto.dev")
    identidade(@clara, "clara.dev")
    identidade(@dora, "dora.dev")
  end

  defp identidade(did, handle) do
    %Identidade{}
    |> Identidade.changeset(%{
      did: did,
      handle: handle,
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: :did)
  end

  defp cantos do
    canto(@linda, %{
      tema: "papel",
      blocos: ["prosas", "recados", "quem-eu-leio"],
      bio: "escrevo sobre plantas, código e domingos vagarosos.",
      links: [
        %{"titulo" => "meu jardim", "url" => "https://example.com/jardim"},
        %{"titulo" => "código", "url" => "https://example.com/codigo"}
      ],
      updatedAt: "2026-09-01T12:00:00Z"
    })

    nome(@linda, "quintal da linda")

    canto(@beto, %{
      tema: "madrugada",
      blocos: ["prosas", "quem-eu-leio"],
      bio: "leio de madrugada e escrevo devagar.",
      updatedAt: "2026-09-02T12:00:00Z"
    })

    nome(@beto, "os cadernos do beto")

    canto(@clara, %{
      tema: "gloss",
      blocos: ["prosas", "recados", "quem-eu-leio"],
      bio: "música, tinta e conversas de varanda.",
      updatedAt: "2026-09-03T12:00:00Z"
    })

    nome(@clara, "casa da clara")
  end

  defp canto(did, value) do
    {:ok, _} = Cantos.indexar(did, %{value: value})
  end

  defp nome(did, nome) do
    Repo.update_all(from(c in Canto, where: c.dono_did == ^did), set: [nome: nome])
  end

  defp prosas do
    prosa(@linda, "l1", %{
      "text" => "primeiro dia no quintal: virei a chave e já me sinto em casa.",
      "tipo" => "nota",
      "langs" => ["pt-br"],
      "createdAt" => "2026-09-10T09:00:00Z"
    })

    prosa(@linda, "l2", %{
      "text" => "arrumei o canto de manhã, plantei manjericão na janela e escrevi isto.",
      "tipo" => "cronica",
      "langs" => ["pt-br"],
      "createdAt" => "2026-09-12T09:00:00Z"
    })

    prosa(@beto, "b1", %{
      "text" => "bom dia. o café passou e o dia começou devagar, do jeito que eu gosto.",
      "tipo" => "nota",
      "langs" => ["pt-br"],
      "createdAt" => "2026-09-11T10:00:00Z"
    })

    prosa(@beto, "b2", %{
      "text" => "por que a gente ainda trata escrever como produtividade? escrever é presença.",
      "tipo" => "pergunta",
      "langs" => ["pt-br"],
      "createdAt" => "2026-09-13T21:00:00Z"
    })

    # resposta: vira thread na prosa do beto e "resposta" nas visitas dele
    prosa(@clara, "c1", %{
      "text" => "concordo, beto. o café de hoje tava especial.",
      "langs" => ["pt-br"],
      "createdAt" => "2026-09-11T10:05:00Z",
      "reply" => %{
        "root" => %{"uri" => at(@beto, "b1"), "cid" => "bafyb1"},
        "parent" => %{"uri" => at(@beto, "b1"), "cid" => "bafyb1"}
      }
    })

    # menção: vira "mencao" nas visitas da linda e link no texto
    prosa(@clara, "c2", %{
      "text" => "olha o que a @linda.dev escreveu hoje: vale a visita.",
      "langs" => ["pt-br"],
      "createdAt" => "2026-09-12T08:00:00Z",
      "facets" => [
        %{
          "index" => %{"byteStart" => 13, "byteEnd" => 23},
          "features" => [%{"$type" => "app.bsky.richtext.facet#mention", "did" => @linda}]
        }
      ]
    })

    prosa(@clara, "c3", %{
      "text" => "ensaio curto sobre vizinhança: ler o que alguém escreveu é visitar a casa dela.",
      "tipo" => "ensaio",
      "langs" => ["pt-br"],
      "createdAt" => "2026-09-14T20:00:00Z"
    })

    # leitura: "li até aqui" de alguém na prosa da linda
    Visitas.registrar(@linda, "leitura", at(@linda, "l2"), @clara)
  end

  defp prosa(did, rkey, value) do
    {:ok, _} = Prosas.indexar(did, %{uri: at(did, rkey), cid: "bafy#{rkey}", value: value})
  end

  defp follows do
    follow(@linda, @beto, "f1", "2026-09-05T12:00:00Z")
    follow(@linda, @clara, "f2", "2026-09-05T12:05:00Z")
    follow(@dora, @linda, "f3", "2026-09-13T09:00:00Z")
  end

  defp follow(seguidor, seguido, rkey, criado) do
    {:ok, _} =
      Follows.indexar(seguidor, %{
        uri: "at://#{seguidor}/place.quintal.graph.follow/#{rkey}",
        value: %{"subject" => seguido, "createdAt" => criado}
      })
  end

  defp recados do
    recado(@beto, "r1", @linda, "visitei teu canto, que jardim bonito.", "2026-09-14T19:00:00Z")
    recado(@clara, "r2", @linda, "adorei a prosa de ontem. volta sempre.", "2026-09-15T08:30:00Z")
  end

  defp recado(autor, rkey, subject, texto, criado) do
    {:ok, _} =
      Recados.indexar(autor, %{
        uri: "at://#{autor}/place.quintal.canto.recado/#{rkey}",
        value: %{"subject" => subject, "text" => texto, "createdAt" => criado}
      })
  end

  defp depoimentos do
    depoimento(@beto, "d1", "a linda escreve como quem cuida de uma horta.", "2026-09-16T10:00:00Z", false)
    depoimento(@clara, "d2", "vizinha de varanda, sempre uma prosa boa.", "2026-09-16T11:00:00Z", true)
  end

  defp depoimento(autor, rkey, texto, criado, aceito?) do
    uri = "at://#{autor}/place.quintal.canto.depoimento/#{rkey}"

    {:ok, _} =
      Depoimentos.indexar(autor, %{
        uri: uri,
        value: %{"subject" => @linda, "text" => texto, "createdAt" => criado}
      })

    if aceito? do
      Repo.update_all(from(d in Depoimento, where: d.uri == ^uri), set: [aceito: true])
    end
  end

  defp blogroll do
    {:ok, _} =
      Blogrolls.indexar(@linda, %{
        value: %{
          "items" => [
            %{"did" => @beto, "note" => "os cadernos do beto"},
            %{"did" => @clara}
          ],
          "updatedAt" => "2026-09-17T12:00:00Z"
        }
      })
  end

  defp convite do
    if Convites.disponiveis(@linda) == [], do: Convites.gerar(@linda)
  end

  defp at(did, rkey), do: "at://#{did}/#{@prosa}/#{rkey}"
end

Quintal.Seeds.Dev.run()
