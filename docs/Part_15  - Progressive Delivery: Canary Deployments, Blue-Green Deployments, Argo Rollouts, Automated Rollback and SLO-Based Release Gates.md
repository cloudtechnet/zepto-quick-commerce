# Part 15 — Progressive Delivery: Canary Deployments, Blue-Green Deployments, Argo Rollouts, Automated Rollback and SLO-Based Release Gates

At the end of Part 14, Zepto uses:

```text
GitHub
   |
   v
GitHub Actions
   |
   v
Artifact Registry
   |
   v
GitOps Repository
   |
   v
Argo CD
   |
   v
GKE
```

Part 15 takes deployment one step further.

Instead of:

```text
Old Version
     |
     v
100% Traffic
```

immediately becoming:

```text
New Version
     |
     v
100% Traffic
```

we introduce **progressive delivery**:

```text
New Version
     |
     v
5% Traffic
     |
     v
25%
     |
     v
50%
     |
     v
100%
```

At every stage we ask:

```text
Is the new version healthy?
```

If yes:

```text
Continue rollout
```

If no:

```text
STOP
 |
 v
ROLLBACK
```

For Zepto, we will use **Argo Rollouts** together with **Argo CD**, Kubernetes, Prometheus and the observability platform from the previous parts.

---

# 15.1 What We Will Build

By the end of Part 15:

```text
[✓] Argo Rollouts installed
[✓] Canary deployment
[✓] Blue-Green deployment
[✓] Traffic splitting
[✓] Canary steps
[✓] Pause/resume
[✓] Prometheus analysis
[✓] Automated rollback
[✓] SLO-based release gates
[✓] Error-rate analysis
[✓] Latency analysis
[✓] Availability analysis
[✓] GitOps integration
[✓] Production approval
[✓] Rollout monitoring
[✓] Rollback testing
```

---

# 15.2 Rolling Update vs Canary vs Blue-Green

There are three different deployment approaches.

## Rolling Update

Current approach:

```text
Old:
Pod 1
Pod 2
Pod 3

       ↓

New:
Pod 1
Pod 2
Pod 3
```

Kubernetes gradually replaces old Pods.

---

# 15.3 Canary

Canary means:

> Send a small percentage of users to the new version first.

Example:

```text
                    Users
                      |
                      v
                  Load Balancer
                      |
             +--------+--------+
             |                 |
             v                 v
          Stable             Canary
          95%                 5%
             |                 |
             v                 v
          v1.3              v1.4
```

Then:

```text
5%
 |
 v
25%
 |
 v
50%
 |
 v
100%
```

---

# 15.4 Blue-Green

Blue-Green maintains two environments:

```text
BLUE
v1.3
100% traffic

GREEN
v1.4
0% traffic
```

After validation:

```text
BLUE
v1.3
0%

GREEN
v1.4
100%
```

Traffic switches from Blue to Green.

---

# 15.5 When to Use Which?

| Strategy                 | Best For                        |
| ------------------------ | ------------------------------- |
| Rolling                  | Normal deployments              |
| Canary                   | Risk-sensitive releases         |
| Blue-Green               | Fast full-environment switching |
| Canary + metrics         | Production critical APIs        |
| Blue-Green + smoke tests | Major releases                  |

For Zepto:

```text
Frontend → Rolling / Canary
Backend  → Canary
Database → Migration strategy
Critical APIs → Canary + automated analysis
```

---

# 15.6 Important Database Warning

Application rollback and database rollback are different.

Suppose:

```text
Backend v1.3
Database schema v1
```

Then you deploy:

```text
Backend v1.4
Database schema v2
```

If you immediately rollback the backend to v1.3, v1.3 may not understand schema v2.

Therefore:

```text
Database migrations must be backward compatible.
```

Use:

```text
Expand
   |
   v
Migrate
   |
   v
Deploy
   |
   v
Contract
```

rather than destructive schema changes during the same release.

---

# 15.7 Architecture

Our progressive delivery architecture becomes:

```text
                        GitHub
                          |
                          v
                   GitHub Actions
                          |
                          v
                  Artifact Registry
                          |
                          v
                     GitOps Repo
                          |
                          v
                       Argo CD
                          |
                          v
                   Argo Rollouts
                          |
                +---------+---------+
                |                   |
                v                   v
             Stable              Canary
              v1.3                v1.4
                |                   |
                +---------+---------+
                          |
                          v
                       Users
                          |
                          v
                     Prometheus
                          |
                          v
                    AnalysisRun
                          |
              +-----------+-----------+
              |                       |
              v                       v
          Successful                Failed
              |                       |
              v                       v
        Continue rollout            Abort
                                      |
                                      v
                                   Rollback
```

---

# 15.8 Argo Rollouts

Argo Rollouts is a Kubernetes controller that provides advanced deployment strategies such as:

```text
Canary
Blue-Green
Traffic management
Analysis
Automated promotion
Automated rollback
```

