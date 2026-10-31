{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.quintal;
  inherit (lib)
    mkIf
    mkOption
    mkEnableOption
    types
    concatStringsSep
    escapeShellArg
    ;

  imageRef = builtins.head (lib.splitString "@" cfg.image);
  imageName = lib.last (lib.splitString "/" imageRef);
  imageHasTag = lib.hasInfix ":" imageName && !(lib.hasSuffix ":latest" imageName);
  imageHasDigest = (builtins.match ".*@sha256:[0-9a-fA-F]{64}$" cfg.image) != null;
  imagePinned = imageHasDigest || imageHasTag;

  userSpec = "${toString cfg.uid}:${toString cfg.gid}";
  requiredMounts = cfg.requiredMounts ++ [
    cfg.dataDir
    cfg.backupDir
  ];

  storagePreStart = concatStringsSep "\n" (
    map (path: ''
      if ! ${pkgs.util-linux}/bin/mountpoint -q ${escapeShellArg (toString path)}; then
        echo "required mount is not available: ${toString path}" >&2
        exit 1
      fi
    '') cfg.requiredMounts
  );

  environmentFileFlags = concatStringsSep " " (
    map (path: "--env-file ${escapeShellArg (toString path)}") cfg.environmentFiles
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
      -e PORT=${toString cfg.port} \
      ${environmentFileFlags} \
      -v ${escapeShellArg (toString cfg.dataDir)}:/data \
      -v ${escapeShellArg (toString cfg.backupDir)}:/backups \
      ${escapeShellArg cfg.image} ${command}
  '';

  migrate = pkgs.writeShellScript "quintal-migrate" (containerRun "/app/bin/migrate");

  backup = pkgs.writeShellScript "quintal-backup" ''
    set -eu
    ${concatStringsSep "\n" (map (path: ". ${escapeShellArg (toString path)}") cfg.environmentFiles)}
    : "''${DATABASE_URL:?DATABASE_URL must be set for backup}"
    ${pkgs.postgresql}/bin/pg_dump "$DATABASE_URL" > ${escapeShellArg (toString cfg.backupDir)}/quintal-$(date +%Y%m%d%H%M%S).sql
  '';
in
{
  options.services.quintal = {
    enable = mkEnableOption "quintal, a collective blog platform on ATProto";

    image = mkOption {
      type = types.str;
      example = "ghcr.io/zoedsoupe/quintal:0.1.0";
      description = ''
        The shared Quintal OCI image. Select an explicit release tag or sha256
        digest; an unpinned image and the latest tag are refused.
      '';
    };

    hostname = mkOption {
      type = types.str;
      example = "quintal.blog.br";
      description = "Public hostname used to build OAuth callback and endpoint URLs.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port the process binds and the container port published on the host.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Host address the container port is published on, normally behind a TLS proxy.";
    };

    environmentFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/run/secrets/quintal.env" ];
      description = ''
        Host-side environment files passed to the container and read by the
        migration and backup scripts. Keep secrets outside the Nix store. They
        must provide DATABASE_URL for an externally managed PostgreSQL database,
        SECRET_KEY_BASE and QUINTAL_SESSION_KEY. The files use shell-compatible
        KEY=value lines and are trusted operator input.
      '';
    };

    uid = mkOption {
      type = types.int;
      example = 33333;
      description = ''
        Stable host UID shared by the service user and the container. Set this
        to the current data owner when adopting an existing installation.
      '';
    };

    gid = mkOption {
      type = types.int;
      example = 33333;
      description = ''
        Stable host GID shared by the service group and the container. Set this
        to the current data group when adopting an existing installation.
      '';
    };

    requiredMounts = mkOption {
      type = types.listOf types.path;
      default = [ ];
      example = [ "/var/lib/quintal" ];
      description = ''
        Paths that must already be mountpoints before the service or a one-off
        command uses data. No automatic mount or ownership changes are performed.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/quintal";
      description = "Host directory mounted at /data for writable release state.";
    };

    backupDir = mkOption {
      type = types.path;
      default = "${cfg.dataDir}/backups";
      defaultText = lib.literalExpression ''"''${config.services.quintal.dataDir}/backups"'';
      description = "Host directory for PostgreSQL dumps, mounted at /backups.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = imagePinned;
        message = "services.quintal.image must select an explicit tag or sha256 digest, not latest.";
      }
      {
        assertion = cfg.environmentFiles != [ ];
        message = "services.quintal.environmentFiles must provide DATABASE_URL and the required runtime secrets.";
      }
    ];

    users.users.quintal = {
      isSystemUser = true;
      group = "quintal";
      uid = cfg.uid;
      home = cfg.dataDir;
      description = "quintal appview";
    };
    users.groups.quintal.gid = cfg.gid;

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0700 quintal quintal -"
      "d '${cfg.backupDir}' 0700 quintal quintal -"
    ];

    virtualisation.docker.enable = lib.mkDefault true;
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.quintal = {
      image = cfg.image;
      serviceName = "quintal";
      user = userSpec;
      workdir = "/data";
      environment = {
        PHX_HOST = cfg.hostname;
        PORT = toString cfg.port;
        HOME = "/data";
      };
      environmentFiles = cfg.environmentFiles;
      volumes = [
        "${cfg.dataDir}:/data"
        "${cfg.backupDir}:/backups"
      ];
      ports = [ "${cfg.listenAddress}:${toString cfg.port}:${toString cfg.port}" ];
      log-driver = "journald";
      pull = "missing";
    };

    systemd.services.quintal-migrate = {
      description = "quintal database migrations";
      unitConfig.RequiresMountsFor = lib.unique requiredMounts;
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      before = [ "quintal.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = migrate;
      };
    };

    systemd.services.quintal = {
      unitConfig.RequiresMountsFor = lib.unique requiredMounts;
      requires = [ "quintal-migrate.service" ];
      after = [ "quintal-migrate.service" ];
      preStart = storagePreStart;
    };

    systemd.services.quintal-backup = {
      description = "quintal PostgreSQL backup";
      unitConfig.RequiresMountsFor = lib.unique requiredMounts;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = backup;
      };
    };
  };
}
