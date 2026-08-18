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
    |> expect(:exchange, fn ^pending, %{"code" => "123"} ->
      {:ok, %{did: "did:plc:alice"}}
    end)

    impl = Quintal.Auth.impl()

    assert {:ok, url, ^pending} = impl.authorize_url("alice.bsky.social")
    assert url =~ "request_uri"
    assert {:ok, %{did: "did:plc:alice"}} = impl.exchange(pending, %{"code" => "123"})
  end
end
