# OpenClaw systemd ExecStartPre hooks
#
# Scripts that run before openclaw-gateway starts:
# - injectTelegramAllowFrom: Injects telegram user ID from agenix secret
# - injectWorkspaceHooks: Adds postWrite hook config (pending upstream support)
# - installMcpSkill: Installs MCP tools skill to workspace
{
  config,
  pkgs,
  osConfig,
}:

let
  # Path to HM-generated config file
  openclawJson = "${config.home.homeDirectory}/.openclaw/openclaw.json";

  # MCP tools skill - teaches OpenClaw how to use mcporter CLI
  # Workaround for mcporter native integration bug (#7158) - uses exec-based calls
  mcpToolsSkill = pkgs.writeTextDir "mcp-tools/SKILL.md" (
    builtins.readFile ../../../skills/mcp-tools.md
  );

  # TODO: remove after https://github.com/openclaw/openclaw/issues/8255 fixed
  # Shell script hook for workspace postWrite events
  postWriteHookScript = pkgs.writeShellScript "openclaw-post-write-hook" ''
    #!/usr/bin/env bash
    FILE_PATH="$1"
    OPERATION="$2"

    LOG_FILE="/var/lib/openclaw/workspace-writes.log"
    TIMESTAMP=$(${pkgs.coreutils}/bin/date -Iseconds)

    echo "$TIMESTAMP $OPERATION $FILE_PATH" >> "$LOG_FILE"
  '';
in
{
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

  # TODO: remove after https://github.com/openclaw/openclaw/issues/8255 fixed
  # Inject workspace.hooks.postWrite config (HM module schema doesn't have this option yet)
  injectWorkspaceHooks = pkgs.writeShellScript "openclaw-inject-workspace-hooks" ''
    set -euo pipefail

    cfg="${openclawJson}"

    if [ ! -f "$cfg" ]; then
      echo "[openclaw-inject-hooks] Config file not found, skipping injection"
      exit 0
    fi

    echo "[openclaw-inject-hooks] Injecting workspace.hooks.postWrite config"
    tmp="$(${pkgs.coreutils}/bin/mktemp)"
    ${pkgs.jq}/bin/jq '.workspace.hooks.postWrite = [
      {
        "command": "${postWriteHookScript}",
        "args": ["${"$"}{filePath}", "${"$"}{operation}", "${"$"}{workspaceRoot}"],
        "timeout": 30000
      }
    ]' "$cfg" > "$tmp"
    ${pkgs.coreutils}/bin/chmod 600 "$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" "$cfg"
  '';

  # Install MCP tools skill to workspace
  installMcpSkill = pkgs.writeShellScript "openclaw-install-mcp-skill" ''
    set -euo pipefail
    SKILLS_DIR="${config.home.homeDirectory}/skills"
    SKILL_SRC="${mcpToolsSkill}/mcp-tools"
    SKILL_DST="$SKILLS_DIR/mcp-tools"

    echo "[openclaw-skills] Installing MCP tools skill..."

    # Create skills directory if needed
    ${pkgs.coreutils}/bin/mkdir -p "$SKILLS_DIR"

    # Remove existing skill (make writable first if exists, since Nix store copies are read-only)
    if [ -d "$SKILL_DST" ]; then
      ${pkgs.coreutils}/bin/chmod -R u+w "$SKILL_DST" 2>/dev/null || true
      ${pkgs.coreutils}/bin/rm -rf "$SKILL_DST"
    fi

    # Copy skill and make writable for future updates
    ${pkgs.coreutils}/bin/cp -r "$SKILL_SRC" "$SKILL_DST"
    ${pkgs.coreutils}/bin/chmod -R u+w "$SKILL_DST"

    echo "[openclaw-skills] MCP tools skill installed to $SKILL_DST"
  '';
}
