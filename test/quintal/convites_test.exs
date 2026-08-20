defmodule Quintal.ConvitesTest do
  use Quintal.DataCase, async: true

  alias Quintal.Convites
  alias Quintal.Identidade
  alias Quintal.Repo

  defp identidade(did) do
    Repo.insert!(%Identidade{
      did: did,
      handle: "#{did}.test",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })
  end

  describe "gerar/1" do
    test "gera código no formato axo-xxxxxxxx" do
      assert {:ok, convite} = Convites.gerar("did:plc:alice")
      assert convite.codigo =~ ~r/^axo-[a-z2-9]{8}$/
      assert convite.criado_por == "did:plc:alice"
      assert is_nil(convite.usado_por)
    end

    test "admin gera sem cota" do
      for _ <- 1..7 do
        assert {:ok, _} = Convites.gerar("admin")
      end
    end

    test "cota esgota depois de 5 códigos criados, usados ou não" do
      did = "did:plc:alice"

      for _ <- 1..5 do
        assert {:ok, _} = Convites.gerar(did)
      end

      assert {:error, :cota_esgotada} = Convites.gerar(did)
    end

    test "revogar libera a vaga na cota" do
      did = "did:plc:alice"

      for _ <- 1..5 do
        assert {:ok, _} = Convites.gerar(did)
      end

      {:ok, convite} = Convites.gerar("admin")
      :ok = Convites.revogar(convite.codigo)

      assert {:error, :cota_esgotada} = Convites.gerar(did)

      [codigo | _] = did |> Convites.disponiveis() |> Enum.map(& &1.codigo)
      :ok = Convites.revogar(codigo)

      assert {:ok, _} = Convites.gerar(did)
    end

    test "fundadora gera sem cota" do
      did = "did:plc:4rt5dyqvarrbolr7qmfcbcsm"

      for i <- 1..6 do
        {:ok, convite} = Convites.gerar(did)
        :ok = Convites.usar(convite.codigo, "did:plc:convidada#{i}")
      end

      assert {:ok, _} = Convites.gerar(did)
    end
  end

  describe "restantes/1" do
    test "começa com a cota cheia" do
      assert Convites.restantes("did:plc:alice") == 5
    end

    test "desconta os criados, usados ou não" do
      {:ok, _} = Convites.gerar("did:plc:alice")
      {:ok, usado} = Convites.gerar("did:plc:alice")
      :ok = Convites.usar(usado.codigo, "did:plc:beto")

      assert Convites.restantes("did:plc:alice") == 3
    end
  end

  describe "usar/2" do
    test "marca o código como usado atomicamente" do
      {:ok, convite} = Convites.gerar("admin")

      assert :ok = Convites.usar(convite.codigo, "did:plc:nova")
      assert {:error, :invalido} = Convites.usar(convite.codigo, "did:plc:outra")

      usado = Repo.get!(Quintal.Convite, convite.codigo)
      assert usado.usado_por == "did:plc:nova"
      assert usado.usado_em
    end

    test "código inexistente é inválido" do
      assert {:error, :invalido} = Convites.usar("axo-zzzz", "did:plc:nova")
    end
  end

  describe "valido?/1" do
    test "válido até ser usado" do
      {:ok, convite} = Convites.gerar("admin")

      assert Convites.valido?(convite.codigo)
      :ok = Convites.usar(convite.codigo, "did:plc:nova")
      refute Convites.valido?(convite.codigo)
    end
  end

  describe "entrou?/1" do
    test "quem tem identidade indexada já mora aqui" do
      identidade("did:plc:alice")
      assert Convites.entrou?("did:plc:alice")
    end

    test "quem usou convite já mora aqui, mesmo antes do bootstrap" do
      {:ok, convite} = Convites.gerar("admin")
      :ok = Convites.usar(convite.codigo, "did:plc:nova")

      assert Convites.entrou?("did:plc:nova")
    end

    test "desconhecido não entrou" do
      refute Convites.entrou?("did:plc:estranho")
    end
  end

  describe "revogar/1" do
    test "revoga código não usado" do
      {:ok, convite} = Convites.gerar("admin")

      assert :ok = Convites.revogar(convite.codigo)
      refute Convites.valido?(convite.codigo)
    end

    test "não revoga código já usado" do
      {:ok, convite} = Convites.gerar("admin")
      :ok = Convites.usar(convite.codigo, "did:plc:nova")

      assert {:error, :invalido} = Convites.revogar(convite.codigo)
    end
  end
end
