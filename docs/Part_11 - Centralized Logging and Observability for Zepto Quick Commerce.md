# Part 11 — Centralized Logging and Observability for Zepto Quick Commerce

After Part 10, we have:

```text
Part 10
Prometheus + Grafana
        |
        +-- Metrics
        +-- Dashboards
        +-- Alerts
```

Now Part 11 adds **centralized logging and observability**.

The target architecture becomes:

```text
                         ZEpto Quick Commerce
                                  |
                    +-------------+-------------+
                    |                           |
                 Metrics                      Logs
                    |                           |
                    v                           v
               Prometheus               Google Cloud Logging
                    |                           |
                    v                           v
                Grafana                Logs Explorer
                    |                           |
                    +-------------+-------------+
                                  |
                                  v
                           Troubleshooting
```

For GKE, Google Cloud's managed logging/monitoring integration is the preferred production approach. GKE workloads can write logs to stdout/stderr and Google Cloud automatically collects them when Cloud Logging is enabled.

---

# 11.1 What We Will Build

We will configure centralized logging for:

```text
Zepto
|
+-- React Frontend
|      |
|      +-- Nginx access logs
|      +-- Nginx error logs
|
+-- Node.js Backend
|      |
|      +-- HTTP requests
|      +-- Application errors
|      +-- Database errors
|      +-- Startup/shutdown events
|
+-- MySQL
|      |
|      +-- Container logs
|      +-- Startup/errors
|
+-- Kubernetes
       |
       +-- Pod events
       +-- Container restarts
       +-- Deployment events
```

Then we will correlate:

```text
Grafana Alert
      |
      v
Prometheus Metric
      |
      v
Kubernetes Pod
      |
      v
Cloud Logging
      |
      v
Node.js Error
      |
      v
Root Cause
```

---

# 11.2 Observability Architecture

The complete Zepto platform now looks like:

```text
                         INTERNET
                            |
                            v
                    Google Load Balancer
                            |
                            v
                         Ingress
                            |
                 +----------+----------+
                 |                     |
                 v                     v
             Frontend               Backend
              React                 Node.js
                 |                     |
                 |                     v
                 |                   MySQL
                 |
                 +---------------------+
                            |
                            |
              +-------------+-------------+
              |                           |
              v                           v
          Prometheus                Cloud Logging
              |                           |
              v                           v
           Grafana                  Logs Explorer
              |                           |
              +-------------+-------------+
                            |
                            v
                       Alert / RCA
```

---

# 11.3 Three Types of Observability

We will use three major signals:

```text
1. Metrics
2. Logs
3. Traces
```

For this Part 11 we focus primarily on:

```text
Metrics + Logs
```

Tracing can be added later with OpenTelemetry.

---

# 11.4 Why Centralized Logging?

Without centralized logging:

```text
Developer
   |
   +--> kubectl logs pod-1
   +--> kubectl logs pod-2
   +--> kubectl logs pod-3
```

This becomes difficult when Pods are recreated.

With centralized logging:

```text
All Pods
   |
   v
Google Cloud Logging
   |
   v
Search
Filter
Analyze
Alert
```

Logs survive Pod recreation and can be searched centrally.

---

# 11.5 GKE Logging Architecture

The recommended architecture is:

```text
Zepto Pods
   |
   | stdout/stderr
   v
GKE Logging Agent
   |
   v
Cloud Logging
   |
   v
Log Explorer
```

For GKE, Google manages the collection infrastructure rather than requiring you to deploy a separate Fluent Bit/Fluentd DaemonSet for the basic GKE logging path.

---

# 11.6 Verify GKE Logging

First check the cluster:

```powershell
gcloud container clusters describe zepto-gke-cluster `
    --region asia-south1
```

Search the output for:

```text
loggingService
```

You should see Google Cloud Logging configured.

You can also inspect:

```powershell
gcloud container clusters describe zepto-gke-cluster `
    --region asia-south1 `
    --format="value(loggingConfig.componentConfig.enableComponents)"
```

Depending on the GKE version/configuration, the exact output may differ.

---

# 11.7 Verify Logs in Google Cloud Console

Open Google Cloud Console.

Navigate:

```text
Google Cloud
   |
   v
Logging
   |
   v
Logs Explorer
```

Select the project:

```text
zepto-ecommerce-class
```

You should be able to query Kubernetes logs.

---

# 11.8 First Kubernetes Log Query

In Logs Explorer, start with:

```text
resource.type="k8s_container"
```

This retrieves container logs.

To focus on Zepto:

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
```

Now you are looking specifically at:

