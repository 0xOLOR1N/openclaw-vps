{
  config,
  lib,
  pkgs,
  nix-openclaw,
  osConfig,
  ...
}:
let
  openclawPkg = import ./package.nix { inherit pkgs nix-openclaw; };
  mcporterConfig = import ./mcp.nix { inherit pkgs; };
  hooks = import ./hooks.nix { inherit config pkgs osConfig; };

  # Generate minimal documents directory for openclaw (required by nix-openclaw module)
  # These are placeholder files - actual content is managed on the VPS
  documentsDir = pkgs.symlinkJoin {
    name = "openclaw-documents";
    paths = [
      (pkgs.writeTextDir "AGENTS.md" "# Agents Configuration\nDefault agent configuration.\n")
      (pkgs.writeTextDir "SOUL.md" "# Soul Configuration\nYou are a helpful AI assistant.\n")
      (pkgs.writeTextDir "TOOLS.md" "# Tools Configuration\nDefault tools configuration.\n")
    ];
  };
in
{
  home.packages = [
    pkgs.nodejs # for MCP bridge
  ];

  programs.openclaw = {
    documents = documentsDir;

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
          dmPolicy = "allowlist"; # Users in allowFrom can use directly
          groupPolicy = "allowlist";
          streamMode = "partial";
          # Empty initially - injected at runtime from secret
          allowFrom = [ ];
        };

        agents.defaults = {
          maxConcurrent = 4;
          subagents.maxConcurrent = 8;
        };

        messages.ackReactionScope = "group-mentions";
      };
    };
  };

  # mcporter config - placed in workspace so mcporter finds it automatically
  # mcporter looks for ./config/mcporter.json relative to workspace (~/.openclaw/workspace/)
  home.file.".openclaw/workspace/config/mcporter.json".source = mcporterConfig;

  # Extend the HM-created systemd user service to add our secrets
  systemd.user.services.openclaw-gateway = {
    Service = {
      EnvironmentFile = [
        osConfig.age.secrets.anthropic-api.path
        osConfig.age.secrets.telegram-creds.path
        osConfig.age.secrets.gateway-token.path
        osConfig.age.secrets.gandalf-api.path
      ];

      Environment = [
        "DEBUG=openclaw:*"
        "LOG_LEVEL=debug"
      ];

      # Inject config values from secrets/patches just before start
      # mkAfter ensures we don't clobber any upstream ExecStartPre
      ExecStartPre = lib.mkAfter [
        "${hooks.injectTelegramAllowFrom}"
        "${hooks.injectWorkspaceHooks}"
        "${hooks.installMcpSkill}"
      ];
    };

    # FIXME: check if it's needed
    Install.WantedBy = [ "default.target" ];
  };
}
