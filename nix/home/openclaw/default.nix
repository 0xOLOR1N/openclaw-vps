# OpenClaw module entry point
#
# Imports the nix-openclaw HM module and application configuration.
{
  nix-openclaw,
  ...
}:

{
  imports = [
    nix-openclaw.homeManagerModules.openclaw
    ./app.nix
  ];
}
