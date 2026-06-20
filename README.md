# Broker Cluster

Kubernetes deployment manifests for the **OptAlpha Broker API** service with Redis caching, automated via shell scripts for easy server provisioning.

## Architecture

```
optalpha-deployment (namespace)
├── broker-api-deployment   → Broker API server (port 7777)
├── broker-api-service      → NodePort service (30001 → 7777)
├── redis-deployment        → Redis 7.0 cache (port 6379)
└── redis-service           → ClusterIP service (6379)

another (namespace)
└── another-autoscaler      → Cron-based restart scheduling
```

## Project Structure

```
optalpha-broker_cluster/          # Root (this repo)
├── optalpha-broker_cluster/      # Deployment bundle (copied to server)
│   ├── Broker/
│   │   ├── broker-api-deployment.yml   # Broker API deployment
│   │   └── broker-api-service.yml      # NodePort service (30001)
│   ├── Redis/
│   │   ├── redis-deployment.yml        # Redis 7.0 deployment
│   │   └── redis-service.yml           # ClusterIP service
│   ├── another-autoscaler.yml          # Autoscaler (RBAC + deployment)
│   ├── optalpha-deployment.yml         # Namespace definition
│   ├── deploy.sh                       # Provisions server & deploys cluster
│   └── destroy.sh                      # Tears down cluster & uninstalls K3s
├── apply.txt                           # Deploy instructions
├── delete.txt                          # Teardown instructions
├── pscp.exe                            # Windows SCP utility
└── README.md
```

## Environment Variables

The Broker API container uses the following environment variables:

### Not Required

These are not required — **no need to set them manually**:

| Variable         | Description              |
| ---------------- | ------------------------ |
| `host`           | PostgreSQL host address  |
| `port_postgres`  | PostgreSQL port          |
| `username`       | Database username        |
| `password`       | Database password        |

### Required — Telegram Alerts

You **must** set these for Telegram alert notifications:

| Variable  | Description                    |
| --------- | ------------------------------ |
| `token`   | Telegram Bot API token         |
| `chat_id` | Telegram chat/group ID         |

Set them in [`broker-api-deployment.yml`](optalpha-broker_cluster/Broker/broker-api-deployment.yml):

```yaml
env:
  - name: token
    value: "<your-telegram-bot-token>"
  - name: chat_id
    value: "<your-telegram-chat-id>"
```

## Restart Schedule

