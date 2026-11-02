{
  description = "quintal: a collective blog platform on ATProto";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    beam-overlay.url = "github:zeeetech/beam-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    beam-overlay,
  }: let
    inherit (nixpkgs.lib) genAttrs;
    inherit (nixpkgs.lib.systems) flakeExposed;

    forAllSystems = f:
      genAttrs flakeExposed (system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [beam-overlay.overlays.default];
        };
      in
        f pkgs);
  in {
    nixosModules = {
      quintal = ./nix/module.nix;
      default = ./nix/module.nix;
    };

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "quintal-dev";

        # Match the Docker builder's Elixir 1.20.5 on OTP 29.
        packages = [
          (pkgs.beam-overlay.mkToolchain {
            elixir.version = "1.20.5";
            erlang-otp.version = "29";
          })
        ];
      };
    });
  };
}