It complements Argo CD:

```text
Argo CD
   |
   | Git synchronization
   v
Argo Rollouts
   |
   | Progressive deployment
   v
GKE
```

---

# 15.9 Install Argo Rollouts

Install the Argo Rollouts controller into GKE.

Create namespace:

```powershell
kubectl create namespace argo-rollouts
```

Then install Argo Rollouts using the current official installation instructions for your chosen version.

After installation:

```powershell
kubectl get pods -n argo-rollouts
```

You should see the controller running.

Verify CRDs:

```powershell
kubectl get crd | Select-String rollouts
```

You should see resources related to:

```text
rollouts.argoproj.io
analysistemplates.argoproj.io
experiments.argoproj.io
```

---

# 15.10 Argo Rollouts CLI

Install the Argo Rollouts CLI.

Verify:

```powershell
kubectl argo rollouts version
```

You should get the client/controller version information.

---

# 15.11 Why Do We Need Another Controller?

We already have:

```text
Deployment
```

Why use:

```text
Rollout
```

?

Normal Deployment supports:

```text
RollingUpdate
```

Argo Rollouts adds:

```text
Canary
Blue-Green
Traffic weights
Analysis
Automated promotion
Automated rollback
```

---

# 15.12 Replace Deployment with Rollout

Current:

```yaml
kind: Deployment
```

Progressive delivery:

```yaml
kind: Rollout
```

The basic structure remains very similar.

---

# 15.13 Backend Rollout

Create in the GitOps repository:

```text
apps/zepto/base/rollout-backend.yaml
```

Example:

```yaml
apiVersion: argoproj.io/v1alpha1

kind: Rollout

metadata:

  name: zepto-backend

  namespace: zepto

spec:

  replicas: 6

  revisionHistoryLimit: 3

  selector:

    matchLabels:

      app: zepto-backend

  template:

    metadata:

      labels:

        app: zepto-backend

    spec:

      serviceAccountName: zepto-backend

      containers:

        - name: backend

          image: zepto-backend

          ports:

            - containerPort: 5000

          resources:

            requests:

              cpu: 250m

              memory: 256Mi

            limits:

              cpu: 500m

              memory: 512Mi

          readinessProbe:

            httpGet:

              path: /health/ready

              port: 5000

            initialDelaySeconds: 10

            periodSeconds: 10

          livenessProbe:

            httpGet:

              path: /health/live

              port: 5000

            initialDelaySeconds: 30

            periodSeconds: 20

  strategy:

    canary:

      canaryService: zepto-backend-canary

      stableService: zepto-backend

      steps:

        - setWeight: 5

        - pause:

            duration: 2m

        - setWeight: 25

        - pause:

            duration: 5m

        - setWeight: 50

        - pause:

            duration: 10m

        - setWeight: 100
```

---

# 15.14 Stable and Canary Services

Argo Rollouts uses services to identify:

```text
Stable ReplicaSet
Canary ReplicaSet
```

Create:

```text
apps/zepto/base/service-backend.yaml
```

Stable:

```yaml
apiVersion: v1

kind: Service

metadata:

  name: zepto-backend

  namespace: zepto

spec:

  selector:

    app: zepto-backend

  ports:

    - port: 5000

      targetPort: 5000
```

Canary:

```yaml
apiVersion: v1

kind: Service

metadata:

  name: zepto-backend-canary

  namespace: zepto

spec:

  selector:

    app: zepto-backend

  ports:

    - port: 5000

      targetPort: 5000
```

The Rollout controller manages which ReplicaSet the services point toward.

---

# 15.15 Important: Traffic Splitting

The simple example above demonstrates the rollout lifecycle, but **percentage traffic splitting requires a traffic-routing provider**.

For GKE, you should choose a supported traffic-management integration such as:

```text
Gateway API
Istio
NGINX
ALB/Ingress integration
```

For a modern GKE implementation, Gateway API is a strong direction.

Conceptually:

```text
Users
  |
  v
Gateway
  |
  +------ 95% ------> Stable
  |
  +------- 5% ------> Canary
```

Without a traffic-routing integration, `setWeight` may represent pod weighting rather than precise percentage-based HTTP traffic distribution.

---

# 15.16 Canary Progression

Our desired production flow:

```text
v1.3 Stable
     |
     v
Deploy v1.4
     |
     v
5% Canary
     |
     v
Prometheus Analysis
     |
     +---- FAIL ---> Rollback
     |
     v
25%
     |
     v
Prometheus Analysis
     |
     +---- FAIL ---> Rollback
     |
     v
50%
     |
     v
Prometheus Analysis
     |
     +---- FAIL ---> Rollback
     |
     v
100%
```

---

# 15.17 Why 5%?

5% allows us to expose the new version to a small portion of traffic.

For example:

```text
10,000 requests
```

Approximately:

```text
Stable:
9,500

Canary:
500
```