```text
Zepto namespace
```

---

# 11.9 Backend Logs

Filter:

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
resource.labels.container_name="backend"
```

Depending on your container metadata and naming, you may instead filter by Pod/application labels.

A more flexible query is:

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
labels.k8s-pod/app="zepto-backend"
```

---

# 11.10 Frontend Logs

Use:

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
labels.k8s-pod/app="zepto-frontend"
```

This allows you to see frontend/Nginx container logs.

---

# 11.11 MySQL Logs

Use:

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
labels.k8s-pod/app="zepto-mysql"
```

This allows centralized investigation of MySQL container output.

---

# 11.12 Why stdout/stderr Matters

Your Node.js application currently uses:

```javascript
morgan("dev")
```

That writes HTTP logs to stdout.

Kubernetes captures container stdout/stderr.

Therefore:

```text
Node.js
   |
   | console.log()
   | console.error()
   | morgan()
   v
stdout/stderr
   |
   v
GKE
   |
   v
Cloud Logging
```

This is the simplest and recommended approach.

---

# 11.13 Improve Node.js Logging

For a production-style application, replace plain log messages with structured JSON logs.

Instead of:

```javascript
console.log("Server started");
```

use:

```javascript
console.log(JSON.stringify({
    severity: "INFO",
    service: "zepto-backend",
    event: "server_started",
    message: "Zepto backend server started",
    port: 5000
}));
```

For errors:

```javascript
console.error(JSON.stringify({
    severity: "ERROR",
    service: "zepto-backend",
    event: "database_error",
    message: error.message
}));
```

Google Cloud Logging can recognize structured JSON fields and make them searchable.

---

# 11.14 Create a Logger Module

Create:

```text
backend/config/logger.js
```

Use:

```javascript
function logInfo(event, message, metadata = {}) {

    console.log(
        JSON.stringify({
            severity: "INFO",
            service: "zepto-backend",
            event,
            message,
            ...metadata,
            timestamp: new Date().toISOString()
        })
    );

}


function logWarn(event, message, metadata = {}) {

    console.log(
        JSON.stringify({
            severity: "WARNING",
            service: "zepto-backend",
            event,
            message,
            ...metadata,
            timestamp: new Date().toISOString()
        })
    );

}


function logError(event, message, metadata = {}) {

    console.error(
        JSON.stringify({
            severity: "ERROR",
            service: "zepto-backend",
            event,
            message,
            ...metadata,
            timestamp: new Date().toISOString()
        })
    );

}


module.exports = {
    logInfo,
    logWarn,
    logError
};
```

---

# 11.15 Update Backend app.js

Import:

```javascript
const {
    logInfo,
    logError
} = require("./config/logger");
```

Then startup logging:

```javascript
logInfo(
    "application_start",
    "Zepto backend application initialized",
    {
        port: process.env.PORT || 5000
    }
);
```

For database errors:

```javascript
catch (error) {

    logError(
        "database_health_check_failed",
        error.message
    );

    res.status(500).json({
        status: "FAILED",
        error: error.message
    });

}
```

---

# 11.16 Better HTTP Request Logging

You already have:

```javascript
morgan("dev");
```

For centralized production logging, use a JSON format.

Example:

```javascript
morgan((tokens, req, res) => {

    return JSON.stringify({

        severity:
            res.statusCode >= 500
                ? "ERROR"
                : "INFO",

        service: "zepto-backend",

        event: "http_request",

        method: tokens.method(req, res),

        path: tokens.url(req, res),

        status:
            Number(tokens.status(req, res)),

        response_time_ms:
            Number(tokens["response-time"](req, res))

    });

});
```

This makes the logs much easier to query.

---

# 11.17 Recommended Backend Logging Format

A request should look conceptually like:

```json
{
  "severity": "INFO",
  "service": "zepto-backend",
  "event": "http_request",
  "method": "GET",
  "path": "/api/products",
  "status": 200,
  "response_time_ms": 34,
  "timestamp": "2026-08-22T10:15:00.000Z"
}
```

An error:

```json
{
  "severity": "ERROR",
  "service": "zepto-backend",
  "event": "database_error",
  "message": "Connection timeout",
  "timestamp": "2026-08-22T10:16:00.000Z"
}
```

---

# 11.18 Important Security Rule

Never log:

```text
DB_PASSWORD
JWT_SECRET
password
credit card numbers
authentication tokens
cookies
session tokens
```

Bad:

```javascript
console.log(req.body);
```

because an order/login request might contain sensitive information.

Instead:

```javascript
console.log(JSON.stringify({
    severity: "INFO",
    event: "order_created",
    orderId: order.id
}));
```

