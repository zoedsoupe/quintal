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
  requiredMounts = cfg.requiredMounts ++ [ cfg.dataDir ];

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
      -e DATABASE_PATH=/data/quintal.db \
      ${environmentFileFlags} \
      -v ${escapeShellArg (toString cfg.dataDir)}:/data \
      ${escapeShellArg cfg.image} ${command}
  '';

  migrate = pkgs.writeShellScript "quintal-migrate" (containerRun "/app/bin/migrate");

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
        migration command. Keep secrets outside the Nix store. They must provide
        SECRET_KEY_BASE and QUINTAL_SESSION_KEY. SQLite is stored at
        /data/quintal.db. The files use shell-compatible KEY=value lines and are
        trusted operator input.
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
      description = "Local-disk directory mounted at /data for the SQLite database and release state.";
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
        message = "services.quintal.environmentFiles must provide the required runtime secrets.";
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

    systemd.tmpfiles.rules = [ "d '${cfg.dataDir}' 0700 quintal quintal -" ];

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
        DATABASE_PATH = "/data/quintal.db";
        HOME = "/data";
      };
      environmentFiles = cfg.environmentFiles;
      volumes = [ "${cfg.dataDir}:/data" ];
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

  };
}
