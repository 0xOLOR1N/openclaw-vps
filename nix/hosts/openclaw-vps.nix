{
  config,
  nix-openclaw,
  ...
}:

let
  # Single source of truth for openclaw user - passed to HM via extraSpecialArgs
  openclawUser = {
    name = "openclaw";
    home = "/var/lib/openclaw";
    uid = 1000;
  };
in
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
        owner = openclawUser.name;
        group = openclawUser.name;
      };
      gandalf-api = {
        rekeyFile = ../../secrets/gandalf.age;
        owner = openclawUser.name;
        group = openclawUser.name;
      };
      telegram-creds = {
        rekeyFile = ../../secrets/telegram-creds.age;
        owner = openclawUser.name;
        group = openclawUser.name;
      };
      telegram-user-id = {
        rekeyFile = ../../secrets/telegram-user-id.age;
        owner = openclawUser.name;
        group = openclawUser.name;
      };
      gateway-token = {
        rekeyFile = ../../secrets/gateway-token.age;
        owner = openclawUser.name;
        group = openclawUser.name;
      };
    };
  };

  users.groups.${openclawUser.name} = { };

  users.users.${openclawUser.name} = {
    isNormalUser = true;
    group = openclawUser.name;
    home = openclawUser.home;
    createHome = true;
    uid = openclawUser.uid;
    linger = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit nix-openclaw openclawUser; };
    backupFileExtension = "bak";
    users.${openclawUser.name} = import ../home;
  };

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../secrets/ssh-key.pub
  ];
}
