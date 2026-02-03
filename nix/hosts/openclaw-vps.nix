{
  config,
  nix-openclaw,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/common.nix
    (import ../modules/openclaw.nix { inherit nix-openclaw; })
  ];

  networking.hostName = "openclaw";

  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    rekey = {
      hostPubkey = builtins.readFile ../../secrets/host-key.pub;
      masterIdentities = [ ../../identities/tpm-identity.txt ];
      storageMode = "local";
      localStorageDir = ../../.secrets/rekeyed/${config.networking.hostName};
    };

    secrets = {
      anthropic-api = {
        rekeyFile = ../../secrets/anthropic-api.age;
        owner = "openclaw";
        group = "openclaw";
      };
      telegram-creds = {
        rekeyFile = ../../secrets/telegram-creds.age;
        owner = "openclaw";
        group = "openclaw";
      };
      telegram-user-id = {
        rekeyFile = ../../secrets/telegram-user-id.age;
        owner = "openclaw";
        group = "openclaw";
      };
      gateway-token = {
        rekeyFile = ../../secrets/gateway-token.age;
        owner = "openclaw";
        group = "openclaw";
      };
    };
  };

  services.openclaw = {
    enable = true;
    port = 18789;
    logLevel = "info";
    initialStateDir = ../../state/.openclaw;
    telegram = {
      enable = true;
      allowFromFile = config.age.secrets.telegram-user-id.path;
    };
    environmentFiles = [
      config.age.secrets.anthropic-api.path
      config.age.secrets.telegram-creds.path
      config.age.secrets.gateway-token.path
    ];
  };

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../secrets/ssh-key.pub
  ];
}
