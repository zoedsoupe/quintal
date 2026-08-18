defmodule Quintal.LexiconsTest do
  use ExUnit.Case, async: true

  @lexicons_dir Application.app_dir(:quintal, "priv/static/lexicons")

  test "every lexicon is valid JSON with an id matching its filename" do
    files = Path.wildcard(Path.join(@lexicons_dir, "*.json"))

    assert files != []

    for file <- files do
      nsid = Path.basename(file, ".json")

      assert {:ok, doc} = file |> File.read!() |> JSON.decode()
      assert doc["lexicon"] == 1
      assert doc["id"] == nsid
      assert is_map(doc["defs"]["main"])
    end
  end
end
