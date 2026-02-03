{
  description = "OpenClaw Hetzner VPS Infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      devshell,
      agenix,
      agenix-rekey,
      nix-openclaw,
      home-manager,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devshell.flakeModule
        agenix-rekey.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      flake = {
        # NixOS configurations (used by agenix-rekey)
        nixosConfigurations.openclaw-vps = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit
              agenix
              agenix-rekey
              nix-openclaw
              home-manager
              ;
          };
          modules = [
            agenix.nixosModules.default
            agenix-rekey.nixosModules.default
            home-manager.nixosModules.home-manager
            ./nix/hosts/openclaw-vps.nix
          ];
        };

        # Colmena deployment configuration
        colmena = {
          meta = {
            nixpkgs = import nixpkgs { system = "x86_64-linux"; };
            specialArgs = {
              inherit
                agenix
                agenix-rekey
                nix-openclaw
                home-manager
                ;
            };
          };
        }
        // (import ./nix/colmena.nix);
      };

      perSystem =
        {
          config,
          pkgs,
          system,
          lib,
          ...
        }:
        let
          # Allow unfree packages (terraform)
          pkgsUnfree = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          # Tell agenix-rekey where to find the hosts
          agenix-rekey.nixosConfigurations = self.nixosConfigurations;

          devshells.default = {
            name = "openclaw-infra";

            env = [
              {
                name = "OTEL_TRACES_EXPORTER";
                value = "";
              }
            ];

            commands = [
              {
                name = "deploy";
                help = "Deploy to VPS with Colmena";
                command = ''
                  export DEPLOY_IP=$(terraform -chdir=terraform output -raw ipv4 2>/dev/null || echo "")
                  if [ -z "$DEPLOY_IP" ]; then
                    echo "Error: No server IP. Run tf-apply first."
                    exit 1
                  fi
                  colmena apply --impure $@
                '';
                category = "deploy";
              }
              {
                name = "ssh-vps";
                help = "SSH into the VPS";
                command = ''
                  IP=$(terraform -chdir=terraform output -raw ipv4)
                  ssh root@$IP $@
                '';
                category = "remote";
              }
              {
                name = "logs";
                help = "View openclaw service logs (user service)";
                command = ''
                  IP=$(terraform -chdir=terraform output -raw ipv4)
                  ssh root@$IP "sudo -u openclaw XDG_RUNTIME_DIR=/run/user/1000 journalctl --user -u openclaw-gateway -f"
                '';
                category = "remote";
              }
              {
                name = "status";
                help = "Check openclaw service status (user service)";
                command = ''
                  IP=$(terraform -chdir=terraform output -raw ipv4)
                  ssh -t root@$IP "sudo -u openclaw XDG_RUNTIME_DIR=/run/user/1000 systemctl --user status openclaw-gateway"
                '';
                category = "remote";
              }
              {
                name = "logs-infect";
                help = "Tail nixos-infect log (during provisioning)";
                command = ''
                  IP=$(terraform -chdir=terraform output -raw ipv4)
                  ssh root@$IP "tail -f /tmp/nixos-infect.log"
                '';
                category = "remote";
              }
              {
                name = "hook-logs";
                help = "View workspace:write hook logs";
                command = ''
                  IP=$(terraform -chdir=terraform output -raw ipv4)
                  ssh root@$IP "tail -f /var/lib/openclaw/workspace-writes.log"
                '';
                category = "remote";
              }
              {
                name = "tf-init";
                help = "Initialize Terraform";
                command = "terraform -chdir=terraform init";
                category = "terraform";
              }
              {
                name = "tf-plan";
                help = "Plan Terraform changes";
                command = "terraform -chdir=terraform plan";
                category = "terraform";
              }
              {
                name = "tf-apply";
                help = "Apply Terraform changes";
                command = "terraform -chdir=terraform apply";
                category = "terraform";
              }
              {
                name = "tf-destroy";
                help = "Destroy Terraform infrastructure";
                command = "terraform -chdir=terraform destroy";
                category = "terraform";
              }

            ];

            devshell.startup.load-secrets.text = ''
              # Load SSH key silently
              age -d -i "$PRJ_ROOT/identities/tpm-identity.txt" "$PRJ_ROOT/secrets/ssh-key.age" 2>/dev/null | ssh-add - 2>/dev/null || true

              # Set Terraform Hetzner token
              export TF_VAR_hcloud_token="$(age -d -i "$PRJ_ROOT/identities/tpm-identity.txt" "$PRJ_ROOT/secrets/hetzner-api.age" 2>/dev/null | tr -d '\n')"
            '';

            packages = [
              pkgsUnfree.terraform
              config.agenix-rekey.package
            ]
            ++ (with pkgs; [
              colmena
              age
              age-plugin-tpm
              openssh
              git
              jq
              # TODO: remove following deps once https://github.com/openclaw/openclaw/issues/8255 fixed
              nodejs_22
              nodePackages.pnpm
            ]);
          };
        };
    };
}
