defmodule QuintalWeb.OAuthControllerTest do
  use QuintalWeb.ConnCase, async: true

  import Mox

  alias Quintal.Auth.Mock

  setup :verify_on_exit!

  describe "GET /oauth/client-metadata.json" do
    test "serves the public client metadata document", %{conn: conn} do
      conn = get(conn, "/oauth/client-metadata.json")
      body = json_response(conn, 200)

      config = Application.fetch_env!(:quintal, Quintal.Auth.ProtoRune)

      assert body["client_id"] == Keyword.fetch!(config, :client_id)
      assert body["redirect_uris"] == [Keyword.fetch!(config, :redirect_uri)]
      assert body["scope"] == Keyword.fetch!(config, :scope)
      assert body["scope"] =~ "place.quintal"
      refute body["scope"] =~ "bsky"
      assert body["dpop_bound_access_tokens"] == true
      assert body["token_endpoint_auth_method"] == "none"
    end
  end

  describe "GET /oauth/callback" do
    test "exchanges the code and stores only the did in the cookie", %{conn: conn} do
      pending = %{state: "abc"}

      expect(Mock, :open_session, fn ^pending, %{"code" => "123", "state" => "abc"} ->
        {:ok, "did:plc:alice"}
      end)

      conn =
        conn
        |> init_test_session(%{oauth_pending: pending})
        |> get("/oauth/callback", %{"code" => "123", "state" => "abc"})

      assert redirected_to(conn) == "/"
      assert get_session(conn, :quintal_did) == "did:plc:alice"
      refute get_session(conn, :oauth_pending)
    end

    test "rejects when there is no pending flow", %{conn: conn} do
      conn = get(conn, "/oauth/callback", %{"code" => "123", "state" => "abc"})

      assert conn.status == 401
    end

    test "rejects when the exchange fails", %{conn: conn} do
      expect(Mock, :open_session, fn _pending, _params ->
        {:error, :invalid_grant}
      end)

      conn =
        conn
        |> init_test_session(%{oauth_pending: %{state: "abc"}})
        |> get("/oauth/callback", %{"code" => "bad", "state" => "abc"})

      assert conn.status == 401
      refute get_session(conn, :quintal_did)
    end
  end
end

defmodule QuintalWeb.OAuthLoginTest do
  use QuintalWeb.ConnCase, async: true

  import Mox

  alias Quintal.Auth.Mock

  setup :verify_on_exit!

  test "login redireciona para o authorization server e guarda o pending", %{conn: conn} do
    expect(Mock, :authorize_url, fn "alice.bsky.social" ->
      {:ok, "https://bsky.social/oauth/authorize?request_uri=xyz", %{state: "abc"}}
    end)

    conn = get(conn, "/oauth/login", %{"handle" => "alice.bsky.social"})

    assert redirected_to(conn) == "https://bsky.social/oauth/authorize?request_uri=xyz"
    assert get_session(conn, :oauth_pending) == %{state: "abc"}
  end

  test "login com handle ruim volta com flash", %{conn: conn} do
    expect(Mock, :authorize_url, fn _handle -> {:error, :not_found} end)

    conn = get(conn, "/oauth/login", %{"handle" => "ninguem"})

    assert redirected_to(conn) == "/"
    refute get_session(conn, :oauth_pending)
  end

  test "logout revoga e limpa a sessão", %{conn: conn} do
    expect(Mock, :logout, fn "did:plc:alice" -> :ok end)

    conn =
      conn
      |> init_test_session(%{quintal_did: "did:plc:alice"})
      |> get("/oauth/logout")

    assert redirected_to(conn) == "/"
    refute get_session(conn, :quintal_did)
  end
end
