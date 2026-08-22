# Part 13 — High Availability, Scaling, Backup, Disaster Recovery and Production Operations

At this point, Zepto has:

```text
Part 1  → Architecture & GitHub
Part 2  → React Frontend
Part 3  → Node.js Backend APIs
Part 4  → MySQL Database
Part 5  → Docker
Part 6  → GKE
Part 7  → Kubernetes
Part 8  → GitHub Actions CI/CD
Part 9  → End-to-End CI/CD
Part 10 → Prometheus + Grafana
Part 11 → Centralized Logging & Observability
Part 12 → Security Hardening
Part 13 → HA, Scaling, Backup, DR & Operations
```

The goal of Part 13 is to make Zepto resilient to:

```text
Pod failure
Node failure
Traffic spikes
Application crashes
Zone failure
Database failure
Bad deployment
Accidental deletion
Data corruption
```

---

# 13.1 Production Architecture

The target architecture is:

```text
                         INTERNET
                            |
                            v
                      Cloud Armor
                            |
                            v
                   HTTPS Load Balancer
                            |
                            v
                         Ingress
                            |
              +-------------+-------------+
              |                           |
              v                           v
       React Frontend               Node.js Backend
       replicas >= 2                replicas >= 2
              |                           |
              |                           |
              |                    +------+------+
              |                    |             |
              |                    v             v
              |                HPA          Prometheus
              |                    |
              |                    v
              |              More Backend Pods
              |
              |
              +-----------------------------+
                                            |
                                            v
                                      Cloud SQL MySQL
                                            |
                              +-------------+-------------+
                              |                           |
                              v                           v
                         HA / Failover                Backups
```

And at the GKE level:

```text
GKE Cluster
|
+-- Zone A
|    |
|    +-- Frontend Pod
|    +-- Backend Pod
|
+-- Zone B
|    |
|    +-- Frontend Pod
|    +-- Backend Pod
|
+-- Zone C
     |
     +-- Frontend Pod
     +-- Backend Pod
```

This is much more resilient than running all Pods on one node or one zone.

---

# 13.2 What We Will Implement

```text
[✓] Multiple replicas
[✓] Horizontal Pod Autoscaler
[✓] Vertical Pod Autoscaler
[✓] GKE cluster autoscaling
[✓] Pod anti-affinity
[✓] Topology spread constraints
[✓] PodDisruptionBudget
[✓] Multi-zone architecture
[✓] Readiness/liveness probes
[✓] Graceful shutdown
[✓] Cloud SQL
[✓] Automated database backups
[✓] Point-in-time recovery
[✓] Disaster recovery strategy
[✓] RTO/RPO
[✓] Zero-downtime deployment
[✓] Rollback
[✓] Load testing
[✓] Capacity planning
[✓] Production runbooks
```

---

# 13.3 High Availability vs Scalability

These are related but different.

### High Availability

Means:

> Keep the application running when something fails.

Example:

```text
Backend Pod 1 → FAILED

Backend Pod 2 → RUNNING
Backend Pod 3 → RUNNING
```

Users continue using Zepto.

### Scalability

Means:

> Increase capacity when traffic increases.

Example:

```text
Normal traffic

Backend Pods = 2
```

Traffic increases:

```text
Backend Pods = 2
       |
       v
Backend Pods = 5
```

---

# 13.4 Why Two Replicas Are Not Enough

Suppose:

```text
Node 1
 |
 +-- Backend Pod 1
 +-- Backend Pod 2
```

Node 1 fails.

Both Pods disappear.

Better:

```text
Node 1
 |
 +-- Backend Pod 1

Node 2
 |
 +-- Backend Pod 2

Node 3
 |
 +-- Backend Pod 3
```

This is why we need:

```text
Pod anti-affinity
+
Topology spread
```

---

# 13.5 Check Current Cluster

Start with:

```powershell
kubectl get nodes -o wide
```

Then:

```powershell
kubectl get pods -n zepto -o wide
```

Look at:

```text
NODE
```

You want Pods distributed across nodes.

---

# 13.6 Multiple Replicas

Backend:

```yaml
spec:
  replicas: 3
```

Frontend:

```yaml
spec:
  replicas: 3
```

For production, three replicas is a reasonable starting point for a small application, but the correct number depends on traffic and resource requirements.

---

# 13.7 Backend Deployment

Your backend deployment should approximately look like:

