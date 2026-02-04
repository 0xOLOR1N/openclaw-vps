# OpenClaw package with custom patches
#
# Applies workspace postWrite hooks patch to upstream nix-openclaw package
# TODO: remove once https://github.com/openclaw/openclaw/issues/8255 fixed
{
  pkgs,
  nix-openclaw,
}:

nix-openclaw.packages.${pkgs.system}.openclaw-gateway.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ../../../patches/openclaw-workspace-write-hook.patch
  ];
})
