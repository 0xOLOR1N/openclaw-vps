# Home Manager user configuration
#
# Defines the user identity and base HM settings.
# Application-specific config is in ./openclaw/
{
  openclawUser,
  ...
}:

{
  imports = [ ./openclaw ];

  home.username = openclawUser.name;
  home.homeDirectory = openclawUser.home;
  home.stateVersion = "24.05";

  # Use sd-switch for headless servers (handles missing D-Bus session)
  systemd.user.startServices = "sd-switch";
}
