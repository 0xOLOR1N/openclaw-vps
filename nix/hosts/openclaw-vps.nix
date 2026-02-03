{
  config,
  nix-openclaw,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../modules/common.nix
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

  users.groups.openclaw = { };

  users.users.openclaw = {
    isNormalUser = true;
    group = "openclaw";
    home = "/var/lib/openclaw";
    createHome = true;
    uid = 1000;
    linger = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit nix-openclaw; };
    backupFileExtension = "bak";
    users.openclaw = import ../home/openclaw.nix;
  };

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../secrets/ssh-key.pub
  ];
}
