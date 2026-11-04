{
  pkgs,
  module,
}: let
  evaluated = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = null;
    modules = [
      module
      {
        nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;

        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        boot.loader.grub.device = "nodev";
        system.stateVersion = "26.05";

        services.beam.containers.quintal = {
          enable = true;
          image = "ghcr.io/zoedsoupe/quintal:1.0.0";
          uid = 33333;
          gid = 33334;
          dataDir = "/zdata/quintal";
          requiredMounts = ["/zdata"];
          port = 4013;
          environmentFiles = ["/etc/phoenix/quintal.env"];
        };
        services.quintal.hostname = "quintal.blog.br";
      }
    ];
  };

  config = evaluated.config;
  container = config.virtualisation.oci-containers.containers.quintal;
in
  assert container.user == "33333:33334";
  assert container.environment.PHX_HOST == "quintal.blog.br";
  assert container.environment.PORT == "4013";
  assert container.environment.DATABASE_PATH == "/data/quintal.db";
  assert container.environment.HOME == "/data";
  assert container.environmentFiles == ["/etc/phoenix/quintal.env"];
  assert container.volumes == ["/zdata/quintal:/data"];
  assert container.ports == ["127.0.0.1:4013:4013"];
  assert config.users.users.quintal.uid == 33333;
  assert config.users.groups.quintal.gid == 33334;
  assert config.systemd.services.quintal-migrate.serviceConfig.Type == "oneshot";
  assert config.systemd.services.quintal.requires == ["quintal-migrate.service"];
  assert config.systemd.services.quintal.unitConfig.RequiresMountsFor == ["/zdata/quintal" "/zdata"];
  assert !(config.services.quintal ? image);
  assert !(config.services.quintal ? enable);
    pkgs.runCommand "quintal-module-check" {} "touch $out"
