defmodule QuintalWeb.ContaControllerTest do
  use QuintalWeb.ConnCase, async: true

  alias Quintal.Repo

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
    conn =
      build_conn()
      |> init_test_session(%{quintal_did: "did:plc:alice"})
      |> get("/conta/exportar")

    assert response(conn, 200)
    assert get_resp_header(conn, "content-disposition") |> hd() =~ ~r/quintal-\d{8}\.zip/
  end

  test "sem sessão, a portaria responde 401" do
    conn = get(build_conn(), "/conta/exportar")

    assert html_response(conn, 401) =~ "opa, pode entrar não"
  end
end