```yaml
apiVersion: apps/v1

kind: Deployment

metadata:

  name: zepto-backend

  namespace: zepto


spec:

  replicas: 3

  selector:

    matchLabels:

      app: zepto-backend


  strategy:

    type: RollingUpdate

    rollingUpdate:

      maxUnavailable: 0

      maxSurge: 1


  template:

    metadata:

      labels:

        app: zepto-backend

    spec:

      serviceAccountName: zepto-backend

      containers:

        - name: backend

          image: asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:IMAGE_TAG

          ports:

            - containerPort: 5000

          resources:

            requests:

              cpu: "250m"

              memory: "256Mi"

            limits:

              cpu: "500m"

              memory: "512Mi"

          readinessProbe:

            httpGet:

              path: /health

              port: 5000

            initialDelaySeconds: 10

            periodSeconds: 10

          livenessProbe:

            httpGet:

              path: /health

              port: 5000

            initialDelaySeconds: 30

            periodSeconds: 20
```

---

# 13.8 Why `maxUnavailable: 0`?

During deployment:

```text
Old Pods = 3
New Pods = 0
```

Kubernetes creates:

```text
New Pod 1
```

After it becomes ready:

```text
Old Pods = 3
New Pods = 1
```

Then another new Pod:

```text
Old Pods = 2
New Pods = 2
```

Eventually:

```text
Old Pods = 0
New Pods = 3
```

This reduces downtime during normal rolling updates.

---

# 13.9 Add Pod Anti-Affinity

Add:

```yaml
affinity:

  podAntiAffinity:

    preferredDuringSchedulingIgnoredDuringExecution:

      - weight: 100

        podAffinityTerm:

          topologyKey: kubernetes.io/hostname

          labelSelector:

            matchLabels:

              app: zepto-backend
```

This tells Kubernetes:

> Prefer placing backend Pods on different nodes.

---

# 13.10 Stronger Distribution with Topology Spread

An even better approach is:

```yaml
topologySpreadConstraints:

  - maxSkew: 1

    topologyKey: topology.kubernetes.io/zone

    whenUnsatisfiable: DoNotSchedule

    labelSelector:

      matchLabels:

        app: zepto-backend
```

This encourages Pods to be distributed across zones.

---

# 13.11 Recommended Backend Scheduling

Combine:

```text
PodAntiAffinity
+
TopologySpreadConstraints
```

Architecture:

```text
Zone A              Zone B              Zone C

Backend Pod 1       Backend Pod 2       Backend Pod 3
```

If Zone A fails:

```text
Zone A ❌

Zone B → Backend Pod 2
Zone C → Backend Pod 3
```

The application remains available.

---

# 13.12 PodDisruptionBudget

A PodDisruptionBudget protects availability during voluntary disruptions such as:

```text
Node maintenance
Node drain
Cluster upgrades
```

Create:

```text
kubernetes/backend/pdb.yaml
```

```yaml
apiVersion: policy/v1

kind: PodDisruptionBudget

metadata:

  name: zepto-backend-pdb

  namespace: zepto


spec:

  minAvailable: 2

  selector:

    matchLabels:

      app: zepto-backend
```

Apply:

```powershell
kubectl apply -f kubernetes/backend/pdb.yaml
```

Verify:

```powershell
kubectl get pdb -n zepto
```

---

# 13.13 Frontend PDB

Create:

```text
kubernetes/frontend/pdb.yaml
```

```yaml
apiVersion: policy/v1

kind: PodDisruptionBudget

metadata:

  name: zepto-frontend-pdb

  namespace: zepto


spec:

  minAvailable: 2

  selector:

    matchLabels:

      app: zepto-frontend
```

Apply:

```powershell
kubectl apply -f kubernetes/frontend/pdb.yaml
```

---

# 13.14 Why PDB?

Suppose:

```text
Backend Pods = 3
```

and:

```yaml
minAvailable: 2
```

Kubernetes tries to make sure that voluntary disruption does not reduce healthy backend Pods below two.

---

# 13.15 Horizontal Pod Autoscaler

Now we make backend automatically scale.

Architecture:

```text
                    Traffic
                       |
                       v
                 Backend Pods
                       |
                       v
                   CPU usage
                       |
                       v
                       HPA
                    /     \
                   /       \
               Scale Up   Scale Down
```

---

# 13.16 Check Metrics Server

Run:

```powershell
kubectl top pods -n zepto
```

If you get CPU/memory information, metrics are available.

If not, inspect your GKE configuration before creating HPA.

---

# 13.17 Create Backend HPA

Create:

```text
kubernetes/backend/hpa.yaml
```

```yaml
apiVersion: autoscaling/v2

kind: HorizontalPodAutoscaler

metadata:

  name: zepto-backend

  namespace: zepto


spec:

  scaleTargetRef:

    apiVersion: apps/v1

    kind: Deployment

    name: zepto-backend

  minReplicas: 3

  maxReplicas: 10

  behavior:

    scaleUp:

      stabilizationWindowSeconds: 0

      policies:

        - type: Percent

          value: 100

          periodSeconds: 60

    scaleDown:

      stabilizationWindowSeconds: 300

      policies:

        - type: Percent

          value: 25

          periodSeconds: 60

  metrics:

    - type: Resource

      resource:

        name: cpu

        target:

          type: Utilization

          averageUtilization: 70

    - type: Resource

      resource:

        name: memory

        target:

          type: Utilization

          averageUtilization: 80
```

