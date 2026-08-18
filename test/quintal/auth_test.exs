defmodule Quintal.AuthTest do
  use ExUnit.Case, async: true

  import Mox

  alias Quintal.Auth.Mock

  setup :verify_on_exit!

  test "impl/0 points to the configured module" do
    assert Quintal.Auth.impl() == Mock
  end

  test "the mock satisfies the behaviour contract" do
    pending = %{state: "abc"}

    Mock
    |> expect(:authorize_url, fn "alice.bsky.social" ->
      {:ok, "https://bsky.social/oauth/authorize?request_uri=xyz", pending}
    end)
    |> expect(:open_session, fn ^pending, %{"code" => "123"} ->
      {:ok, "did:plc:alice"}
    end)
    |> expect(:current_session, fn "did:plc:alice" ->
      {:ok, %{did: "did:plc:alice", handle: "alice.bsky.social"}}
    end)
    |> expect(:logout, fn "did:plc:alice" -> :ok end)

    impl = Quintal.Auth.impl()

    assert {:ok, url, ^pending} = impl.authorize_url("alice.bsky.social")
    assert url =~ "request_uri"
    assert {:ok, "did:plc:alice"} = impl.open_session(pending, %{"code" => "123"})
    assert {:ok, %{handle: "alice.bsky.social"}} = impl.current_session("did:plc:alice")
    assert :ok = impl.logout("did:plc:alice")
  end
end
