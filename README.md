# aws-sish

Self-hosted tunnel server using [sish](https://github.com/antoniomika/sish) on AWS EC2. Allows multiple users to expose local services via auto-assigned subdomains (e.g., `myapp.tunnel.example.com`), similar to ngrok/cloudflared but fully self-hosted.

## Architecture

```
*.tunnel.example.com (Route 53 wildcard)
         │
    ┌────▼────┐
    │   EC2   │  sish server (Docker)
    │  :2222  │  SSH tunnel endpoint
    │  :80    │  HTTP proxy
    │  :443   │  HTTPS proxy
    └────┬────┘
       ╱   ╲
  ┌──────┐ ┌──────┐
  │User A│ │User B│
  └──────┘ └──────┘
  alice.tunnel.example.com
           bob.tunnel.example.com
```

## Prerequisites

- AWS account with Route 53 hosted zone
- EC2 instance (t3.micro is sufficient for light usage)
- A domain name with DNS managed by Route 53
- AWS CLI configured with appropriate permissions
- Docker & Docker Compose on the EC2 instance

## Quick Start

### 1. Set up EC2 instance

Launch an EC2 instance (Amazon Linux 2023 or Ubuntu 22.04) with the following **Security Group** inbound rules:

| Port | Protocol | Source    | Purpose              |
| ---- | -------- | --------- | -------------------- |
| 22   | TCP      | Your IP   | SSH admin access     |
| 80   | TCP      | 0.0.0.0/0 | HTTP tunnel traffic  |
| 443  | TCP      | 0.0.0.0/0 | HTTPS tunnel traffic |
| 2222 | TCP      | 0.0.0.0/0 | SSH tunnel endpoint  |

Then run the setup script on the EC2 instance:

```bash
./scripts/setup-ec2.sh
```

### 2. Configure environment

```bash
cp .env.example .env
vim .env
```

Set the following values:

```
TUNNEL_DOMAIN=tunnel.yourdomain.com
ADMIN_TOKEN=your-strong-secret-here
AWS_REGION=ap-northeast-1
AWS_HOSTED_ZONE_ID=Z0123456789ABCDEFGHIJ
```

### 3. Set up wildcard DNS

```bash
./scripts/setup-dns.sh
```

This creates Route 53 records:

- `tunnel.yourdomain.com` → EC2 public IP
- `*.tunnel.yourdomain.com` → EC2 public IP

### 4. Add users

```bash
# Add from a public key file
./scripts/manage-users.sh add alice ~/.ssh/alice_id_ed25519.pub

# Add from a key string
./scripts/manage-users.sh add-key bob 'ssh-ed25519 AAAA... bob@laptop'

# List all users
./scripts/manage-users.sh list
```

### 5. Start the server

```bash
docker compose up -d
```

## User Guide (for tunnel users)

Users need **only an SSH client** -- no additional software to install.

### Expose a local HTTP service

```bash
# Expose localhost:3000 as https://myapp.tunnel.yourdomain.com
ssh -R myapp:80:localhost:3000 tunnel.yourdomain.com -p 2222
```

### Expose multiple services

```bash
# In separate terminals
ssh -R frontend:80:localhost:3000 tunnel.yourdomain.com -p 2222
ssh -R api:80:localhost:8080 tunnel.yourdomain.com -p 2222
```

### SSH config shortcut

Add to `~/.ssh/config`:

```
Host tunnel
    HostName tunnel.yourdomain.com
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
    RemoteForward myapp:80 localhost:3000
```

Then simply: `ssh tunnel`

## Admin

### View logs

```bash
docker compose logs -f sish
```

### Admin console

sish provides a web admin console at:

- `https://tunnel.yourdomain.com/_sish/console`
- Authenticate with the `ADMIN_TOKEN` from `.env`

### Restart

```bash
docker compose restart sish
```

### Update sish

```bash
docker compose pull && docker compose up -d
```

## User Management

```bash
./scripts/manage-users.sh add <username> <pubkey_file>     # Add user
./scripts/manage-users.sh add-key <username> <key_string>  # Add from string
./scripts/manage-users.sh remove <username>                # Remove user
./scripts/manage-users.sh list                             # List all users
./scripts/manage-users.sh show <username>                  # Show user key
```

Changes take effect immediately -- sish watches the pubkeys directory. No restart needed.

## File Structure

```
aws-sish/
├── docker-compose.yml       # sish service definition
├── .env.example             # Environment template
├── .gitignore
├── scripts/
│   ├── setup-ec2.sh         # EC2 instance setup
│   ├── setup-dns.sh         # Route 53 wildcard DNS
│   └── manage-users.sh      # User SSH key management
└── data/
    ├── keys/                # sish server SSH host keys (auto-generated)
    ├── pubkeys/             # Authorized user public keys
    └── certs/               # TLS certificates (auto-generated)
```