---

# 13.18 Apply HPA

```powershell
kubectl apply -f kubernetes/backend/hpa.yaml
```

Check:

```powershell
kubectl get hpa -n zepto
```

Expected:

```text
NAME             TARGETS
zepto-backend    35%/70%, 42%/80%
```

---

# 13.19 How HPA Works

Normal:

```text
CPU = 40%

Pods = 3
```

Traffic increases:

```text
CPU = 85%
```

HPA:

```text
3 Pods
   |
   v
5 Pods
```

Traffic continues:

```text
CPU = 80%
```

HPA:

```text
5 Pods
   |
   v
7 Pods
```

Maximum:

```text
10 Pods
```

---

# 13.20 Frontend HPA

Create:

```text
kubernetes/frontend/hpa.yaml
```

```yaml
apiVersion: autoscaling/v2

kind: HorizontalPodAutoscaler

metadata:

  name: zepto-frontend

  namespace: zepto


spec:

  scaleTargetRef:

    apiVersion: apps/v1

    kind: Deployment

    name: zepto-frontend

  minReplicas: 3

  maxReplicas: 10

  metrics:

    - type: Resource

      resource:

        name: cpu

        target:

          type: Utilization

          averageUtilization: 70
```

Apply:

```powershell
kubectl apply -f kubernetes/frontend/hpa.yaml
```

---

# 13.21 Cluster Autoscaling

HPA creates more Pods.

But what if there isn't enough room on existing nodes?

Example:

```text
HPA

3 Pods
 |
 v
10 Pods
```

But:

```text
GKE Nodes
Node 1 → full
Node 2 → full
```

Some Pods remain:

```text
Pending
```

Cluster autoscaling solves this:

```text
Pending Pods
     |
     v
Cluster Autoscaler
     |
     v
New Node
     |
     v
Pods Scheduled
```

GKE provides cluster autoscaling capabilities to adjust node capacity based on workload demand.

---

# 13.22 Check Node Pool

```powershell
gcloud container node-pools list `
  --cluster zepto-gke-cluster `
  --region asia-south1
```

You should identify your node pool.

---

# 13.23 Enable Node Pool Autoscaling

For example:

```powershell
gcloud container clusters update zepto-gke-cluster `
  --region asia-south1 `
  --enable-autoscaling `
  --node-pool default-pool `
  --min-nodes 3 `
  --max-nodes 6
```

Adjust the node pool name to your actual cluster.

---

# 13.24 Important: Regional vs Zonal Cluster

For production HA, prefer a **regional GKE cluster** rather than concentrating production capacity in a single zone.

Your project has been using:

```text
asia-south1
```

A regional cluster can distribute nodes across multiple zones within the region.

Check:

```powershell
gcloud container clusters describe zepto-gke-cluster `
  --region asia-south1 `
  --format="value(location)"
```

---

# 13.25 Multi-Zone Distribution

The goal:

```text
asia-south1-a
      |
      +-- backend
      +-- frontend

asia-south1-b
      |
      +-- backend
      +-- frontend

asia-south1-c
      |
      +-- backend
      +-- frontend
```

This protects against a single-zone failure.

---

# 13.26 Vertical Pod Autoscaler

HPA answers:

> How many Pods do I need?

VPA answers:

> How much CPU and memory should each Pod receive?

Architecture:

```text
HPA
 |
 +-- Number of Pods

VPA
 |
 +-- CPU
 +-- Memory
```

VPA is useful for discovering appropriate resource requests, although it should be introduced carefully when combined with HPA.

---

# 13.27 VPA Recommendation Mode

For production, initially use recommendation mode rather than automatic updates.

Example:

```yaml
apiVersion: autoscaling.k8s.io/v1

kind: VerticalPodAutoscaler

metadata:

  name: zepto-backend-vpa

  namespace: zepto


spec:

  targetRef:

    apiVersion: apps/v1

    kind: Deployment

    name: zepto-backend

  updatePolicy:

    updateMode: "Off"
```

This means:

```text
VPA
 |
 v
Observe workload
 |
 v
Recommend CPU/Memory
```

without automatically restarting Pods.

---

# 13.28 Check VPA

```powershell
kubectl get vpa -n zepto
```

Then:

```powershell
kubectl describe vpa zepto-backend-vpa -n zepto
```

Use recommendations to adjust:

```yaml
resources:
  requests:
