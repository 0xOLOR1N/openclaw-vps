# OpenClaw Hetzner VPS Infrastructure

Deploy OpenClaw to a Hetzner VPS using Terraform + NixOS + Colmena + agenix-rekey.

## Prerequisites

- Nix with flakes enabled
- TPM 2.0 (for age-plugin-tpm)
- Hetzner Cloud account
- Telegram Bot (@BotFather)
- Anthropic API key

## Quick Start

```bash
nix develop # or direnv allow
```

### 1. Generate TPM Identity (one-time)

```bash
age-plugin-tpm --generate -o identities/tpm-identity.txt
```

### 2. Generate Host Key (one-time)

```bash
ssh-keygen -t ed25519 -f /tmp/host-key -N "" -C "root@openclaw"
TPM=$(age-plugin-tpm -y identities/tpm-identity.txt)
cat /tmp/host-key | age -r "$TPM" -o secrets/host-key.age
cat /tmp/host-key.pub > secrets/host-key.pub
rm /tmp/host-key /tmp/host-key.pub
```

### 3. Generate SSH Key

```bash
ssh-keygen -t ed25519 -C "openclaw-hetzner" -f /tmp/openclaw-key -N ""
cat /tmp/openclaw-key | age -r "$TPM" -o secrets/ssh-key.age
cp /tmp/openclaw-key.pub secrets/ssh-key.pub
rm /tmp/openclaw-key /tmp/openclaw-key.pub
```

### 4. Create Secrets

```bash
TPM=$(age-plugin-tpm -y identities/tpm-identity.txt)

echo -n "YOUR_HETZNER_TOKEN" | age -r "$TPM" -o secrets/hetzner-api.age
echo -n "ANTHROPIC_API_KEY=sk-ant-..." | age -r "$TPM" -o secrets/anthropic-api.age
echo -n "TELEGRAM_BOT_TOKEN=123456:ABC..." | age -r "$TPM" -o secrets/telegram-creds.age
echo -n "YOUR_TELEGRAM_USER_ID" | age -r "$TPM" -o secrets/telegram-user-id.age
echo -n "OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)" | age -r "$TPM" -o secrets/gateway-token.age
```

### 5. Rekey for Host

```bash
agenix rekey
git add .secrets/
```

### 6. Provision & Deploy

```bash
tf-init
tf-apply
# Wait 3-5 min for nixos-infect
deploy
```

## Day-2 Operations

| Task              | Command                       |
| ----------------- | ----------------------------- |
| Deploy changes    | `deploy`                        |
| View logs         | `logs`                          |
| SSH to server     | `ssh-vps`                       |
| Edit secret       | `agenix edit secrets/foo.age`   |
| Rekey after edit  | `agenix rekey && git add .secrets/` |
| Destroy infra     | `tf-destroy`                    |

## File Structure

```
.
├── flake.nix
├── identities/
│   └── tpm-identity.txt
├── secrets/
│   ├── host-key.age          # Persistent host key (TPM-encrypted)
│   ├── host-key.pub          # Host public key (for rekey)
│   ├── ssh-key.age
│   ├── ssh-key.pub
│   ├── hetzner-api.age
│   ├── anthropic-api.age
│   ├── telegram-creds.age
│   ├── telegram-user-id.age
│   └── gateway-token.age
├── .secrets/
│   └── rekeyed/
│       └── openclaw/         # Auto-generated host-specific secrets
├── state/.openclaw/          # Initial OpenClaw state
├── terraform/
├── nix/
│   ├── colmena.nix
│   ├── hosts/openclaw-vps.nix
│   └── modules/
└── scripts/
```

## Security

| File | Safe to commit? | Why |
|------|-----------------|-----|
| `identities/tpm-identity.txt` | Yes | TPM-bound, only works on your hardware |
| `secrets/*.age` | Yes | Encrypted for TPM only |
| `.secrets/rekeyed/*.age` | Yes | Encrypted for host only |