This gives us real production behavior without immediately exposing all users to the new version.

---

# 15.18 Prometheus Analysis

This is where Part 10 becomes important.

We already have:

```text
Prometheus
```

Now Argo Rollouts asks Prometheus:

```text
How is the canary performing?
```

For example:

```text
HTTP error rate?
P95 latency?
Request rate?
```

---

# 15.19 AnalysisTemplate

Create:

```text
apps/zepto/base/analysis-error-rate.yaml
```

```yaml
apiVersion: argoproj.io/v1alpha1

kind: AnalysisTemplate

metadata:

  name: zepto-backend-error-rate

  namespace: zepto

spec:

  metrics:

    - name: error-rate

      interval: 30s

      count: 5

      failureLimit: 2

      successCondition: result[0] < 0.01

      provider:

        prometheus:

          address: http://prometheus-operated.monitoring.svc.cluster.local:9090

          query: |
            sum(
              rate(
                http_requests_total{
                  namespace="zepto",
                  service="zepto-backend",
                  status=~"5.."
                }[2m]
              )
            )
            /
            sum(
              rate(
                http_requests_total{
                  namespace="zepto",
                  service="zepto-backend"
                }[2m]
              )
            )
```

**Important:** The exact Prometheus metric name and labels depend on how your Node.js application is instrumented. If your application currently exposes a different metric, use that metric in the query.

---

# 15.20 What Does This Query Mean?

Conceptually:

```text
5xx requests
      /
all requests
      =
error rate
```

Suppose:

```text
5xx = 2
total = 1000
```

Then:

```text
2 / 1000 = 0.002
```

or:

```text
0.2%
```

Our success condition:

```yaml
result[0] < 0.01
```

means:

```text
Error rate < 1%
```

---

# 15.21 Latency Analysis

Create:

```text
apps/zepto/base/analysis-latency.yaml
```

Example:

```yaml
apiVersion: argoproj.io/v1alpha1

kind: AnalysisTemplate

metadata:

  name: zepto-backend-latency

  namespace: zepto

spec:

  metrics:

    - name: p95-latency

      interval: 30s

      count: 5

      failureLimit: 2

      successCondition: result[0] < 0.5

      provider:

        prometheus:

          address: http://prometheus-operated.monitoring.svc.cluster.local:9090

          query: |
            histogram_quantile(
              0.95,
              sum(
                rate(
                  http_request_duration_seconds_bucket{
                    namespace="zepto",
                    service="zepto-backend"
                  }[5m]
                )
              ) by (le)
            )
```

The condition:

```text
< 0.5
```

means:

```text
P95 < 500ms
```

assuming the histogram uses seconds.

---

# 15.22 Combined Analysis

You can combine multiple metrics.

```yaml
spec:

  metrics:

    - name: error-rate
      ...

    - name: p95-latency
      ...
```

The canary must satisfy both:

```text
Error Rate < 1%
AND
P95 < 500ms
```

---

# 15.23 SLO-Based Release Gate

This is the important production concept.

Suppose our SLO is:

```text
Availability >= 99.9%
```

and:

```text
5xx error rate <= 0.1%
```

Then a new release must satisfy:

```text
Canary:
error rate <= 0.1%
```

before continuing.

Architecture:

```text
Canary
   |
   v
Prometheus
   |
   v
SLO Query
   |
   +---- PASS ----> Continue
   |
   +---- FAIL ----> Abort
```

---

# 15.24 Define Zepto Release SLOs

Example:

```text
Availability:
99.9%

HTTP 5xx:
< 0.1%

P95 API latency:
< 500ms

P99 API latency:
< 1 second
```

These are example targets. Your actual SLOs should be based on business requirements and measured baseline performance.

---

# 15.25 Analysis Based on Availability

Conceptually:

```text
successful requests
-------------------
total requests
```

Example:

```text
999 successful
1000 total
```

means:

```text
99.9%
```

If:

```text
998 successful
1000 total
```

then:

```text
99.8%
```

and the rollout should fail if the threshold is:

```text
99.9%
```

---

# 15.26 Attach Analysis to Rollout

Modify:

```yaml
strategy:

  canary:

    canaryService: zepto-backend-canary

    stableService: zepto-backend

    steps:

      - setWeight: 5

      - pause:

          duration: 2m

      - analysis:

          templates:

            - templateName: zepto-backend-error-rate

            - templateName: zepto-backend-latency

      - setWeight: 25

      - pause:

          duration: 5m

      - analysis:

          templates:

            - templateName: zepto-backend-error-rate

            - templateName: zepto-backend-latency

      - setWeight: 50

      - pause:

          duration: 10m

      - analysis:

          templates:

            - templateName: zepto-backend-error-rate

            - templateName: zepto-backend-latency

      - setWeight: 100
```

---

# 15.27 Automated Rollback

If analysis fails:

```text
Analysis
   |
   v
FAILED
   |
   v
Abort Rollout
   |
   v
Stable ReplicaSet
   |
   v
100% Stable
```

