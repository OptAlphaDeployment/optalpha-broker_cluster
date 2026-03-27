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
