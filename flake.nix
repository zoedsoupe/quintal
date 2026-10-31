{
  description = "quintal: a collective blog platform on ATProto";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    elixir-overlay.url = "github:zoedsoupe/elixir-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    elixir-overlay,
  }: let
    inherit (nixpkgs.lib) genAttrs;
    inherit (nixpkgs.lib.systems) flakeExposed;

    forAllSystems = f:
      genAttrs flakeExposed (system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [elixir-overlay.overlays.default];
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

        # Match the Docker builder's Elixir 1.20.2 on OTP 28.
        packages = with pkgs; [
          (elixir-with-otp beam28Packages.erlang)."1.20.2"
          beam28Packages.erlang
        ];
      };
    });
  };
}
