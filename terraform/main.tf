provider "hcloud" {
  token = var.hcloud_token
}

data "external" "host_key" {
  program = ["bash", "-c", <<-EOF
    KEY=$(age -d -i "${path.module}/../identities/tpm-identity.txt" "${path.module}/../secrets/host-key.age" 2>/dev/null)
    if [ -z "$KEY" ]; then
      echo '{"error": "Failed to decrypt host key"}' >&2
      exit 1
    fi
    KEY_ESCAPED=$(echo "$KEY" | jq -Rs .)
    echo "{\"private_key\": $KEY_ESCAPED}"
  EOF
  ]
}

data "external" "ssh_key" {
  program = ["bash", "-c", <<-EOF
    KEY=$(age -d -i "${path.module}/../identities/tpm-identity.txt" "${path.module}/../secrets/ssh-key.age" 2>/dev/null)
    if [ -z "$KEY" ]; then
      echo '{"error": "Failed to decrypt ssh key"}' >&2
      exit 1
    fi
    KEY_ESCAPED=$(echo "$KEY" | jq -Rs .)
    echo "{\"private_key\": $KEY_ESCAPED}"
  EOF
  ]
}

resource "hcloud_ssh_key" "deploy" {
  name       = "${var.name}-deploy"
  public_key = file(var.ssh_public_key_path)
}

resource "hcloud_server" "nixos" {
  name        = var.name
  image       = var.image
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.deploy.id]

  user_data = <<-CLOUDINIT
    #cloud-config
    package_update: true
    runcmd:
      - ["bash", "-c", "curl -fsSL https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | PROVIDER=hetznercloud NIX_CHANNEL=nixos-24.05 bash 2>&1 | tee /tmp/nixos-infect.log"]
    CLOUDINIT

  lifecycle {
    ignore_changes = [user_data, image]
  }
}

resource "null_resource" "wait_for_nixos" {
  depends_on = [hcloud_server.nixos]

  triggers = {
    server_id = hcloud_server.nixos.id
  }

  provisioner "local-exec" {
    command     = <<-EOF
      echo "Waiting for nixos-infect to complete and server to reboot into NixOS..."
      IP="${hcloud_server.nixos.ipv4_address}"
      SSH_KEY=$(age -d -i "${path.module}/../identities/tpm-identity.txt" "${path.module}/../secrets/ssh-key.age")
      
      # Write key to temp file for SSH
      KEYFILE=$(mktemp)
      echo "$SSH_KEY" > "$KEYFILE"
      chmod 600 "$KEYFILE"
      
      # Wait for NixOS (retry SSH until /etc/NIXOS exists)
      for i in $(seq 1 60); do
        echo "Attempt $i/60: Checking if NixOS is ready..."
        if ssh -i "$KEYFILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes root@$IP "test -f /etc/NIXOS" 2>/dev/null; then
          echo "NixOS is ready!"
          rm -f "$KEYFILE"
          exit 0
        fi
        sleep 10
      done
      
      rm -f "$KEYFILE"
      echo "Timeout waiting for NixOS"
      exit 1
    EOF
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "provision_host_key" {
  depends_on = [null_resource.wait_for_nixos]

  triggers = {
    server_id = hcloud_server.nixos.id
  }

  provisioner "file" {
    content     = data.external.host_key.result.private_key
    destination = "/etc/ssh/ssh_host_ed25519_key"

    connection {
      type        = "ssh"
      host        = hcloud_server.nixos.ipv4_address
      user        = "root"
      private_key = data.external.ssh_key.result.private_key
    }
  }

  provisioner "file" {
    content     = file(var.host_public_key_path)
    destination = "/etc/ssh/ssh_host_ed25519_key.pub"

    connection {
      type        = "ssh"
      host        = hcloud_server.nixos.ipv4_address
      user        = "root"
      private_key = data.external.ssh_key.result.private_key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /etc/ssh/ssh_host_ed25519_key",
      "chmod 644 /etc/ssh/ssh_host_ed25519_key.pub",
      "systemctl restart sshd",
      "echo 'Host key provisioned successfully'"
    ]

    connection {
      type        = "ssh"
      host        = hcloud_server.nixos.ipv4_address
      user        = "root"
      private_key = data.external.ssh_key.result.private_key
    }
  }
}
