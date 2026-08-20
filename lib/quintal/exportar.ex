defmodule Quintal.Exportar do
  @moduledoc """
  A exportação total (spec 5.1, feature 8): um zip de um clique com
  markdown e json dos records.

  A fonte é o índice local, que espelha o repo da pessoa no pds dela:
  prosas viram um `.md` cada em `prosas/`, e tudo (prosas, recados,
  depoimentos, canto, blogroll, follows) também sai como json em
  `records/`, no formato do lexicon.

  Imagens saem como referência de blob dentro do json das prosas; os
  binários ficam no pds (não há leitura de blob na fronteira
  `Quintal.PDS` ainda). Baixar os blobs entra junto com essa leitura.
  """

  import Ecto.Query

  alias Quintal.Blogroll
  alias Quintal.Canto
  alias Quintal.Depoimento
  alias Quintal.Follow
  alias Quintal.Prosa
  alias Quintal.Recado
  alias Quintal.Repo

  @doc """
  Monta o zip da pessoa em memória.

  Retorna `{:ok, binary}` pronto para `send_download/3`.
  """
  @spec zip(did :: String.t()) :: {:ok, binary()}
  def zip(did) do
    prosas = Repo.all(from p in Prosa, where: p.autor_did == ^did, order_by: [asc: p.created_at], preload: [:imagens])

    entradas =
      Enum.map(prosas, &markdown/1) ++
        [
          {~c"records/prosas.json", json(Enum.map(prosas, &prosa_json/1))},
          {~c"records/recados.json", json(Enum.map(recados(did), &recado_json/1))},
          {~c"records/depoimentos.json", json(Enum.map(depoimentos(did), &depoimento_json/1))},
          {~c"records/canto.json", json(canto_json(Repo.get(Canto, did)))},
          {~c"records/blogroll.json", json(blogroll_json(Repo.get(Blogroll, did)))},
          {~c"records/follows.json", json(Enum.map(follows(did), &follow_json/1))}
        ]

    {:ok, {_nome, binario}} = :zip.create(~c"quintal.zip", entradas, [:memory])
    {:ok, binario}
  end

  defp markdown(%Prosa{} = prosa) do
    data = DateTime.to_date(prosa.created_at)
    rkey = prosa.uri |> String.split("/") |> List.last()
    {~c"prosas/#{data}-#{rkey}.md", prosa.texto}
  end

  defp prosa_json(%Prosa{} = prosa) do
    %{
      "uri" => prosa.uri,
      "cid" => prosa.cid,
      "text" => prosa.texto,
      "type" => prosa.tipo,
      "replyRoot" => prosa.reply_root,
      "replyParent" => prosa.reply_parent,
      "langs" => prosa.langs,
      "createdAt" => iso(prosa.created_at),
      "images" =>
        Enum.map(prosa.imagens, fn img -> %{"image" => img.blob, "alt" => img.alt} end)
    }
  end

  defp recados(did) do
    Repo.all(from r in Recado, where: r.autor_did == ^did, order_by: [asc: r.created_at])
  end

  defp recado_json(%Recado{} = recado) do
    %{
      "uri" => recado.uri,
      "subject" => recado.subject_did,
      "text" => recado.texto,
      "createdAt" => iso(recado.created_at)
    }
  end

  defp depoimentos(did) do
    Repo.all(from d in Depoimento, where: d.autor_did == ^did, order_by: [asc: d.created_at])
  end

  defp depoimento_json(%Depoimento{} = depoimento) do
    %{
      "uri" => depoimento.uri,
      "subject" => depoimento.subject_did,
      "text" => depoimento.texto,
      "createdAt" => iso(depoimento.created_at)
    }
  end

  defp canto_json(nil), do: nil

  defp canto_json(%Canto{} = canto) do
    %{
      "theme" => canto.tema,
      "accent" => canto.cor,
      "blocks" => canto.blocos,
      "bio" => canto.bio,
      "links" => Enum.map(canto.links, fn link -> %{"title" => link.titulo, "url" => link.url} end),
      "updatedAt" => iso(canto.updated_at)
    }
  end

  defp blogroll_json(nil), do: nil

  defp blogroll_json(%Blogroll{} = blogroll) do
    %{
      "items" => Enum.map(blogroll.items, fn item -> %{"did" => item.did, "note" => item.note} end),
      "updatedAt" => iso(blogroll.updated_at)
    }
  end

  defp follows(did) do
    Repo.all(from f in Follow, where: f.seguidor_did == ^did, order_by: [asc: f.created_at])
  end

  defp follow_json(%Follow{} = follow) do
    %{
      "uri" => follow.uri,
      "subject" => follow.seguido_did,
      "createdAt" => iso(follow.created_at)
    }
  end

  defp iso(nil), do: nil
  defp iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp json(termo), do: JSON.encode!(termo)
end