This is one of the most important advantages of progressive delivery.

---

# 15.28 Example Failure

Suppose:

```text
v1.3 = stable
v1.4 = canary
```

At 5%:

```text
Error Rate = 0.2%
```

But SLO says:

```text
< 0.1%
```

Therefore:

```text
0.2% > 0.1%
```

Analysis:

```text
FAILED
```

Rollout:

```text
ABORTED
```

Traffic:

```text
100% → v1.3
```

---

# 15.29 Manual Pause

You can also deliberately pause:

```yaml
- pause: {}
```

This means:

```text
Deploy Canary
     |
     v
PAUSED
```

A human must decide:

```text
Continue
```

or:

```text
Abort
```

This is useful for production releases.

---

# 15.30 Production Release Pattern

A strong production strategy:

```text
5%
 |
 v
Automated analysis
 |
 v
25%
 |
 v
Automated analysis
 |
 v
50%
 |
 v
Automated analysis
 |
 v
Manual approval
 |
 v
100%
```

This combines:

```text
Automation
+
Observability
+
Human approval
```

---

# 15.31 Argo Rollouts Status

Check:

```powershell
kubectl argo rollouts get rollout zepto-backend -n zepto
```

You may see:

```text
Name:            zepto-backend
Status:          Healthy
Strategy:        Canary
Step:            2/7
SetWeight:       25
```

---

# 15.32 Watch Rollout

```powershell
kubectl argo rollouts get rollout zepto-backend `
  -n zepto `
  --watch
```

This provides a live view.

---

# 15.33 Promote Rollout

If manually paused:

```powershell
kubectl argo rollouts promote zepto-backend `
  -n zepto
```

Then:

```text
Canary
 |
 v
Next step
```

---

# 15.34 Abort Rollout

If problems are detected:

```powershell
kubectl argo rollouts abort zepto-backend `
  -n zepto
```

Then verify:

```powershell
kubectl argo rollouts get rollout zepto-backend `
  -n zepto
```

---

# 15.35 Restart Rollout

For another test:

```powershell
kubectl argo rollouts restart zepto-backend `
  -n zepto
```

Use this carefully in production.

---

# 15.36 Blue-Green Deployment

Now let's implement the second strategy.

Blue:

```text
v1.3
```

Green:

```text
v1.4
```

Traffic:

```text
100% → Blue
```

Deploy Green:

```text
100% → Blue
0%   → Green
```

Test Green:

```text
Health
Smoke tests
Metrics
```

Then switch:

```text
0%   → Blue
100% → Green
```

---

# 15.37 Blue-Green Rollout

Example:

```yaml
apiVersion: argoproj.io/v1alpha1

kind: Rollout

metadata:

  name: zepto-backend

  namespace: zepto

spec:

  replicas: 3

  selector:

    matchLabels:

      app: zepto-backend

  template:

    metadata:

      labels:

        app: zepto-backend

    spec:

      containers:

        - name: backend

          image: zepto-backend

          ports:

            - containerPort: 5000

  strategy:

    blueGreen:

      activeService: zepto-backend

      previewService: zepto-backend-preview

      autoPromotionEnabled: false

      scaleDownDelaySeconds: 300
```

---

# 15.38 Blue-Green Services

Active:

```yaml
apiVersion: v1

kind: Service

metadata:

  name: zepto-backend

spec:

  selector:

    app: zepto-backend

  ports:

    - port: 5000

      targetPort: 5000
```

Preview:

```yaml
apiVersion: v1

kind: Service

metadata:

  name: zepto-backend-preview

spec:

  selector:

    app: zepto-backend

  ports:

    - port: 5000

      targetPort: 5000
```

---

# 15.39 Blue-Green Flow

```text
                 Users
                   |
                   v
              Active Service
                   |
                   v
                 BLUE
                 v1.3

                 GREEN
                 v1.4
                   |
                   |
              Preview Service
```

Test:

```text
Preview Service
      |
      v
Green
```

If healthy:

```text
Promote
```

Then:

```text
Active Service
      |
      v
GREEN
```

---

# 15.40 Blue-Green Promotion

Check:

```powershell
kubectl argo rollouts get rollout zepto-backend -n zepto
```

Promote:

```powershell
kubectl argo rollouts promote zepto-backend -n zepto
```

Traffic switches to Green.

---

# 15.41 Blue-Green Rollback

Suppose:

```text
Green = v1.4
```

has an issue immediately after promotion.

Argo Rollouts maintains the previous ReplicaSet according to the configured history/delay.

You can abort/rollback according to the rollout state and configured retention.

The important concept is:

```text
Blue
v1.3
still available

Green
v1.4
problem

        ↓

Switch back to Blue
```

This can make rollback extremely fast.

---

# 15.42 Canary vs Blue-Green