Both deployments are restarted daily via [another-autoscaler](https://github.com/dignajar/another-autoscaler) annotations:

| Component  | Cron (UTC)         | Action  |
| ---------- | ------------------ | ------- |
| Redis      | `30 22 * * *`      | Restart |
| Broker API | `35 22 * * *`      | Restart |

## Deploy

1. Copy the deployment bundle to your server:

   **Windows** (using included `pscp.exe`):
   ```bash
   pscp -r optalpha-broker_cluster root@<server ip>:/root
   ```

   **Linux / Mac**:
   ```bash
   scp -r optalpha-broker_cluster root@<server ip>:/root
   ```

2. SSH into the server and run the deploy script:
   ```bash
   ssh root@<server ip>
   sudo chmod +x /root/optalpha-broker_cluster/deploy.sh
   /root/optalpha-broker_cluster/deploy.sh
   exit
   ```

   The script will:
   - Update system packages
   - Disable UFW
   - Install K3s (v1.33.9+k3s1)
   - Apply all Kubernetes manifests

## Teardown

1. SSH into the server and run the destroy script:
   ```bash
   ssh root@<server ip>
   sudo chmod +x /root/optalpha-broker_cluster/destroy.sh
   /root/optalpha-broker_cluster/destroy.sh
   exit
   ```

   The script will:
   - Delete all Kubernetes resources
   - Remove the deployment directory
   - Uninstall K3s

## Resource Limits

| Component  | CPU (req/limit)  | Memory (req/limit) |
| ---------- | ---------------- | ------------------- |
| Broker API | 100m / 150m      | 500Mi / 750Mi       |
| Redis      | 50m / 75m        | 52Mi / 78Mi         |
| Autoscaler | 100m / 300m      | 128Mi / 256Mi       |

## For Multi IP Setup on Single Server

For running different family accounts on the same server cloud providers has an option to attach multiple IP address's to single server.

### Multi-Network Card Configuration (Netplan)

To set up a multi-network card configuration, you will need to configure `netplan` (typically located in `/etc/netplan/`, e.g., `50-cloud-init.yaml`).

**Important:** Ask your cloud provider for the exact mapping of network card names (e.g., `eth0`, `ens1`, `ens2`) to their corresponding IP addresses so you can correctly configure the netplan.

**Example `/etc/netplan/50-cloud-init.yaml` snippet:**
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0: # Primary interface
      dhcp4: false
      addresses:
        - 203.0.113.10/24
      routes:
        - to: 203.0.113.0/24
          scope: link
        - to: default
          via: 203.0.113.1
        - to: default
          via: 203.0.113.1
          table: 101
      routing-policy:
        - to: 10.42.0.0/16
          table: 254
          priority: 10
        - to: 10.43.0.0/16
          table: 254
          priority: 10
        - from: 203.0.113.10/32
          table: 101
          priority: 100
    ens4: # Additional interface example
      dhcp4: false
      addresses:
        - 203.0.113.20/24
      routes:
        - to: 203.0.113.0/24
          scope: link
        - to: default
          via: 203.0.113.1
          table: 102
      routing-policy:
        - from: 203.0.113.20/32
          table: 102
```

### Field-by-Field Breakdown of `eth0` Config

To properly understand the multi-network setup, here is an explanation of every field used in the primary interface (`eth0`) configuration:

- `dhcp4: false`: Disables dynamic IP assignment (DHCP) so the interface uses a static IP.
- `addresses: [203.0.113.10/24]`: The static IP address and subnet mask assigned to this specific network card.
- `routes:`: Defines the routing paths for traffic leaving this interface.
  - `- to: 203.0.113.0/24 scope: link`: Defines the local subnet route. `scope: link` indicates that this subnet is directly connected to this network segment (Layer 2).
  - `- to: default via: 203.0.113.1`: **Global Default Gateway**. The primary interface must define the default internet gateway for the entire server. This ensures that any traffic not matching specific policies still has a way out to the internet. Secondary interfaces (like `ens4`) do *not* have this global default gateway because a system can only have one active global default route.
  - `- to: default via: 203.0.113.1 table: 101`: Defines the default gateway specifically for custom routing `table 101`.
- `routing-policy:`: Defines rules for which routing table to use based on specific conditions.
  - `- to: 10.42.0.0/16 table: 254 priority: 10` & `- to: 10.43.0.0/16 table: 254 priority: 10`: **Kubernetes Internal Routing**. K3s uses internal subnets (`10.42.0.0/16` for pods, `10.43.0.0/16` for services). `table: 254` is the Linux `main` routing table. These rules explicitly ensure that traffic destined for internal K3s pods/services uses the main routing table and is handled locally, rather than being incorrectly routed out to the internet.
  - `- from: 203.0.113.10/32 table: 101 priority: 100`: **Symmetric Routing Policy**. This guarantees that if an external request comes in specifically through this interface's IP, the response will be forced to leave through `table 101` (this interface's specific gateway). Every interface needs its own custom table and this source-based routing policy to ensure traffic exits through the correct network card.
- Apply the configuration using `sudo netplan apply`.

### Squid Proxy Installation and Setup

A Squid proxy can be used to route traffic from specific internal ports out through specific external IP addresses (network cards).

1. **Install Squid:**
   ```bash
   sudo apt update
   sudo apt install squid -y
   ```

2. **Configure Squid (`/etc/squid/squid.conf`):**
   - Define your internal K3s network (e.g., `10.42.0.0/16`) via ACL and allow it access.
   - **Crucial:** Deny all other external access to prevent public abuse (`http_access deny all`).
   - Define the internal HTTP ports Squid should listen on using `http_port` (e.g., `8001`, `8002`, etc.).
   - Create ACLs to tag traffic hitting those specific internal ports (e.g., `acl account1 myport 8001`).
   - Use `tcp_outgoing_address` to bind specific public IPs (from your netplan config) to those ACLs.
   - Disable caching since this is just for API routing, not web browsing (`cache deny all`).

**Example `/etc/squid/squid.conf` snippet:**
```conf
# Allow internal K3s network
acl k3s_network src 10.42.0.0/16
http_access allow k3s_network

# Deny everything else (Crucial for security)
http_access deny all

# Listen on specific internal port
http_port 8001

# Identify traffic coming to this specific port
acl account1 myport 8001

# Route traffic for this port out through a specific public IP
tcp_outgoing_address 203.0.113.10 account1

# Disable caching for API calls
cache deny all
```

3. **Restart Squid:**
   ```bash
   sudo systemctl restart squid
   sudo systemctl enable squid
   ```