```

---

# 13.29 Graceful Shutdown

When Kubernetes terminates a Node.js Pod, the application should stop accepting new work and finish current requests.

Update your Node.js server.

Example:

```javascript
const server = app.listen(
    process.env.PORT || 5000,
    () => {
        console.log("Zepto backend started");
    }
);


function shutdown(signal) {

    console.log(
        `Received ${signal}. Shutting down...`
    );

    server.close(() => {

        console.log(
            "HTTP server closed"
        );

        process.exit(0);

    });

}


process.on(
    "SIGTERM",
    () => shutdown("SIGTERM")
);

process.on(
    "SIGINT",
    () => shutdown("SIGINT")
);
```

---

# 13.30 Add Kubernetes Termination Grace Period

In deployment:

```yaml
spec:

  template:

    spec:

      terminationGracePeriodSeconds: 30
```

This gives the application time to shut down cleanly.

---

# 13.31 Readiness vs Liveness

You already have:

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 5000
```

and:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 5000
```

For production, consider separating:

```text
/health/live
/health/ready
```

---

# 13.32 Liveness Endpoint

Liveness should answer:

> Is the Node.js process alive?

Example:

```javascript
app.get("/health/live", (req, res) => {

    res.json({
        status: "UP"
    });

});
```

It should not depend on MySQL.

---

# 13.33 Readiness Endpoint

Readiness answers:

> Can this Pod receive application traffic?

```javascript
app.get("/health/ready", async (req, res) => {

    try {

        await db.query("SELECT 1");

        res.json({
            status: "READY",
            database: "Connected"
        });

    } catch (error) {

        res.status(503).json({
            status: "NOT_READY",
            database: "Disconnected"
        });

    }

});
```

---

# 13.34 Update Probes

Use:

```yaml
readinessProbe:

  httpGet:

    path: /health/ready

    port: 5000

  initialDelaySeconds: 10

  periodSeconds: 10

  timeoutSeconds: 3

  failureThreshold: 3


livenessProbe:

  httpGet:

    path: /health/live

    port: 5000

  initialDelaySeconds: 30

  periodSeconds: 20

  timeoutSeconds: 3

  failureThreshold: 3
```

This is better than using the database-dependent endpoint for liveness.

---

# 13.35 Why This Matters

Suppose MySQL is temporarily unavailable.

With the old configuration:

```text
/health
 |
 +-- MySQL
      |
      X
```

Liveness fails.

Kubernetes might restart healthy Node.js containers unnecessarily.

With separate endpoints:

```text
/health/live
 |
 +-- Node.js alive → YES

/health/ready
 |
 +-- MySQL available → NO
```

Kubernetes removes the Pod from traffic without unnecessarily restarting it.

---

# 13.36 Database High Availability

This is one of the biggest production changes.

Current architecture:

```text
GKE
 |
 +-- MySQL Pod
      |
      +-- PVC
```

A more production-oriented architecture:

```text
GKE
 |
 +-- Backend
       |
       v
     Cloud SQL
       |
       +-- HA
       +-- Backups
       +-- PITR
```

For a production ecommerce application, use managed MySQL rather than operating the primary database as a single Kubernetes Pod.

---

# 13.37 Cloud SQL HA

Cloud SQL for MySQL supports high availability configurations.

Conceptually:

```text
                Cloud SQL
                    |
          +---------+---------+
          |                   |
          v                   v
      Primary              Standby
          |
          v
       Storage
```

If the primary instance becomes unavailable, Cloud SQL can fail over according to the configured HA architecture.

---

# 13.38 Create Cloud SQL Instance

For a training project, you can create a small instance.

Example:

```powershell
gcloud sql instances create zepto-mysql-prod `
  --database-version=MYSQL_8_0 `
  --cpu=2 `
  --memory=7680MiB `
  --region=asia-south1
```

**Check the currently supported MySQL versions and machine configurations for your region before running this command.**

---

# 13.39 Create Database

```powershell
gcloud sql databases create zepto_db `
  --instance=zepto-mysql-prod
```

---

# 13.40 Create Application User

Do not use:

```text
root
```

for the application.

Create:

```text
zepto_app
```

Example:

```powershell
gcloud sql users create zepto_app `
  --instance=zepto-mysql-prod `
  --password="CHANGE_THIS_PASSWORD"
```

Store the password in Secret Manager.

---

# 13.41 Database Architecture

Production:

```text
Node.js
   |
   | MySQL connection
   v
Cloud SQL
   |
   +-- zepto_db
   |
   +-- zepto_app
```

Not:

```text
Node.js
   |
   v
root
```

---

# 13.42 Database Connection Configuration

Your backend uses:

```text
DB_HOST
DB_PORT
DB_USER
DB_PASSWORD
DB_NAME
```

Production values should become:

```text
DB_HOST=<Cloud SQL endpoint/private address>
DB_PORT=3306
DB_USER=zepto_app
DB_PASSWORD=<Secret Manager value>
DB_NAME=zepto_db
```

Do not commit the actual values.

---

# 13.43 Backup Strategy

A production database needs:

```text
Backup
+
Restore testing
```

not just:

```text
Backup
```

Because a backup that has never been restored is not proven.

---

# 13.44 RPO

RPO:

> Recovery Point Objective.

It answers:

> How much data can we afford to lose?

Example:

```text
RPO = 15 minutes
```

means:

```text
Maximum acceptable data loss ≈ 15 minutes
```

---

# 13.45 RTO

RTO:

> Recovery Time Objective.

It answers:

> How quickly must the application recover?

Example:

```text
RTO = 30 minutes
```

means:

```text
Application should be restored within 30 minutes.
```

---

# 13.46 Example Zepto Targets

For a learning production-style environment:

```text
RPO = 15 minutes

RTO = 30 minutes
```

For a real commercial ecommerce platform, determine these from business requirements rather than copying these numbers.

---

# 13.47 Backup Architecture

```text
                    MySQL
                      |
                      v
                 Cloud SQL
                      |
              +-------+-------+
              |               |
              v               v
         Automated       Point-in-Time
           Backup           Recovery
              |               |
              +-------+-------+
                      |
                      v
                   Restore
```

---

# 13.48 Enable Automated Backups

Configure backups for the Cloud SQL instance.

You can configure:

```text
Backup window
Retention
Point-in-time recovery
Transaction logs
```

Use Google Cloud Console or `gcloud sql instances patch` with the current supported options for your Cloud SQL configuration.

---

# 13.49 Point-in-Time Recovery

PITR allows:

```text
Database
   |
   | 10:00
   | 10:30
   | 11:00
   | 11:30
   v
Choose recovery point
```

For example:

```text
Accidental DELETE
at 11:27
```

You may restore to:

```text
11:26
```

depending on the configured recovery capabilities.

---

# 13.50 Backup Test

Do not just say:

```text
Backup exists
```

Test:

```text
Create backup
     |
     v
Create restore
     |
     v
Connect
     |
     v
Run SELECT
     |
     v
Verify data
```

---

# 13.51 Disaster Recovery

Consider these failure scenarios:

| Failure                   | Recovery                |
| ------------------------- | ----------------------- |
| Pod failure               | Kubernetes restarts Pod |
| Node failure              | Pods rescheduled        |
| Zone failure              | Multi-zone workload     |
| Traffic spike             | HPA                     |
| Node capacity exhausted   | Cluster Autoscaler      |
| Bad deployment            | Rollback                |
| Database corruption       | PITR                    |
| Database instance failure | Cloud SQL HA            |
| Accidental deletion       | Backup/restore          |
| Region failure            | Regional DR plan        |

---

# 13.52 Application Rollback

Check history:

```powershell
kubectl rollout history deployment/zepto-backend -n zepto
```

Rollback:

```powershell
kubectl rollout undo deployment/zepto-backend -n zepto
```

Check:

```powershell
kubectl rollout status deployment/zepto-backend -n zepto
```

---

# 13.53 Zero-Downtime Deployment

Your desired flow:

```text
Old Version
   |
   | 3 Pods
   v
+------+------+------+
| Pod1 | Pod2 | Pod3 |
+------+------+------+

New Version starts

+------+------+------+------+
| Old  | Old  | Old  | New  |
+------+------+------+------+

New Pod becomes Ready

+------+------+------+------+
| Old  | Old  | New  | New  |
+------+------+------+------+

Eventually

+------+------+------+
| New  | New  | New  |
+------+------+------+
```

The Service continues routing to ready Pods.

---

# 13.54 Verify Deployment Strategy

```powershell
kubectl get deployment zepto-backend `
  -n zepto `
  -o yaml
```

Check:

```yaml
strategy:
  type: RollingUpdate
```

---

# 13.55 Load Testing

Before production, test:

```text
100 users
500 users
1000 users
5000 users
```

depending on your target.

Test:

```text
GET /products
GET /categories
POST /cart
POST /orders
GET /health
```

---

# 13.56 Load Testing Tools

Popular choices include:

```text
k6
Apache JMeter
Locust
```

For a DevOps project, k6 is a good option.

Create:

```text
tests/load-test.js
```

Example:

```javascript
import http from "k6/http";

import {
    check,
    sleep
} from "k6";


export const options = {

    vus: 10,

    duration: "30s"

};


export default function () {

    const response =
        http.get(
            "https://YOUR_DOMAIN/api/products"
        );

    check(
        response,
        {
            "status is 200":
                (r) => r.status === 200
        }
    );

    sleep(1);

}
```

Replace the URL with your actual environment.

---

# 13.57 Run Load Test

Install k6 according to its official installation documentation.

Then:

```powershell
k6 run tests/load-test.js
```

Watch:

```text
Grafana
   |
   +-- CPU
   +-- Memory
   +-- Requests/sec
   +-- P95
   +-- 5xx
   +-- HPA
```

---

# 13.58 Test HPA

Before:

```powershell
kubectl get hpa -n zepto
```

Then run load.

Watch:

```powershell
kubectl get hpa -n zepto -w
```

Also:

```powershell
kubectl get pods -n zepto -w
```

You should see:

```text
3 Pods
  |
  v
4 Pods
  |
  v
5 Pods
```

depending on traffic and resource configuration.

---

# 13.59 Test Node Failure

Do this only in a controlled environment.

Identify Pods:

```powershell
kubectl get pods -n zepto -o wide
```

If a node is drained:

```powershell
kubectl drain NODE_NAME `
  --ignore-daemonsets `
  --delete-emptydir-data
```

Observe:

```text
Pods
 |
 v
Rescheduled
```

After testing, uncordon:

```powershell
kubectl uncordon NODE_NAME
```

---

# 13.60 Test Pod Failure

Delete one backend Pod:

```powershell
kubectl delete pod POD_NAME -n zepto
```

Immediately watch:

```powershell
kubectl get pods -n zepto -w
```

Expected:

```text
Old Pod
   |
   X
   |
   v
New Pod
   |
   v
Running
```

This is one of the simplest HA tests.

---

# 13.61 Test Deployment Rollback

Deploy a known test version.

Then:

```powershell
kubectl rollout status deployment/zepto-backend -n zepto
```

If the version is bad:

```powershell
kubectl rollout undo deployment/zepto-backend -n zepto
```

Verify:

```powershell
kubectl get pods -n zepto
```

---

# 13.62 Production Runbook

Create:

```text
docs/runbooks/
```

Structure:

```text
docs/
|
+-- runbooks/
|   |
|   +-- backend-down.md
|   +-- frontend-down.md
|   +-- mysql-down.md
|   +-- high-cpu.md
|   +-- high-memory.md
|   +-- deployment-rollback.md
|   +-- database-recovery.md
|   +-- node-failure.md
|
+-- disaster-recovery.md
```

---

# 13.63 Backend Down Runbook

Create:

```text
docs/runbooks/backend-down.md
```

```markdown
# Zepto Backend Down Runbook

## 1. Check Pods

kubectl get pods -n zepto

## 2. Check Deployment

kubectl get deployment zepto-backend -n zepto

## 3. Check Events

kubectl get events -n zepto --sort-by=.lastTimestamp

## 4. Check Logs

kubectl logs deployment/zepto-backend -n zepto

## 5. Check Previous Logs

kubectl logs POD_NAME -n zepto --previous

## 6. Check HPA

kubectl get hpa -n zepto

## 7. Check Prometheus

Check:

- CPU
- Memory
- Pod restarts
- HTTP 5xx
- Request latency

## 8. Rollback if Required

kubectl rollout undo deployment/zepto-backend -n zepto

## 9. Verify

kubectl rollout status deployment/zepto-backend -n zepto

## 10. Test

curl https://YOUR_DOMAIN/health
```

---

# 13.64 Database Recovery Runbook

Create:

```text
docs/runbooks/database-recovery.md
```

Use:

```markdown
# Zepto Database Recovery

## Identify Incident

Determine:

- Data corruption?
- Accidental DELETE?
- Database unavailable?
- Application connection failure?

## Stop Harmful Operations

If necessary, stop the affected application operation.

## Identify Recovery Point

Determine required RPO.

## Restore Database

Restore from:

- Automated backup
- Point-in-time recovery

## Validate

Run:

SELECT COUNT(*) FROM products;

SELECT COUNT(*) FROM orders;

## Reconnect Backend

Validate:

/health/ready

## Verify Application

Test:

- Login
- Product listing
- Cart
- Checkout
- Orders

## Document Incident

Record:

- Root cause
- Recovery time
- Data loss
- Corrective action
```

---

# 13.65 Capacity Planning

Monitor:

```text
CPU
Memory
Requests/sec
P95 latency
Pod count
Node count
Database CPU
Database connections
Database storage
```

Example:

```text
Current:
100 requests/sec

CPU:
40%

P95:
150ms

Pods:
3
```

At:

```text
500 requests/sec
```

you might discover:

```text
CPU:
85%

P95:
900ms

Pods:
10
```

That tells you the current architecture needs optimization or additional capacity.

---

# 13.66 Production SLOs

Define Service Level Objectives.

Example:

```text
Availability:
99.9%

API P95 latency:
< 500ms

HTTP 5xx:
< 1%

Database availability:
99.9%
```

These are example targets, not universal requirements.

---

# 13.67 Error Budget

If availability SLO is:

```text
99.9%
```

then the allowed downtime is approximately:

```text
43.8 minutes/month
```

The concept is:

```text
SLO
 |
 v
Error Budget
 |
 +-- Deployments
 +-- Experiments
 +-- Maintenance
```

When the error budget is exhausted, prioritize reliability over risky feature releases.

---

# 13.68 Production Dashboard

Your Grafana dashboard should now include:

```text
+------------------------------------------------------+
|             ZEPTO PRODUCTION OVERVIEW                |
+------------------------------------------------------+

+-------------------+-------------------+--------------+
| Availability      | Requests/sec      | P95 Latency  |
+-------------------+-------------------+--------------+

+-------------------+-------------------+--------------+
| HTTP 5xx          | Backend Pods      | Frontend Pods|
+-------------------+-------------------+--------------+

+-------------------+-------------------+--------------+
| CPU               | Memory            | Restarts     |
+-------------------+-------------------+--------------+

+-------------------+-------------------+--------------+
| Node Capacity     | HPA               | DB Health    |
+-------------------+-------------------+--------------+

+------------------------------------------------------+
|                  Alerts / Incidents                  |
+------------------------------------------------------+
```

---

# 13.69 Production Operations

Daily checks:

```text
[ ] Pods healthy
[ ] Nodes healthy
[ ] HPA normal
[ ] No critical alerts
[ ] Database healthy
[ ] Backups successful
[ ] No major security findings
```

Weekly:

```text
[ ] Backup restore test
[ ] Vulnerability review
[ ] Capacity review
[ ] Error budget review
[ ] Cost review
```

Monthly:

```text
[ ] Disaster recovery exercise
[ ] Security review
[ ] IAM review
[ ] RBAC review
[ ] Certificate review
[ ] Architecture review
```

---

# 13.70 Cost Optimization

High availability increases cost.

For example:

```text
3 nodes
+
3 backend Pods
+
3 frontend Pods
+
Prometheus
+
Grafana
+
Cloud SQL HA
```

costs more than:

```text
1 node
+
1 backend Pod
+
1 frontend Pod
```

Production design is therefore a balance:

```text
Reliability
     +
Performance
     +
Security
     +
Cost
```

---

# 13.71 Complete Part 13 Folder Structure

Your repository should now contain:

```text
zepto-quick-commerce/
|
+-- frontend/
|
+-- backend/
|
+-- database/
|
+-- kubernetes/
|   |
|   +-- namespace.yaml
|   +-- resource-quota.yaml
|   +-- limit-range.yaml
|   |
|   +-- network-policies/
|   |
|   +-- backend/
|   |   |
|   |   +-- deployment.yaml
|   |   +-- service.yaml
|   |   +-- serviceaccount.yaml
|   |   +-- hpa.yaml
|   |   +-- pdb.yaml
|   |   +-- vpa.yaml
|   |
|   +-- frontend/
|   |   |
|   |   +-- deployment.yaml
|   |   +-- service.yaml
|   |   +-- hpa.yaml
|   |   +-- pdb.yaml
|   |
|   +-- mysql/
|   |
|   +-- ingress/
|
+-- monitoring/
|   |
|   +-- values.yaml
|   +-- servicemonitors/
|   +-- prometheus-rules/
|   +-- grafana/
|
+-- tests/
|   |
|   +-- load-test.js
|
+-- docs/
|   |
|   +-- runbooks/
|   |   +-- backend-down.md
|   |   +-- frontend-down.md
|   |   +-- mysql-down.md
|   |   +-- high-cpu.md
|   |   +-- high-memory.md
|   |   +-- deployment-rollback.md
|   |   +-- database-recovery.md
|   |   +-- node-failure.md
|   |
|   +-- disaster-recovery.md
|
+-- .github/
|   |
|   +-- workflows/
|       +-- deploy.yml
|
+-- .gitignore
|
+-- README.md
```

---

# 13.72 Production Readiness Architecture

The complete Zepto platform is now:

```text
                              USERS
                                |
                                v
                         +-------------+
                         | Cloud Armor |
                         +------+------+
                                |
                                v
                       HTTPS Load Balancer
                                |
                                v
                             Ingress
                                |
                   +------------+------------+
                   |                         |
                   v                         v
             React Frontend             Node.js API
             HPA: 3-10                  HPA: 3-10
                   |                         |
                   |                         |
                   |                    +----+----+
                   |                    |         |
                   |                    v         v
                   |                Prometheus  Cloud SQL
                   |                             |
                   |                        +----+----+
                   |                        |         |
                   |                        v         v
                   |                       HA      Backup
                   |
                   +-----------------------------+
```

