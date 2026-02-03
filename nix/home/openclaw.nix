{
  config,
  lib,
  pkgs,
  nix-openclaw,
  osConfig,
  ...
}:

let
  # TODO: remove once https://github.com/openclaw/openclaw/issues/8255 fixed
  # Patch the official nix-openclaw package with our workspace:write hook
  openclawPkg = nix-openclaw.packages.${pkgs.system}.openclaw-gateway.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../patches/openclaw-workspace-write-hook.patch
    ];
  });

  # Path to HM-generated config file
  openclawJson = "${config.home.homeDirectory}/.openclaw/openclaw.json";

  # Runtime injection script for telegram allowFrom (keeps Nix evaluation pure)
  # This reads the secret at service start time, not at Nix eval time
  # All commands use full paths to avoid PATH issues in systemd
  injectTelegramAllowFrom = pkgs.writeShellScript "openclaw-inject-telegram-allowfrom" ''
    set -euo pipefail

    cfg="${openclawJson}"
    idFile="${osConfig.age.secrets.telegram-user-id.path}"

    # If config doesn't exist yet, do nothing (HM activation creates it)
    if [ ! -f "$cfg" ]; then
      echo "[openclaw-inject] Config file not found, skipping injection"
      exit 0
    fi

    if [ ! -r "$idFile" ]; then
      echo "[openclaw-inject] telegram-user-id secret missing/unreadable at $idFile" >&2
      exit 0
    fi

    uid="$(${pkgs.coreutils}/bin/tr -d ' \n\t' < "$idFile")"
    if ! echo "$uid" | ${pkgs.gnugrep}/bin/grep -Eq '^[0-9]+$'; then
      echo "[openclaw-inject] Invalid telegram user id: '$uid'" >&2
      exit 0
    fi

    echo "[openclaw-inject] Injecting telegram user ID $uid into config"
    tmp="$(${pkgs.coreutils}/bin/mktemp)"
    ${pkgs.jq}/bin/jq ".channels.telegram.allowFrom = [($uid|tonumber)]" \
      "$cfg" > "$tmp"
    ${pkgs.coreutils}/bin/chmod 600 "$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" "$cfg"
  '';
in
{
  imports = [
    nix-openclaw.homeManagerModules.openclaw
  ];

  home.username = "openclaw"; # FIXME: used twice in the code
  home.homeDirectory = "/var/lib/openclaw"; # FIXME: used twice in the code
  home.stateVersion = "24.05";

  # FIXME: can be removed (to check)
  # Use sd-switch for headless servers (handles missing D-Bus session)
  systemd.user.startServices = "sd-switch";

  # Add memory files (nix-openclaw only handles top-level .md files)
  home.file.".openclaw/workspace/memory" = {
    source = ../../state/.openclaw/memory;
    recursive = true;
  };

  # TODO: remove after https://github.com/openclaw/openclaw/issues/8255 fixed
  # Hook handler for workspace:write events
  home.file."hooks/on-workspace-write.js".text = ''
    import { appendFile } from "fs/promises";

    const LOG_FILE = "/var/lib/openclaw/workspace-writes.log";

    export default async function onWorkspaceWrite(event) {
      const { operation, tool, paths, workspaceRoot } = event.context;
      const timestamp = new Date().toISOString();
      
      const logLine = JSON.stringify({ timestamp, operation, paths }) + "\n";
      await appendFile(LOG_FILE, logLine).catch(() => {});
      
      console.log(`[workspace:write] ''${operation}: ''${paths.join(", ")}`);
    }
  '';

  programs.openclaw = {
    # TODO: refactor to fetch from git private repo or similar
    # Use instances mode (simple mode has a bug with unitName)
    # Seed workspace with initial documents (IDENTITY.md, SOUL.md, etc.)
    documents = ../../state/.openclaw;

    instances.default = {
      enable = true;

      package = openclawPkg;

      systemd.enable = true;
      systemd.unitName = "openclaw-gateway";
      launchd.enable = false;

      # Typed config -> generates ~/.openclaw/openclaw.json
      config = {
        gateway = {
          port = 18789;
          mode = "local";
        };

        logging = {
          level = "debug";
        };

        commands = {
          native = "auto";
          nativeSkills = "auto";
        };

        channels.telegram = {
          enabled = true;
          dmPolicy = "pairing";
          groupPolicy = "allowlist";
          streamMode = "partial";
          # FIXME: find a better solution (rageImportEncrypted.sh ?)
          # Empty initially - injected at runtime from secret
          allowFrom = [ ];
        };

        agents.defaults = {
          maxConcurrent = 4;
          subagents.maxConcurrent = 8;
        };

        messages.ackReactionScope = "group-mentions";

        # TODO: remove after https://github.com/openclaw/openclaw/issues/8255 fixed
        # Enable workspace:write hook (requires patched package)
        hooks.internal = {
          enabled = true;
          handlers = [
            {
              event = "workspace:write";
              module = "/var/lib/openclaw/hooks/on-workspace-write.js";
            }
          ];
        };
      };
    };
  };

  # Extend the HM-created systemd user service to add our secrets
  systemd.user.services.openclaw-gateway = {
    Service = {
      EnvironmentFile = [
        osConfig.age.secrets.anthropic-api.path
        osConfig.age.secrets.telegram-creds.path
        osConfig.age.secrets.gateway-token.path
      ];

      Environment = [
        "DEBUG=openclaw:*"
        "LOG_LEVEL=debug"
      ];

      # Inject telegram allowFrom from secret just before start
      # mkAfter ensures we don't clobber any upstream ExecStartPre
      ExecStartPre = lib.mkAfter [ "${injectTelegramAllowFrom}" ];
    };

    # FIXME: check if it's needed
    Install.WantedBy = [ "default.target" ];
  };
}
