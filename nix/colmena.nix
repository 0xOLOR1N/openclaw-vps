{
  openclaw-vps =
    {
      agenix,
      agenix-rekey,
      home-manager,
      nix-openclaw,
      ...
    }:
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
        home-manager.nixosModules.home-manager
        ./hosts/openclaw-vps.nix
      ];
    };
}
