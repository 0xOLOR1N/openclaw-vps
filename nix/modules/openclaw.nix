{ nix-openclaw }:
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.openclaw;
  openclawPkg = nix-openclaw.packages.x86_64-linux.openclaw-gateway;

  openclawSrc = pkgs.fetchFromGitHub {
    owner = "openclaw";
    repo = "openclaw";
    rev = "1c4db91593358839a67f6e68576258cf31fa811e";
    sha256 = "sha256-+UHA1Ib79jF7LXKvyGlLeCPVzE81snfjEZRzdawYFwA=";
  };

  configJson = pkgs.writeText "openclaw-config.json" (
    builtins.toJSON {
      commands = {
        native = "auto";
        nativeSkills = "auto";
      };
      channels = {
        telegram = {
          enabled = cfg.telegram.enable;
          dmPolicy = "pairing";
          allowFrom = cfg.telegram.allowFrom;
          groupPolicy = "allowlist";
          streamMode = "partial";
        };
      };
      gateway = {
        port = cfg.port;
        mode = "local";
      };
      agents = {
        defaults = {
          maxConcurrent = 4;
          subagents = {
            maxConcurrent = 8;
          };
        };
      };
      messages = {
        ackReactionScope = "group-mentions";
      };
    }
  );
in
{
  options.services.openclaw = {
    enable = mkEnableOption "OpenClaw AI assistant service";

    user = mkOption {
      type = types.str;
      default = "openclaw";
    };

    group = mkOption {
      type = types.str;
      default = "openclaw";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/openclaw";
    };

    port = mkOption {
      type = types.port;
      default = 18789;
    };

    logLevel = mkOption {
      type = types.enum [
        "debug"
        "info"
        "warn"
        "error"
      ];
      default = "info";
    };

    environmentFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
    };

    initialStateDir = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Directory containing initial .openclaw state files (IDENTITY.md, SOUL.md, USER.md, memory/)";
    };

    telegram = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };

      tokenFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing just the Telegram bot token";
      };

      tokenEnvFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to env file containing TELEGRAM_BOT_TOKEN=...";
      };

      allowFrom = mkOption {
        type = types.listOf types.int;
        default = [ ];
        description = "List of Telegram user IDs allowed to use the bot";
      };

      allowFromFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing newline-separated Telegram user IDs";
      };
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      shell = pkgs.bash; # Enable shell access for exec commands
    };

    users.groups.${cfg.group} = { };

    systemd.services.openclaw = {
      description = "OpenClaw AI Assistant Gateway";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        HOME = cfg.dataDir;
        XDG_CONFIG_HOME = cfg.dataDir;
        OPENCLAW_DATA_DIR = cfg.dataDir;
        LOG_LEVEL = cfg.logLevel;
        # Point to workspace templates to avoid nix package path bug
        OPENCLAW_TEMPLATES_PATH = "${cfg.dataDir}/docs/reference/templates";
      };

      path = [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.nodejs_22
        pkgs.git
      ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        EnvironmentFile = cfg.environmentFiles;

        ExecStartPre = pkgs.writeShellScript "openclaw-setup" ''
          set -euo pipefail

          CONFIG_DIR=${cfg.dataDir}/.openclaw
          mkdir -p $CONFIG_DIR

          ${optionalString (cfg.initialStateDir != null) ''
            WORKSPACE_DIR=$CONFIG_DIR/workspace
            mkdir -p $WORKSPACE_DIR
            for file in IDENTITY.md SOUL.md USER.md MEMORY.md; do
              if [ -f "${cfg.initialStateDir}/$file" ]; then
                cp -f "${cfg.initialStateDir}/$file" "$WORKSPACE_DIR/$file"
              fi
            done
            if [ -d "${cfg.initialStateDir}/memory" ]; then
              cp -rf "${cfg.initialStateDir}/memory" "$WORKSPACE_DIR/"
            fi
          ''}

          cp ${configJson} $CONFIG_DIR/openclaw.json
          chmod 600 $CONFIG_DIR/openclaw.json

          ${optionalString (cfg.telegram.allowFromFile != null) ''
            USER_IDS=$(cat ${cfg.telegram.allowFromFile} | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            ${pkgs.jq}/bin/jq ".channels.telegram.allowFrom = [$USER_IDS]" \
              $CONFIG_DIR/openclaw.json > $CONFIG_DIR/openclaw.json.tmp
            mv $CONFIG_DIR/openclaw.json.tmp $CONFIG_DIR/openclaw.json
          ''}

          LOCAL_OPENCLAW=${cfg.dataDir}/.openclaw/openclaw-local
          if [ ! -d "$LOCAL_OPENCLAW/dist" ]; then
            mkdir -p $LOCAL_OPENCLAW
            cp -r ${openclawPkg}/lib/openclaw/dist $LOCAL_OPENCLAW/
            cp -r ${openclawPkg}/lib/openclaw/node_modules $LOCAL_OPENCLAW/ 2>/dev/null || true
          fi

          if [ ! -d "$LOCAL_OPENCLAW/extensions" ]; then
            cp -r ${openclawPkg}/lib/openclaw/extensions $LOCAL_OPENCLAW/
          fi

          mkdir -p $LOCAL_OPENCLAW/docs/reference/templates
          cp -f ${openclawSrc}/docs/reference/templates/*.md $LOCAL_OPENCLAW/docs/reference/templates/ 2>/dev/null || true
        '';

        # Run from local copy with templates in correct relative path
        ExecStart = "${pkgs.nodejs_22}/bin/node ${cfg.dataDir}/.openclaw/openclaw-local/dist/index.js gateway --port ${toString cfg.port}";

        Restart = "on-failure";
        RestartSec = 5;

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