---

# 11.19 Add Request ID

A very useful observability improvement is a request ID.

The flow becomes:

```text
Browser
   |
   | X-Request-ID
   v
Ingress
   |
   v
Node.js
   |
   +-- request ID
   |
   v
MySQL
```

Then you can search all logs belonging to one request.

---

# 11.20 Request ID Middleware

Create:

```text
backend/middleware/requestId.js
```

```javascript
const crypto = require("crypto");

function requestIdMiddleware(req, res, next) {

    const requestId =
        req.headers["x-request-id"] ||
        crypto.randomUUID();

    req.requestId = requestId;

    res.setHeader(
        "X-Request-ID",
        requestId
    );

    next();
}

module.exports = requestIdMiddleware;
```

---

# 11.21 Add Request ID to app.js

Import:

```javascript
const requestIdMiddleware =
    require("./middleware/requestId");
```

Add before your routes:

```javascript
app.use(requestIdMiddleware);
```

Now every request gets:

```text
X-Request-ID
```

---

# 11.22 Log Request ID

Update the logger:

```javascript
logInfo(
    "http_request",
    "HTTP request completed",
    {
        requestId: req.requestId,
        method: req.method,
        path: req.path,
        status: res.statusCode
    }
);
```

Now Logs Explorer can search:

```text
requestId="..."
```

---

# 11.23 Add Application Labels

Your Kubernetes Pods already have:

```yaml
labels:
  app: zepto-backend
```

We can extend them:

```yaml
labels:
  app: zepto-backend
  component: backend
  environment: production
```

For frontend:

```yaml
labels:
  app: zepto-frontend
  component: frontend
  environment: production
```

For MySQL:

```yaml
labels:
  app: zepto-mysql
  component: database
  environment: production
```

These labels make filtering easier.

---

# 11.24 Add Environment Label

Backend deployment:

```yaml
metadata:
  labels:
    app: zepto-backend
    component: backend
    environment: production
```

Pod:

```yaml
template:
  metadata:
    labels:
      app: zepto-backend
      component: backend
      environment: production
```

Do the same for frontend and MySQL.

---

# 11.25 Logging Dashboard

Now create a Grafana dashboard for logs.

However, there is an important architecture point:

```text
Prometheus
=
Metrics

Cloud Logging
=
Logs
```

Grafana can visualize Cloud Logging data, but Google Cloud's Logs Explorer is usually the primary place for detailed GKE log investigation.

For a unified Grafana observability experience, you can later configure a Google Cloud Logging data source or use a Loki-based architecture.

For this project:

```text
Grafana
  |
  +-- Metrics
  |
  +-- Kubernetes dashboards

Logs Explorer
  |
  +-- Application logs
  +-- Kubernetes logs
  +-- MySQL logs
```

---

# 11.26 Create Useful Log Queries

## All Zepto logs

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
```

---

## Backend errors

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
severity>=ERROR
```

---

## Backend only

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
labels.k8s-pod/app="zepto-backend"
```

---

## Frontend only

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
labels.k8s-pod/app="zepto-frontend"
```

---

## MySQL only

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
labels.k8s-pod/app="zepto-mysql"
```

---

# 11.27 Search HTTP 500 Errors

If structured logs contain:

```json
"status": 500
```

you can search for the backend service and HTTP error.

For example:

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
jsonPayload.service="zepto-backend"
jsonPayload.status=500
```

---

# 11.28 Search Database Errors

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
jsonPayload.event="database_error"
```

This is extremely useful.

Instead of searching thousands of logs, you immediately find:

```text
database_error
```

events.

---

# 11.29 Search a Specific Request

If the application generated:

```text
requestId=8f1b3d...
```

search:

```text
resource.type="k8s_container"
jsonPayload.requestId="8f1b3d..."
```

Now you can trace:

```text
Request
   |
   +-- Backend log
   |
   +-- Database error
   |
   +-- Response
```

---

# 11.30 Log-Based Metrics

Google Cloud Logging can turn matching logs into metrics.

For example:

```text
Backend ERROR logs
        |
        v
Log-based metric
        |
        v
Cloud Monitoring
        |
        v
Alert
```

Create a log-based metric for:

```text
Zepto backend errors
```

Conceptually filter:

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
jsonPayload.service="zepto-backend"
severity>=ERROR
```

Metric name:

```text
zepto_backend_errors
```

Then you can alert when:

```text
backend errors > threshold
```

---

# 11.31 Logs + Prometheus Correlation

This is where observability becomes powerful.

Suppose Grafana shows:

```text
Backend 5xx rate
      ^
      |
      | 2.5%
      |
```

Then:

```text
Prometheus
   |
   v
High 5xx rate
```

Search Cloud Logging:

```text
service="zepto-backend"
severity>=ERROR
```

You discover:

```text
database_error
Connection timeout
```

Then:

```text
kubectl
   |
   v
MySQL Pod
   |
   v
Restart count increased
```

Root cause:

```text
MySQL instability
```

---

# 11.32 Observability Investigation Workflow

Use this workflow whenever production has an issue:

```text
1. User reports problem
          |
          v
2. Check Grafana
          |
          v
3. Check Prometheus metrics
          |
          v
4. Identify affected Pod
          |
          v
5. Check Kubernetes status
          |
          v
6. Open Cloud Logging
          |
          v
7. Filter application errors
          |
          v
8. Search request ID
          |
          v
9. Identify root cause
          |
          v
10. Fix and deploy
```

---

# 11.33 Example Incident

Suppose users report:

```text
"Checkout is failing."
```

First check Grafana:

```text
Backend 5xx
   |
   v
8%
```

Prometheus:

```text
HTTP 500 rate increased
```

Cloud Logging:

```text
event=database_error
message=Connection timeout
```

Kubernetes:

```powershell
kubectl get pods -n zepto
```

MySQL:

```text
Restart count = 4
```

Then:

```powershell
kubectl logs deployment/zepto-mysql -n zepto
```

You find the database container restarting.

Now you have:

```text
User Issue
   |
   v
HTTP 500
   |
   v
Database Error
   |
   v
MySQL Restart
```

This is observability.

---

# 11.34 Kubernetes Events

Logs aren't the only source.

Use:

```powershell
kubectl get events -n zepto `
    --sort-by=.lastTimestamp
```

You might discover:

```text
FailedScheduling

FailedMount

BackOff

Unhealthy

Failed

Pulling

Pulled
```

These events are extremely useful for Kubernetes troubleshooting.

---

# 11.35 Monitor Deployment Health

Run:

```powershell
kubectl get deployment -n zepto
```

Example:

```text
NAME             READY   UP-TO-DATE   AVAILABLE
zepto-backend    2/2     2            2
zepto-frontend   2/2     2            2
zepto-mysql      1/1     1            1
```

Prometheus should also monitor:

```text
desired replicas
available replicas
unavailable replicas
```

---

# 11.36 Monitor Pod Restarts

Prometheus:

```promql
sum by(pod) (
  kube_pod_container_status_restarts_total{
    namespace="zepto"
  }
)
```

Cloud Logging:

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
severity>=ERROR
```

Together:

```text
Metrics
+
Logs
```

give much better troubleshooting.

---

# 11.37 Monitor Node Problems

If multiple Pods fail at once:

```text
Frontend Pod
     |
     X

Backend Pod
     |
     X

Monitoring Pod
     |
     X
```

Check:

```powershell
kubectl get nodes
```

Then:

```powershell
kubectl describe node NODE_NAME
```

Then check Grafana:

```text
Node CPU
Node memory
Node disk
```

Then Cloud Logging:

```text
resource.type="k8s_node"
```

This can identify node-level issues.

---

# 11.38 Add Logging Documentation

Create:

```text
monitoring/README.md
```

Use:

````markdown
# Zepto Monitoring and Logging

## Metrics

Prometheus collects:

- Kubernetes metrics
- Node metrics
- Pod metrics
- Deployment metrics
- Zepto backend application metrics

## Dashboards

Grafana is used for:

- CPU
- Memory
- Pod restarts
- Deployment replicas
- Backend requests
- Backend latency
- HTTP 5xx errors

## Logs

GKE sends container logs to Google Cloud Logging.

Primary log sources:

- Zepto frontend
- Zepto backend
- MySQL
- Kubernetes

## Useful Log Query

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
````

## Backend Error Query

```text
resource.type="k8s_container"
resource.labels.namespace_name="zepto"
jsonPayload.service="zepto-backend"
severity>=ERROR
```

## Kubernetes Debugging

```bash
kubectl get pods -n zepto

kubectl describe pod POD_NAME -n zepto

kubectl logs POD_NAME -n zepto

kubectl get events -n zepto --sort-by=.lastTimestamp
```

````

---

# 11.39 Git Structure After Part 11

Your project now becomes:

```text
zepto-quick-commerce/
|
+-- frontend/
|
+-- backend/
|   |
|   +-- config/
|   |   +-- db.js
|   |   +-- metrics.js
|   |   +-- logger.js
|   |
|   +-- middleware/
|       +-- requestId.js
|
+-- database/
|
+-- kubernetes/
|   |
|   +-- namespace.yaml
|   +-- secret.yaml
|   |
|   +-- mysql/
|   |
|   +-- backend/
|   |
|   +-- frontend/
|   |
|   +-- ingress/
|
+-- monitoring/
|   |
|   +-- values.yaml
|   |
|   +-- servicemonitors/
|   |   +-- backend-servicemonitor.yaml
|   |
|   +-- prometheus-rules/
|   |   +-- zepto-alerts.yaml
|   |
|   +-- grafana/
|       +-- README.md
|
+-- .github/
|   |
|   +-- workflows/
|       +-- deploy.yml
|
+-- README.md
````

---

# 11.40 Commit Part 11

Create a branch:

```powershell
git checkout -b feature/centralized-logging
```

Add changes:

```powershell
git add backend/
git add kubernetes/
git add monitoring/
```

Commit:

```powershell
git commit -m "Add centralized logging and observability"
```

Push:

```powershell
git push origin feature/centralized-logging
```

Then create a Pull Request.

---

# 11.41 Part 11 CI/CD Flow

When merged:

```text
Git Push
   |
   v
GitHub Actions
   |
   +-- Test backend
   |
   +-- Build backend
   |
   +-- Push image
   |
   v
Artifact Registry
   |
   v
GKE
   |
   v
Backend updated
   |
   +-- /health
   |
   +-- /metrics
   |
   +-- structured logs
```

Monitoring configuration is then applied:

```powershell
kubectl apply -f monitoring/
```

For the nested resources, use:

```powershell
kubectl apply -f monitoring/servicemonitors/
kubectl apply -f monitoring/prometheus-rules/
```

---

# 11.42 Final Monitoring Architecture

After Part 11:

```text
                         ZEPTO
                           |
          +----------------+----------------+
          |                |                |
          v                v                v
       Frontend         Backend           MySQL
          |                |                |
          |                +---- /metrics  |
          |                |                |
          +----------------+----------------+
                           |
             +-------------+-------------+
             |                           |
             v                           v
        Cloud Logging               Prometheus
             |                           |
             v                           v
       Logs Explorer                  Grafana
             |                           |
             |                           v
             |                     Dashboards
             |                           |
             +------------+--------------+
                          |
                          v
                     Alert / RCA
```

---

# 11.43 Final Observability Stack

```text
+----------------------------------------------------+
|                  ZEPTO APPLICATION                 |
+----------------------------------------------------+
| React | Node.js | MySQL | Kubernetes               |
+--------------------------+-------------------------+
                           |
             +-------------+-------------+
             |                           |
             v                           v
         METRICS                       LOGS
             |                           |
             v                           v
        Prometheus                Cloud Logging
             |                           |
             v                           v
          Grafana                   Logs Explorer
             |                           |
             +-------------+-------------+
                           |
                           v
                    INCIDENT RESPONSE
```

---

# 11.44 Part 11 Success Criteria

You have successfully completed Part 11 when:

```text
[✓] GKE logging enabled

[✓] Zepto container logs visible in Cloud Logging

[✓] Backend logs searchable

[✓] Frontend logs searchable

[✓] MySQL logs searchable

[✓] Kubernetes events available

[✓] Node.js structured logging implemented

[✓] Request IDs implemented

[✓] Sensitive information excluded from logs

[✓] Backend /metrics implemented

[✓] Prometheus scraping backend

[✓] Grafana displaying metrics

[✓] Prometheus alerts configured

[✓] Cloud Logging queries documented

[✓] Logs and metrics can be correlated

[✓] Incident troubleshooting workflow documented
```

---

# 11.45 Complete Zepto DevOps Journey

You now have:

```text
Part 1
Architecture
    |
    v
Part 2
React
    |
    v
Part 3
Node.js
    |
    v
Part 4
MySQL
    |
    v
Part 5
Docker
    |
    v
Part 6
GKE
    |
    v
Part 7
Kubernetes
    |
    v
Part 8
GitHub Actions
    |
    v
Part 9
End-to-End CI/CD
    |
    v
Part 10
Prometheus + Grafana
    |
    v
Part 11
Centralized Logging + Observability
```

The next logical step is **Part 12 — Security hardening and production readiness**: Kubernetes NetworkPolicies, non-root containers, image scanning, Artifact Registry vulnerability scanning, Workload Identity, Secret Manager, RBAC hardening, HTTPS/TLS, security headers, resource quotas, Pod Security, and production GKE best practices.
