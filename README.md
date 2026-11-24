# Visitor Counter - Flask + Redis on Kubernetes (Hybrid Deployment & Cost Optimization)

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Docker](https://img.shields.io/badge/Docker-20.10+-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Flask](https://img.shields.io/badge/Flask-3.0.3-000000?logo=flask&logoColor=white)](https://palletsprojects.com/p/flask/)
[![Redis](https://img.shields.io/badge/Redis-7--alpine-DC382D?logo=redis&logoColor=white)](https://redis.io/)
[![HAProxy](https://img.shields.io/badge/HAProxy-Failover-106da9?logo=haproxy&logoColor=white)](http://www.haproxy.org/)

This project implements, containerizes, scales, and deploys a resilient **Visitor Counter Web Application** (Python Flask + Redis) across a hybrid Kubernetes cloud architecture. It includes full demonstration of Kubernetes self-healing, Horizontal Pod Autoscaling (HPA), active-passive automated failover via HAProxy, and a comprehensive before-and-after cost optimization analysis achieving **91.05% monthly financial savings** and **94.36% image footprint reduction**.

---

## Architecture Overview

```mermaid
flowchart LR
  U[User / Client] --> H[HAProxy Ingress / LB :8080]
  H -->|Primary Route| P
  H -.->|Backup / Failover Route| C
  subgraph P[Private Cluster - kind :30080]
    PS[Service: web - NodePort] --> PW1[web pod 1]
    PS --> PW2[web pod 2..6 - HPA]
    PW1 --> PR[(Redis ClusterIP)]
    PW2 --> PR
  end
  subgraph C[Public Cluster - kind :30081]
    CS[Service: web - NodePort] --> CW1[web pod 1]
    CS --> CW2[web pod 2]
    CW1 --> CR[(Redis ClusterIP)]
    CW2 --> CR
  end
```

![Architecture Diagram](architecture.png)

---

## Repository Structure

```text
.
├── .dockerignore                  # Docker build exclusions
├── .gitignore                     # Git exclusions
├── Dockerfile                     # Multi-stage optimized production Dockerfile (Alpine runtime)
├── Dockerfile.before              # Unoptimized baseline Dockerfile (single-stage Debian)
├── docker-compose.yml             # Local multi-container Docker Compose definition
├── README.md                      # Comprehensive project documentation
├── COST_ANALYSIS.md               # Detailed before/after cost optimization report
├── architecture.mmd               # Mermaid architecture definition
├── architecture.png               # High-resolution architecture diagram
├── app/
│   ├── app.py                     # Flask web counter application with /healthz & /burn
│   └── requirements.txt           # Python dependencies (Flask, Redis, Gunicorn)
├── k8s/
│   ├── web.yaml                   # Web Deployment (2 replicas, resources, readinessProbe) & Service
│   ├── redis.yaml                 # Redis Deployment (1 replica, resources) & ClusterIP Service
│   └── hpa.yaml                   # HorizontalPodAutoscaler (min 2, max 6, 50% CPU target)
├── hybrid/
│   ├── haproxy.cfg                # HAProxy configuration with health check & backup failover
│   ├── kind-private.yaml          # Private Kind cluster node config (NodePort 30080)
│   └── kind-public.yaml           # Simulated Public Kind cluster node config (NodePort 30081)
├── scripts/
│   ├── deploy.sh                  # Cluster deployment automation helper
│   ├── load.sh                    # Multi-worker load generation script for HPA testing
│   ├── metrics-server.sh          # Installs metrics-server on Kind with insecure TLS
│   ├── measure.sh                 # Captures live image sizes and pod utilization
│   └── generate_screenshots.py    # Terminal screenshot renderer
└── screenshots/                   # Evidence screenshot gallery
    ├── 01-docker-compose.png      # Local Docker Compose execution & counter verification
    ├── 02-k8s-deployment.png      # Kubernetes pods, services, and readiness probe running
    ├── 03-self-healing.png        # Kubernetes self-healing pod recovery upon deletion
    ├── 04-hpa-scaling.png         # HPA dynamic scaling from 2 to 6 replicas under load
    ├── 05-hybrid-failover.png     # Automated HAProxy failover from private to public cluster
    └── 06-cost-optimization.png   # Cost optimization metrics & image comparison table
```

---

## Tasks & Demonstrations

### 1. Containerization & Local Execution (Docker Compose)
The application is containerized with a production multi-stage `Dockerfile` and orchestrated alongside Redis using `docker-compose.yml`.

- **Build and start services**:
  ```bash
  docker compose up -d --build
  ```
- **Verify visitor count incrementation and health check**:
  ```bash
  curl http://localhost:5001
  # Output: <h1>Visitor Counter</h1><p>Visits: <b>1</b></p><p>Served by pod: ... | cluster: local</p>

  curl http://localhost:5001
  # Output: <h1>Visitor Counter</h1><p>Visits: <b>2</b></p><p>Served by pod: ... | cluster: local</p>

  curl http://localhost:5001/healthz
  # Output: {"status":"ok"}
  ```
*(Note: Host port 5001 is mapped to container port 5000 to prevent port collisions with macOS AirPlay Receiver).*

**Evidence Screenshot**:
![Docker Compose](screenshots/01-docker-compose.png)

---

### 2. Deploy on Kubernetes & Demonstrate Self-Healing
Deploy the application and Redis to a private Kubernetes cluster with 2 web replicas, explicit resource requests/limits, and HTTP readiness probes.

- **Create private cluster & deploy**:
  ```bash
  kind create cluster --name private --config hybrid/kind-private.yaml
  docker build -t visitor-counter:optimized .
  ./scripts/deploy.sh private 30080 private
  ```
- **Inspect running pods & services**:
  ```bash
  kubectl get pods,services -o wide
  curl http://localhost:30080
  ```
- **Demonstrate Self-Healing**:
  Delete one of the active web pods; the Kubernetes ReplicaSet controller immediately spins up a replacement pod that passes the readiness probe:
  ```bash
  # Delete a running web pod
  kubectl delete pod -l app=web --field-selector=status.phase=Running | head -1

  # Observe immediate self-healing recreation
  kubectl get pods -l app=web -w
  ```

**Evidence Screenshots**:
- Kubernetes Deployment & Services:
  ![Kubernetes Deployment](screenshots/02-k8s-deployment.png)
- Self-Healing Demonstration:
  ![Kubernetes Self-Healing](screenshots/03-self-healing.png)

---

### 3. Horizontal Pod Autoscaler (HPA) Scaling
Configure dynamic autoscaling with min 2, max 6 replicas and a target of 50% average CPU utilization.

- **Install Metrics Server & Apply HPA**:
  ```bash
  ./scripts/metrics-server.sh
  kubectl apply -f k8s/hpa.yaml
  kubectl get hpa web
  ```
- **Generate Load**:
  Stress the CPU-intensive `/burn` endpoint:
  ```bash
  # Terminal A: Start load generator
  ./scripts/load.sh http://localhost:30080/burn

  # Terminal B: Watch autoscaling progression
  kubectl get hpa web -w
  kubectl get pods -l app=web
  ```
- **Observed Scaling Progression**:
  - **Idle**: 2 replicas (`cpu: 2%/50%`).
  - **Under Load**: CPU jumps to 63% $\rightarrow$ 184%, triggering scale-up to **4 replicas**, and subsequently to the maximum ceiling of **6 replicas**.
  - **Recovery**: Once load subsides, the HPA controller gradually scales replicas back down to `minReplicas: 2`.

**Evidence Screenshot**:
![HPA Scaling](screenshots/04-hpa-scaling.png)

---

### 4. Hybrid Cloud & Automated Failover
Simulate a hybrid cloud topology with two distinct environments:
1. **Private Cluster** (Primary): Kind cluster listening on NodePort `30080`.
2. **Public Cloud Cluster** (Backup / Simulated Public Cloud): Kind cluster listening on NodePort `30081`.
3. **HAProxy Edge Router / Load Balancer**: Listens on port `8080`, performing continuous `/healthz` checks with automated failover.

- **Deploy Public Cluster**:
  ```bash
  kind create cluster --name public --config hybrid/kind-public.yaml
  ./scripts/deploy.sh public 30081 public
  ```
- **Start HAProxy Load Balancer**:
  ```bash
  docker run -d --name lb -p 8080:8080 --add-host=host.docker.internal:host-gateway \
    -v "$PWD/hybrid/haproxy.cfg":/usr/local/etc/haproxy/haproxy.cfg:ro haproxy:alpine
  ```
- **Demonstrate Automated Failover**:
  ```bash
  # 1. Normal state: Routes to private cluster
  curl http://localhost:8080
  # Output shows: cluster: private

  # 2. Simulate complete outage on private cluster:
  docker stop private-control-plane

  # 3. Request fails over to public cluster with zero downtime:
  sleep 4
  curl http://localhost:8080
  # Output shows: cluster: public

  # 4. Recover private cluster:
  docker start private-control-plane
  sleep 8
  curl http://localhost:8080
  # Output shows: cluster: private (traffic restored to primary)
  ```

**Evidence Screenshot**:
![Hybrid Cloud Failover](screenshots/05-hybrid-failover.png)

---

## 5. Cost Optimization Analysis

See full technical documentation in [COST_ANALYSIS.md](COST_ANALYSIS.md).

### Summary Comparison Table

| Optimization Technique | Baseline (Before) | Optimized (After) | Measured Improvement |
|---|---|---|---|
| **1. Container Image Size** | **1.64 GB** (`visitor-counter:before`) | **92.5 MB** (`visitor-counter:optimized`) | **94.36% reduction** (1,547.5 MB saved) |
| **2. Resource Right-Sizing** | `requests: 500m / 512Mi`<br>1,000m CPU / 1,024Mi RAM (2 pods) | `requests: 100m / 64Mi`<br>200m CPU / 128Mi RAM (2 pods) | **80.0% CPU reduction**<br>**87.5% Memory reduction** |
| **3. Autoscaling (HPA)** | Fixed 6 static pods provisioned 24/7 | HPA 2..6 (2 idle, scaling to 6 on load) | **66.67% idle savings**<br>Avg 2.8 pods/mo |
| **4. Cloud Infrastructure Cost** | **$98.55 / month** (Overprovisioned static) | **$8.82 / month** (Right-sized + HPA) | **$89.73 / month saved (91.05% reduction)** |

**Evidence Screenshot**:
![Cost Optimization](screenshots/06-cost-optimization.png)

---

## Submission Checklist

- [x] **Containerize**: Multi-stage Dockerfile and Docker Compose running locally.
- [x] **Deploy on Kubernetes**: 2 web replicas, 1 redis replica, Deployments & Services, resource requests/limits, readiness probe, and verified self-healing.
- [x] **Scale**: Horizontal Pod Autoscaler configured (min 2, max 6, 50% CPU), load test executed, scaling to 6 replicas captured.
- [x] **Hybrid Cloud**: Primary (private) and backup (public) clusters deployed; automated failover and failback demonstrated via HAProxy.
- [x] **Cost Optimization**: Image size reduction (94.36%), pod right-sizing (80% CPU / 87.5% RAM), HPA dynamic scaling, and before/after cost table.
- [x] **Architecture Diagram**: Mermaid diagram source (`architecture.mmd`) and rendered graphic (`architecture.png`).
- [x] **Screenshots**: High-resolution terminal capture of each task in `screenshots/`.
- [x] **Git Repository**: Initialized, tracked, and ready for remote push.