| Feature                 | Canary              | Blue-Green           |
| ----------------------- | ------------------- | -------------------- |
| Initial traffic         | Small %             | 0%                   |
| New environment         | Partial             | Full                 |
| Traffic control         | Gradual             | Switch               |
| Resource usage          | Lower               | Higher               |
| Risk                    | Low                 | Low                  |
| Rollback                | Fast                | Very fast            |
| Real production traffic | Yes                 | Usually after switch |
| Best use                | Continuous releases | Major releases       |

---

# 15.43 Which Strategy for Zepto?

Recommended:

```text
Backend APIs:
Canary

Frontend:
Rolling / Canary

Critical checkout/payment:
Canary + strict SLO

Major application rewrite:
Blue-Green
```

---

# 15.44 Checkout Is Special

Imagine Zepto checkout:

```text
POST /api/orders
```

A bad deployment could cause:

```text
Duplicate orders
Incorrect totals
Payment errors
Inventory errors
```

Therefore:

```text
Checkout release
      |
      v
5% canary
      |
      v
Monitor
      |
      v
Error rate
      |
      v
Latency
      |
      v
Order success rate
      |
      v
Continue
```

---

# 15.45 Business Metrics

Technical metrics are not enough.

Monitor:

```text
HTTP 5xx
CPU
Memory
Latency
```

But also:

```text
Order success rate
Cart failure rate
Checkout failure rate
Payment failure rate
Inventory error rate
```

For example:

```text
HTTP errors = normal
```

but:

```text
Order success rate
99% → 95%
```

means the release is bad.

---

# 15.46 Business SLO

Create a business metric:

```text
order_success_rate
```

Conceptually:

```text
successful orders
-----------------
total order attempts
```

Example:

```text
995 / 1000
=
99.5%
```

If SLO is:

```text
>= 99%
```

the release passes.

---

# 15.47 Prometheus Business Metric

Your Node.js application can expose:

```text
zepto_orders_total
zepto_orders_success_total
zepto_orders_failed_total
```

Then Prometheus can calculate:

```promql
sum(rate(zepto_orders_success_total[5m]))
/
sum(rate(zepto_orders_total[5m]))
```

---

# 15.48 Business SLO Analysis

Analysis:

```yaml
successCondition: result[0] >= 0.99
```

This means:

```text
Order success rate >= 99%
```

Now production deployment becomes:

```text
Technical SLO
+
Business SLO
```

---

# 15.49 Example Release Gate

A release can continue only if:

```text
HTTP 5xx < 0.1%
AND
P95 latency < 500ms
AND
Order success > 99%
```

Architecture:

```text
                   Canary
                      |
          +-----------+-----------+
          |           |           |
          v           v           v
       Error        Latency     Orders
       Rate          P95        Success
          |           |           |
          +-----------+-----------+
                      |
                      v
                Release Gate
                 /       \
               PASS      FAIL
                |          |
                v          v
             Continue    Rollback
```

---

# 15.50 AnalysisRun

When a Rollout references an AnalysisTemplate, Argo Rollouts creates an:

```text
AnalysisRun
```

Check:

```powershell
kubectl get analysisrun -n zepto
```

Describe:

```powershell
kubectl describe analysisrun NAME -n zepto
```

You can see:

```text
Successful
Failed
Inconclusive
```

---

# 15.51 Troubleshooting Analysis

If analysis fails:

```powershell
kubectl describe analysisrun NAME -n zepto
```

Check:

```text
Prometheus address
Prometheus query
Metric name
Labels
Network connectivity
Threshold
```

A common problem is:

```text
Metric does not exist
```

because the application hasn't exposed the expected metric.

---

# 15.52 Verify Prometheus Metrics

Before writing AnalysisTemplates, verify the query manually.

Use Prometheus/Grafana.

For example:

```promql
rate(http_requests_total[5m])
```

Then verify:

```text
Does the metric exist?
```

Next:

```promql
sum(rate(http_requests_total{status=~"5.."}[5m]))
```

Then:

```text
Does it return data?
```

Only then put it into Argo Rollouts.

---

# 15.53 GitOps Structure After Part 15

Update:

```text
zepto-quick-commerce-gitops/
|
+-- apps/
|   |
|   +-- zepto/
|       |
|       +-- base/
|           |
|           +-- rollout-backend.yaml
|           +-- service-backend.yaml
|           +-- service-backend-canary.yaml
|           +-- analysis-error-rate.yaml
|           +-- analysis-latency.yaml
|           +-- analysis-order-success.yaml
|           +-- kustomization.yaml
|       |
|       +-- overlays/
|           |
|           +-- dev/
|           +-- staging/
|           +-- production/
|
+-- argocd/
|   |
|   +-- projects/
|   +-- applications/
|
+-- README.md
```

---

# 15.54 Update Kustomization

Add:

```yaml
resources:

  - rollout-backend.yaml

  - service-backend.yaml

  - service-backend-canary.yaml

  - analysis-error-rate.yaml

  - analysis-latency.yaml

  - analysis-order-success.yaml
```

