# Broker Cluster

Kubernetes deployment manifests for the **OptAlpha Broker API** service with Redis caching and time-based autoscaling.

## Architecture

```
optalpha-deployment (namespace)
├── broker-api-deployment   → Broker API server (port 7777)
├── broker-api-service      → NodePort service (30001 → 7777)
├── redis-deployment        → Redis 7.0 cache (port 6379)
└── redis-service           → ClusterIP service (6379)

another (namespace)
└── another-autoscaler      → Cron-based replica scaling
```

## Project Structure

```
Broker_Cluster/
├── Broker/
│   ├── broker-api-deployment.yml   # Broker API deployment
│   └── broker-api-service.yml      # NodePort service (30001)
├── Redis/
│   ├── redis-deployment.yml        # Redis 7.0 deployment
│   └── redis-service.yml           # ClusterIP service
├── another-autoscaler.yml          # Time-based autoscaler (RBAC + deployment)
├── optalpha-deployment.yml         # Namespace definition
├── apply.txt                       # kubectl apply order
├── delete.txt                      # kubectl delete order
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

Set them in [`broker-api-deployment.yml`](Broker/broker-api-deployment.yml):

```yaml
env:
  - name: token
    value: "<your-telegram-bot-token>"
  - name: chat_id
    value: "<your-telegram-chat-id>"
```

## Autoscaler Schedule

The Broker API scales automatically via [another-autoscaler](https://github.com/dignajar/another-autoscaler):

| Event | Cron (UTC)         | Replicas |
| ----- | ------------------ | -------- |
| Start | `15 03 * * *`      | 1        |
| Stop  | `00 10 * * *`      | 0        |

Redis restarts daily at `30 22 * * *` (UTC).

## Deploy

```bash
kubectl apply -f optalpha-deployment.yml
kubectl apply -f another-autoscaler.yml
kubectl apply -f Redis
kubectl apply -f Broker
```

## Teardown

```bash
kubectl delete -f Broker
kubectl delete -f Redis
kubectl delete -f another-autoscaler.yml
kubectl delete -f optalpha-deployment.yml
```

## Resource Limits

| Component  | CPU (req/limit)  | Memory (req/limit) |
| ---------- | ---------------- | ------------------- |
| Broker API | 100m / 150m      | 500Mi / 750Mi       |
| Redis      | 50m / 75m        | 52Mi / 78Mi         |
| Autoscaler | 100m / 300m      | 128Mi / 256Mi       |
