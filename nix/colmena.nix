{
  openclaw-vps =
    { agenix, agenix-rekey, ... }:
    {
      deployment = {
        targetHost = builtins.getEnv "DEPLOY_IP";
        targetUser = "root";
        tags = [
          "production"
          "openclaw"
        ];
      };

      imports = [
        agenix.nixosModules.default
        agenix-rekey.nixosModules.default
        ./hosts/openclaw-vps.nix
      ];
    };
}