GKE:

```text
                   GKE Regional Cluster
                           |
          +----------------+----------------+
          |                |                |
          v                v                v
       Zone A           Zone B           Zone C
          |                |                |
      Backend          Backend          Backend
      Frontend         Frontend         Frontend
```

Observability:

```text
Application
    |
    +---- Metrics ---> Prometheus ---> Grafana
    |
    +---- Logs ------> Cloud Logging
    |
    +---- Alerts ----> Alertmanager
```

Security:

```text
Cloud Armor
     |
     v
HTTPS
     |
     v
NetworkPolicy
     |
     v
RBAC
     |
     v
Workload Identity
     |
     v
Secret Manager
     |
     v
Non-root Containers
```

---

# 13.73 Part 13 Verification Commands

Run these after implementation:

### Pods

```powershell
kubectl get pods -n zepto -o wide
```

### Deployments

```powershell
kubectl get deployments -n zepto
```

### HPA

```powershell
kubectl get hpa -n zepto
```

### PDB

```powershell
kubectl get pdb -n zepto
```

### VPA

```powershell
kubectl get vpa -n zepto
```

### NetworkPolicy

```powershell
kubectl get networkpolicy -n zepto
```

### ResourceQuota

```powershell
kubectl get resourcequota -n zepto
```

### LimitRange

```powershell
kubectl get limitrange -n zepto
```

### Nodes

```powershell
kubectl get nodes -o wide
```

### Node utilization

```powershell
kubectl top nodes
```

### Pod utilization

```powershell
kubectl top pods -n zepto
```

---

# 13.74 End-to-End HA Test

Perform this sequence in your non-production/staging environment:

```text
1. Deploy Zepto
       |
       v
2. Verify 3 backend Pods
       |
       v
3. Delete one Pod
       |
       v
4. Verify replacement
       |
       v
5. Generate load
       |
       v
6. Verify HPA scales
       |
       v
7. Drain a node
       |
       v
8. Verify Pods reschedule
       |
       v
9. Deploy a new application version
       |
       v
10. Verify zero downtime
       |
       v
11. Introduce test failure
       |
       v
12. Roll back
       |
       v
13. Verify monitoring
       |
       v
14. Verify logs
```

---

# 13.75 Part 13 Success Criteria

Part 13 is complete when:

```text
[✓] Backend runs multiple replicas

[✓] Frontend runs multiple replicas

[✓] Pods distributed across nodes/zones

[✓] Pod anti-affinity configured

[✓] Topology spread configured

[✓] PodDisruptionBudget configured

[✓] Readiness probe configured

[✓] Liveness probe configured

[✓] Separate live/ready health endpoints

[✓] Graceful Node.js shutdown implemented

[✓] RollingUpdate configured

[✓] maxUnavailable configured appropriately

[✓] HPA configured

[✓] Cluster autoscaling configured

[✓] VPA recommendations considered

[✓] Regional/multi-zone architecture considered

[✓] MySQL production architecture defined

[✓] Cloud SQL considered/implemented

[✓] Database backups configured

[✓] PITR configured

[✓] RPO defined

[✓] RTO defined

[✓] Restore procedure documented

[✓] Rollback tested

[✓] Load testing performed

[✓] Production dashboards available

[✓] Production runbooks created

[✓] Capacity planning established
```

---

# 13.76 Final Zepto DevOps Journey

You now have a complete progression:

```text
Part 1
Architecture
       |
Part 2
React
       |
Part 3
Node.js
       |
Part 4
MySQL
       |
Part 5
Docker
       |
Part 6
GKE
       |
Part 7
Kubernetes
       |
Part 8
GitHub Actions
       |
Part 9
CI/CD Testing
       |
Part 10
Prometheus + Grafana
       |
Part 11
Centralized Logging
       |
Part 12
Security Hardening
       |
Part 13
High Availability
Scaling
Backup
Disaster Recovery
Production Operations
```

At this point the project has moved from a basic **3-tier ecommerce application** into a realistic **production-oriented DevOps/GKE platform**.

The next logical step is **Part 14 — Advanced CI/CD and GitOps with Argo CD**: move deployment responsibility from imperative GitHub Actions `kubectl` commands to a GitOps model, introduce separate dev/staging/prod environments, Kustomize or Helm, Argo CD synchronization, deployment history, automatic drift detection, progressive/canary deployments, and a Git-based production approval workflow.
