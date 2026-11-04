{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.quintal;
  container = config.services.beam.containers.quintal;
  inherit
    (lib)
    mkIf
    mkOption
    types
    concatStringsSep
    escapeShellArg
    ;

  userSpec = "${toString container.uid}:${toString container.gid}";
  requiredMounts = container.requiredMounts ++ [container.dataDir];

  environmentFileFlags = concatStringsSep " " (
    map (path: "--env-file ${escapeShellArg (toString path)}") container.environmentFiles
  );

  # One-off run of the same pinned image, for commands that must not race
  # the running service (migrations). No operator wrapper: the release's
  # own binaries are the interface.
  containerRun = command: ''
    ${config.virtualisation.docker.package}/bin/docker run --rm \
      --user ${userSpec} \
      --workdir /data \
      -e HOME=/data \
      -e PHX_HOST=${escapeShellArg cfg.hostname} \
      -e PORT=${toString container.port} \
      -e DATABASE_PATH=/data/quintal.db \
      ${environmentFileFlags} \
      -v ${escapeShellArg (toString container.dataDir)}:/data \
      ${escapeShellArg container.image} ${command}
  '';

  migrate = pkgs.writeShellScript "quintal-migrate" (containerRun "/app/bin/migrate");
in {
  options.services.quintal.hostname = mkOption {
    type = types.str;
    example = "quintal.blog.br";
    description = "Public hostname used to build OAuth callback and endpoint URLs.";
  };

  config = lib.mkMerge [
    {
      services.beam.containers.quintal.environment = {
        PHX_HOST = cfg.hostname;
        PORT = toString container.port;
        DATABASE_PATH = "/data/quintal.db";
      };
    }
    (mkIf container.enable {
      assertions = [
        {
          assertion = container.port != null;
          message = "services.beam.containers.quintal.port must be set.";
        }
        {
          assertion = container.environmentFiles != [];
          message = "services.beam.containers.quintal.environmentFiles must provide SECRET_KEY_BASE and QUINTAL_SESSION_KEY.";
        }
      ];

      systemd.services.quintal-migrate = {
        description = "quintal database migrations";
        unitConfig.RequiresMountsFor = lib.unique requiredMounts;
        wants = ["network-online.target"];
        after = ["network-online.target"];
        wantedBy = ["multi-user.target"];
        before = ["quintal.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = migrate;
        };
      };

      systemd.services.quintal = {
        requires = ["quintal-migrate.service"];
        after = ["quintal-migrate.service"];
      };
    })
  ];
}
