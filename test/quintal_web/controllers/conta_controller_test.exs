defmodule QuintalWeb.ContaControllerTest do
  use QuintalWeb.ConnCase, async: true

  import Mox

  alias Quintal.Auth.Mock, as: AuthMock
  alias Quintal.Repo

  setup :verify_on_exit!

  setup do
    Repo.insert!(%Quintal.Identidade{
      did: "did:plc:alice",
      handle: "alice.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    :ok
  end

  test "baixa o zip dos dados da pessoa" do
    expect(AuthMock, :current_session, fn "did:plc:alice" -> {:ok, %{did: "did:plc:alice"}} end)

    conn =
      build_conn()
      |> init_test_session(%{quintal_did: "did:plc:alice"})
      |> get("/conta/exportar")

    assert response(conn, 200)
    assert conn |> get_resp_header("content-disposition") |> hd() =~ ~r/quintal-\d{8}\.zip/
  end

  test "cookie com sessão oauth morta não exporta" do
    expect(AuthMock, :current_session, fn "did:plc:alice" -> {:error, :not_found} end)

    conn =
      build_conn()
      |> init_test_session(%{quintal_did: "did:plc:alice"})
      |> get("/conta/exportar")

    assert html_response(conn, 401)
  end

  test "sem sessão, a portaria responde 401" do
    conn = get(build_conn(), "/conta/exportar")

    assert html_response(conn, 401) =~ "opa, pode entrar não"
  end
end