Remove:

```text
deployment-backend.yaml
```

if the Rollout completely replaces the Deployment.

Do not deploy both controllers managing the same application Pods.

---

# 15.55 Important Migration Step

Do not simply change:

```text
Deployment
```

to:

```text
Rollout
```

on production without planning.

Recommended:

```text
DEV
 |
 v
Install Argo Rollouts
 |
 v
Test Rollout
 |
 v
STAGING
 |
 v
Canary testing
 |
 v
Production
```

---

# 15.56 Dev Testing

Deploy:

```powershell
kubectl apply -k apps/zepto/overlays/dev
```

Then:

```powershell
kubectl argo rollouts get rollout zepto-backend `
  -n zepto `
  --watch
```

Expected:

```text
Healthy
```

---

# 15.57 Trigger a New Version

Update:

```yaml
newTag: NEW_GIT_SHA
```

Push GitOps:

```powershell
git add .
git commit -m "Deploy backend canary"
git push
```

Argo CD sees:

```text
OutOfSync
```

Then synchronizes.

---

# 15.58 Observe Canary

```powershell
kubectl argo rollouts get rollout zepto-backend `
  -n zepto `
  --watch
```

You may see:

```text
Step 1
5%

Step 2
25%

Step 3
50%

Step 4
100%
```

If you have pauses:

```text
Paused
```

may appear.

---

# 15.59 Observe Analysis

```powershell
kubectl get analysisrun -n zepto
```

Then:

```powershell
kubectl describe analysisrun NAME -n zepto
```

Expected:

```text
Status:
Successful
```

---

# 15.60 Test Automated Rollback

Deploy intentionally faulty code to DEV.

For example:

```text
v1.5
```

causes HTTP 500 responses.

Canary:

```text
5%
```

Prometheus:

```text
Error rate = 5%
```

SLO:

```text
< 1%
```

Result:

```text
FAILED
```

Argo Rollouts:

```text
ABORT
```

Stable:

```text
v1.4
```

remains active.

---

# 15.61 Verify Rollback

```powershell
kubectl argo rollouts get rollout zepto-backend `
  -n zepto
```

Then:

```powershell
kubectl get pods -n zepto
```

Check the image:

```powershell
kubectl get pods -n zepto `
  -o jsonpath="{range .items[*]}{.spec.containers[0].image}{'\n'}{end}"
```

---

# 15.62 Production Deployment

Production flow:

```text
Developer
    |
    v
Application PR
    |
    v
CI
    |
    v
Image SHA
    |
    v
GitOps PR
    |
    v
Staging
    |
    v
Canary
    |
    v
Automated SLO tests
    |
    v
Production approval
    |
    v
5%
    |
    v
25%
    |
    v
50%
    |
    v
100%
```

---

# 15.63 Production Approval

Do not let:

```text
GitHub Actions
```

automatically deploy:

```text
100% production
```

Instead:

```text
GitOps PR
   |
   v
Review
   |
   v
Merge
   |
   v
Argo CD
   |
   v
Rollout
   |
   v
5%
   |
   v
Analysis
```

For the final promotion:

```text
Human approval
```

can be required.

---

# 15.64 SLO Release Policy

Create:

```text
docs/release-policy.md
```

```markdown
# Zepto Production Release Policy

## Canary Stages

5%
25%
50%
100%

## Release Gates

HTTP 5xx:
< 0.1%

P95 latency:
< 500ms

Order success rate:
>= 99%

Availability:
>= 99.9%

## Rollback Conditions

Rollback if:

- Error rate exceeds threshold
- P95 latency exceeds threshold
- Order success rate falls below threshold
- Critical business metric degrades
- Security issue discovered

## Production Approval

Production releases require:

- CI success
- Security scan success
- Staging validation
- Canary analysis success
- Production approval
```

---

# 15.65 GitHub Actions + GitOps + Rollouts

The final deployment process is now:

```text
             GitHub
                |
                v
         GitHub Actions
                |
        +-------+-------+
        |               |
        v               v
      Tests          Security
        |               |
        +-------+-------+
                |
                v
        Artifact Registry
                |
                v
           GitOps PR
                |
                v
            Argo CD
                |
                v
         Argo Rollouts
                |
                v
           Canary 5%
                |
                v
            Prometheus
                |
                v
           SLO Analysis
           /           \
        PASS            FAIL
         |               |
         v               v
       25%             Abort
         |               |
         v               v
       50%            Stable
         |
         v
       100%
```

---

# 15.66 Monitoring Dashboard

Extend your Grafana dashboard from Part 10.

Add:

```text
+------------------------------------------------------+
|             ZEPTO PROGRESSIVE DELIVERY              |
+------------------------------------------------------+

+----------------+----------------+-------------------+
| Stable Version | Canary Version | Canary Weight     |
+----------------+----------------+-------------------+

+----------------+----------------+-------------------+
| Error Rate     | P95 Latency    | P99 Latency       |
+----------------+----------------+-------------------+

+----------------+----------------+-------------------+
| Order Success  | 5xx            | Request Rate      |
+----------------+----------------+-------------------+

+------------------------------------------------------+
|                Rollout Status                        |
+------------------------------------------------------+

+------------------------------------------------------+
|                Analysis Results                      |
+------------------------------------------------------+
```

---

# 15.67 Alerts

Create alerts for:

```text
Canary error rate > threshold
Canary latency > threshold
Canary availability < threshold
Rollout degraded
Analysis failed
Production rollback
```

Example:

```text
🚨 Zepto Canary Failed

Version:
a83f921

Error Rate:
2.4%

SLO:
< 0.1%

Action:
Automatic rollback
```

---

# 15.68 Release Observability

At this point your observability platform becomes:

```text
                 Release
                    |
          +---------+---------+
          |         |         |
          v         v         v
       Metrics     Logs     Traces
          |         |         |
          +---------+---------+
                    |
                    v
                 Grafana
                    |
                    v
              Release Decision
```

Later, distributed tracing can be added with OpenTelemetry.

---

# 15.69 Canary and Distributed Tracing

For future enhancement:

```text
React
  |
  v
Node.js
  |
  v
MySQL
```

can be traced:

```text
Request
 |
 +-- Frontend
 |
 +-- API
 |
 +-- Product Service
 |
 +-- Database
```

Then compare:

```text
Stable trace latency
vs
Canary trace latency
```

This becomes Part 16 territory.

---

# 15.70 Production Failure Example

Suppose:

```text
Version:
v1.6
```

starts at:

```text
5%
```

Metrics:

```text
Error Rate: 0.05%
P95: 350ms
Order Success: 99.8%
```

All pass.

Continue:

```text
25%
```

Metrics:

```text
Error Rate: 0.08%
P95: 420ms
Order Success: 99.5%
```

Pass.

Continue:

```text
50%
```

Metrics:

```text
Error Rate: 0.9%
P95: 800ms
Order Success: 97.5%
```

Fail.

Argo Rollouts:

```text
ABORT
```

Traffic returns:

```text
100% Stable
```

No need for a manual emergency deployment.

---

# 15.71 Why This Is Better

Without progressive delivery:

```text
v1.6
 |
 v
100% users
 |
 v
Problem
 |
 v
Incident
 |
 v
Rollback
```

With progressive delivery:

```text
v1.6
 |
 v
5%
 |
 v
Problem detected
 |
 v
Automatic rollback
 |
 v
95%+ users never affected
```

This is the main benefit.

---

# 15.72 Production Checklist

## Argo Rollouts

```text
[ ] Controller installed
[ ] CRDs installed
[ ] CLI installed
[ ] Rollout created
```

## Canary

```text
[ ] Stable service
[ ] Canary service
[ ] 5% stage
[ ] 25% stage
[ ] 50% stage
[ ] 100% stage
```

## Metrics

```text
[ ] Error rate
[ ] P95 latency
[ ] Availability
[ ] Request rate
[ ] Business metrics
```

## Automated Analysis

```text
[ ] AnalysisTemplate
[ ] AnalysisRun
[ ] Prometheus query
[ ] Success condition
[ ] Failure condition
```

## Rollback

```text
[ ] Abort tested
[ ] Automatic rollback tested
[ ] Git rollback tested
```

## Production

```text
[ ] Human approval
[ ] Release policy
[ ] SLO defined
[ ] Grafana dashboard
[ ] Alerts
```

---

# 15.73 Final GitOps Repository

Your repository now becomes:

```text
zepto-quick-commerce-gitops/
|
+-- apps/
|   |
|   +-- zepto/
|       |
|       +-- base/
|       |   |
|       |   +-- rollout-backend.yaml
|       |   +-- service-backend.yaml
|       |   +-- service-backend-canary.yaml
|       |   +-- service-backend-preview.yaml
|       |   +-- rollout-frontend.yaml
|       |   |
|       |   +-- analysis-error-rate.yaml
|       |   +-- analysis-latency.yaml
|       |   +-- analysis-availability.yaml
|       |   +-- analysis-order-success.yaml
|       |   |
|       |   +-- kustomization.yaml
|       |
|       +-- overlays/
|           |
|           +-- dev/
|           |
|           +-- staging/
|           |
|           +-- production/
|
+-- argocd/
|   |
|   +-- projects/
|   |   +-- zepto-project.yaml
|   |
|   +-- applications/
|       +-- zepto-dev.yaml
|       +-- zepto-staging.yaml
|       +-- zepto-production.yaml
|
+-- docs/
|   |
|   +-- release-policy.md
|   +-- rollback.md
|   +-- progressive-delivery.md
|
+-- README.md
```

---

# 15.74 Complete Zepto Deployment Platform

