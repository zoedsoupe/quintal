defmodule Quintal.PDS.ProtoRune do
  @moduledoc """
  `Quintal.PDS` implementation over `ProtoRune.XRPC.Client`.

  Every request is DPoP-signed with the person's OAuth session and goes
  to the `service_url` of their own pds. A 401 demanding a fresh DPoP
  nonce is retried once by the client itself.
  """

  @behaviour Quintal.PDS

  alias ProtoRune.Session
  alias ProtoRune.XRPC.Client
  alias ProtoRune.XRPC.Procedure
  alias ProtoRune.XRPC.Query
  alias Quintal.Lexicon

  @impl true
  def get_record(session, repo, collection, rkey) do
    query =
      "com.atproto.repo.getRecord"
      |> Query.new(base_url: Session.service_url(session), response: :json)
      |> Query.put_param(:repo, repo)
      |> Query.put_param(:collection, collection)
      |> Query.put_param(:rkey, rkey)

    run(session, query, "GET")
  end

  @impl true
  def list_records(session, repo, collection, opts \\ []) do
    query =
      "com.atproto.repo.listRecords"
      |> Query.new(base_url: Session.service_url(session), response: :json)
      |> Query.put_param(:repo, repo)
      |> Query.put_param(:collection, collection)

    query =
      Enum.reduce(opts, query, fn
        {:limit, limit}, q -> Query.put_param(q, :limit, limit)
        {:cursor, cursor}, q -> Query.put_param(q, :cursor, cursor)
        {:reverse, reverse}, q -> Query.put_param(q, :reverse, reverse)
        {_other, _value}, q -> q
      end)

    run(session, query, "GET")
  end

  @impl true
  def create_record(session, collection, record) do
    with :ok <- Lexicon.validate(collection, record) do
      body = %{
        repo: session.did,
        collection: collection,
        record: Map.put_new(record, "$type", collection)
      }

      run(session, procedure(session, "com.atproto.repo.createRecord", body), "POST")
    end
  end

  @impl true
  def put_record(session, collection, rkey, record, opts \\ []) do
    with :ok <- Lexicon.validate(collection, record) do
      body = %{
        repo: session.did,
        collection: collection,
        rkey: rkey,
        record: Map.put_new(record, "$type", collection)
      }

      body =
        case Keyword.fetch(opts, :swap_commit) do
          {:ok, cid} -> Map.put(body, :swap_commit, cid)
          :error -> body
        end

      run(session, procedure(session, "com.atproto.repo.putRecord", body), "POST")
    end
  end

  @impl true
  def delete_record(session, collection, rkey, opts \\ []) do
    body = %{repo: session.did, collection: collection, rkey: rkey}

    body =
      case Keyword.fetch(opts, :swap_record) do
        {:ok, cid} -> Map.put(body, :swap_record, cid)
        :error -> body
      end

    case run(session, procedure(session, "com.atproto.repo.deleteRecord", body), "POST") do
      {:ok, _response} -> :ok
      {:error, _} = error -> error
    end
  end

  @impl true
  def upload_blob(session, data, content_type) when is_binary(data) do
    proc =
      "com.atproto.repo.uploadBlob"
      |> Procedure.new(base_url: Session.service_url(session), response: :json)
      |> Procedure.put_raw_body(data)
      |> Procedure.put_header("content-type", content_type)

    run(session, proc, "POST")
  end

  defp procedure(session, method, body) do
    method
    |> Procedure.new(base_url: Session.service_url(session), response: :json)
    |> Map.put(:body, body)
  end

  # Signs the request with the session's DPoP proof and executes it.
  # The proof binds method + url, so both are needed before the call.
  defp run(session, request, http_method) do
    url = to_string(request)

    with {:ok, headers, session} <- Session.authorization_headers(session, http_method, url) do
      Client.execute(%{request | headers: Map.merge(request.headers, headers)}, session: session)
    end
  end
end