You now have:

```text
                           USERS
                             |
                             v
                      HTTPS / Gateway
                             |
                             v
                         GKE
                             |
                 +-----------+-----------+
                 |                       |
                 v                       v
             Frontend                Backend
                                       |
                                +------+------+
                                |             |
                                v             v
                           Stable         Canary
                           v1.5           v1.6
                                \         /
                                 \       /
                                  \     /
                                   Users
                                     |
                                     v
                                 Prometheus
                                     |
                                     v
                              AnalysisTemplate
                                     |
                            +--------+--------+
                            |                 |
                            v                 v
                           PASS              FAIL
                            |                 |
                            v                 v
                       Continue             Abort
                            |                 |
                            v                 v
                         25/50%             Stable
                            |
                            v
                          100%
```

---

# 15.75 Complete DevOps Architecture

The Zepto project has now evolved into:

```text
                 ┌──────────────────────────┐
                 │        Developer         │
                 └────────────┬─────────────┘
                              │
                              v
                 ┌──────────────────────────┐
                 │         GitHub           │
                 └────────────┬─────────────┘
                              │
                              v
                 ┌──────────────────────────┐
                 │     GitHub Actions       │
                 │                          │
                 │ Test                     │
                 │ Build                    │
                 │ Scan                     │
                 └────────────┬─────────────┘
                              │
                              v
                 ┌──────────────────────────┐
                 │    Artifact Registry     │
                 └────────────┬─────────────┘
                              │
                              v
                 ┌──────────────────────────┐
                 │       GitOps Repo        │
                 │       Kustomize          │
                 └────────────┬─────────────┘
                              │
                              v
                 ┌──────────────────────────┐
                 │         Argo CD          │
                 └────────────┬─────────────┘
                              │
                              v
                 ┌──────────────────────────┐
                 │     Argo Rollouts        │
                 │                          │
                 │ Canary / Blue-Green      │
                 └────────────┬─────────────┘
                              │
                     ┌────────┴────────┐
                     │                 │
                     v                 v
                  Stable            Canary
                     │                 │
                     └────────┬────────┘
                              │
                              v
                            GKE
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             v                v                v
         Prometheus        Grafana         Logging
             │                │                │
             └────────────────┼────────────────┘
                              │
                              v
                       SLO Release Gate
                              │
                     ┌────────┴────────┐
                     │                 │
                     v                 v
                  Continue          Rollback
```

---

# 15.76 Part 15 Success Criteria

Part 15 is complete when:

```text
[✓] Argo Rollouts installed

[✓] Rollout CRD working

[✓] Backend converted from Deployment to Rollout

[✓] Canary strategy configured

[✓] Stable Service configured

[✓] Canary Service configured

[✓] 5% canary tested

[✓] 25% canary tested

[✓] 50% canary tested

[✓] 100% promotion tested

[✓] Blue-Green strategy understood/tested

[✓] Preview Service configured

[✓] Prometheus AnalysisTemplate created

[✓] Error-rate analysis configured

[✓] Latency analysis configured

[✓] Availability analysis configured

[✓] Business SLO configured

[✓] AnalysisRun verified

[✓] Automated rollback tested

[✓] Manual rollback tested

[✓] GitOps rollback tested

[✓] Production approval implemented

[✓] Grafana progressive-delivery dashboard created

[✓] Canary alerts configured

[✓] Release policy documented
```

---

# 15.77 Final Zepto Release Process

From now on, a production release should look like:

```text
Developer
    |
    v
Pull Request
    |
    v
CI Tests
    |
    v
Security Scan
    |
    v
Docker Build
    |
    v
Artifact Registry
    |
    v
GitOps PR
    |
    v
Argo CD
    |
    v
Staging
    |
    v
Smoke Tests
    |
    v
Production Approval
    |
    v
Canary 5%
    |
    v
SLO Analysis
    |
    +------ FAIL ------> Automatic Rollback
    |
    PASS
    |
    v
Canary 25%
    |
    v
SLO Analysis
    |
    +------ FAIL ------> Automatic Rollback
    |
    PASS
    |
    v
Canary 50%
    |
    v
SLO Analysis
    |
    +------ FAIL ------> Automatic Rollback
    |
    PASS
    |
    v
100% Production
    |
    v
Monitoring
```

That is the key outcome of **Part 15**: Zepto is no longer just doing automated deployments; it now has a **controlled progressive release system** where GitOps defines the desired state, Argo CD synchronizes it, Argo Rollouts controls how the new version reaches users, and Prometheus/SLO measurements determine whether the rollout continues or is automatically rolled back.

**Next logical step — Part 16:** **Distributed Tracing and Advanced Observability with OpenTelemetry + Jaeger/Tempo + Grafana**, including React → Node.js → MySQL request tracing, correlation IDs, trace-based troubleshooting, RED/USE metrics, and connecting traces with the centralized logs and Prometheus metrics from Parts 10–11.
