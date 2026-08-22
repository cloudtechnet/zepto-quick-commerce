# Part 10 — Monitoring Zepto Quick Commerce on GKE Using Prometheus and Grafana

After completing **Part 9 — End-to-End CI/CD Testing**, the next step is to add observability.

We will monitor:

```text
Zepto Quick Commerce
        |
        +-- GKE Cluster
        |
        +-- Kubernetes Nodes
        |
        +-- Frontend Pods
        |
        +-- Backend Pods
        |
        +-- MySQL Pod
        |
        +-- CPU / Memory
        |
        +-- Pod Restarts
        |
        +-- Deployment Replicas
        |
        +-- HTTP/API Metrics
        |
        +-- MySQL Metrics
        |
        +-- Grafana Dashboards
        |
        +-- Prometheus Alerts
```

The recommended learning setup is the **kube-prometheus-stack Helm chart**, which installs Prometheus, Grafana, Alertmanager, kube-state-metrics, node-exporter, and Kubernetes monitoring rules together. See the official [Prometheus documentation](https://prometheus.io/docs/introduction/overview/?utm_source=chatgpt.com), [Grafana documentation](https://grafana.com/docs/grafana/latest/?utm_source=chatgpt.com), and [Prometheus Community Helm charts](https://github.com/prometheus-community/helm-charts?utm_source=chatgpt.com).

---

# 10.1 Monitoring Architecture

Our final architecture becomes:

```text
                         INTERNET
                            |
                            v
                    GKE Load Balancer
                            |
                            v
                         Ingress
                            |
                 +----------+----------+
                 |                     |
                 v                     v
          React Frontend          Node.js Backend
                 |                     |
                 |                     v
                 |                   MySQL
                 |
                 +---------------------+
                           |
                           |
                    Application
                       Metrics
                           |
                           v
                     Prometheus
                           |
                    +------+------+
                    |             |
                    v             v
                 Grafana      Alertmanager
                    |
                    v
                Dashboards
```

Prometheus collects metrics.

Grafana visualizes them.

Alertmanager manages Prometheus alerts.

---

# 10.2 What We Will Install

Instead of installing each component separately, install:

```text
kube-prometheus-stack
```

It provides:

```text
kube-prometheus-stack
|
+-- Prometheus
|
+-- Grafana
|
+-- Alertmanager
|
+-- kube-state-metrics
|
+-- node-exporter
|
+-- Prometheus Operator
|
+-- Kubernetes dashboards/rules
```

This is much easier to operate than creating Prometheus YAML manually.

---

# 10.3 Prerequisites

Verify the cluster first:

```powershell
kubectl get nodes
```

Expected:

```text
STATUS
Ready
Ready
```

Check Zepto:

```powershell
kubectl get pods -n zepto
```

Expected:

```text
zepto-mysql-xxxxx       Running

zepto-backend-xxxxx     Running
zepto-backend-yyyyy     Running

zepto-frontend-xxxxx    Running
zepto-frontend-yyyyy    Running
```

Check Helm:

```powershell
helm version
```

If Helm is not installed, install Helm using the official [Helm installation documentation](https://helm.sh/docs/intro/install/?utm_source=chatgpt.com).

---

# 10.4 Create Monitoring Namespace

We will keep monitoring components separate from the application.

Create:

```powershell
kubectl create namespace monitoring
```

Verify:

```powershell
kubectl get namespaces
```

Expected:

```text
zepto
monitoring
```

Architecture:

```text
GKE
|
+-- namespace: zepto
|      |
|      +-- frontend
|      +-- backend
|      +-- mysql
|
+-- namespace: monitoring
       |
       +-- prometheus
       +-- grafana
       +-- alertmanager
```

---

# 10.5 Add Prometheus Helm Repository

Run:

```powershell
helm repo add prometheus-community `
  https://prometheus-community.github.io/helm-charts
```

Update repositories:

```powershell
helm repo update
```

Verify:

```powershell
helm search repo prometheus-community/kube-prometheus-stack
```

---

# 10.6 Create Monitoring Folder

Add the following structure to your repository:

```text
monitoring/
|
+-- values.yaml
|
+-- servicemonitors/
|   |
|   +-- backend-servicemonitor.yaml
|
+-- prometheus-rules/
|   |
|   +-- zepto-alerts.yaml
|
+-- grafana/
    |
    +-- README.md
```

Your project now becomes:

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
|   +-- workflows/
|       +-- deploy.yml
|
+-- README.md
```

---

# 10.7 Configure Prometheus and Grafana

Create:

```text
monitoring/values.yaml
```

Use:

```yaml
grafana:

  enabled: true

  adminPassword: "ZeptoGrafana@123"

  service:

    type: ClusterIP

  persistence:

    enabled: true

    storageClassName: standard-rwo

    size: 5Gi


prometheus:

  enabled: true

  prometheusSpec:

    retention: 15d

    serviceMonitorSelectorNilUsesHelmValues: false

    podMonitorSelectorNilUsesHelmValues: false

    resources:

      requests:

        cpu: 250m
        memory: 512Mi

      limits:

        cpu: 1000m
        memory: 2Gi


alertmanager:

  enabled: true


kubeStateMetrics:

  enabled: true


nodeExporter:

  enabled: true
```

### Important

The password:

```text
ZeptoGrafana@123
```

is only suitable for training.

Do not commit a production Grafana administrator password into Git.

For production, use Kubernetes Secrets or an external secret-management system.

---

# 10.8 Install kube-prometheus-stack

Run:

```powershell
helm upgrade --install zepto-monitoring `
  prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --values monitoring/values.yaml
```

Helm will install the monitoring stack.

---

# 10.9 Check Helm Release

```powershell
helm list -n monitoring
```

Expected:

```text
NAME               NAMESPACE
zepto-monitoring   monitoring
```

---

# 10.10 Check Monitoring Pods

```powershell
kubectl get pods -n monitoring
```

You should see components similar to:

```text
zepto-monitoring-grafana-xxxxx

zepto-monitoring-kube-state-metrics-xxxxx

zepto-monitoring-kube-prometheus-operator-xxxxx

prometheus-zepto-monitoring-kube-prometheus-prometheus-0

alertmanager-zepto-monitoring-kube-prometheus-alertmanager-0

zepto-monitoring-prometheus-node-exporter-xxxxx
```

All should eventually become:

```text
Running
```

---

# 10.11 Check Monitoring Services

```powershell
kubectl get services -n monitoring
```

Look for Grafana and Prometheus services.

For example:

```text
zepto-monitoring-grafana

zepto-monitoring-kube-prometheus-prometheus
```

---

# 10.12 Access Grafana Securely

For development/training, use port forwarding rather than exposing Grafana publicly.

Run:

```powershell
kubectl port-forward `
  service/zepto-monitoring-grafana `
  3000:80 `
  -n monitoring
```

Keep the terminal running.

Open:

```text
http://localhost:3000
```

Login:

```text
Username: admin
Password: ZeptoGrafana@123
```

---

# 10.13 Get Grafana Password from Kubernetes

If you allow the Helm chart to generate/manage the password instead, retrieve it from the Secret rather than hardcoding it.

For PowerShell:

```powershell
$encoded = kubectl get secret `
  zepto-monitoring-grafana `
  -n monitoring `
  -o jsonpath="{.data.admin-password}"

[System.Text.Encoding]::UTF8.GetString(
    [System.Convert]::FromBase64String($encoded)
)
```

---

# 10.14 Access Prometheus

Open another PowerShell terminal.

Run:

```powershell
kubectl port-forward `
  service/zepto-monitoring-kube-prometheus-prometheus `
  9090:9090 `
  -n monitoring
```

Open:

```text
http://localhost:9090
```

---

# 10.15 Verify Prometheus Targets

In Prometheus go to:

```text
Status
   |
   v
Targets
```

You should find targets for:

```text
Kubernetes API Server

Kubernetes Nodes

kube-state-metrics

node-exporter

Prometheus

Alertmanager
```

The target status should normally be:

```text
UP
```

---

# 10.16 Basic Prometheus Queries

Go to:

```text
Prometheus
   |
   v
Graph
```

Test:

```promql
up
```

This tells you whether monitored targets are available.

---

# 10.17 Monitor Kubernetes Pods

Query:

```promql
kube_pod_info
```

You can filter Zepto:

```promql
kube_pod_info{namespace="zepto"}
```

This should show Zepto Pods.

---

# 10.18 Monitor Pod Status

Run:

```promql
kube_pod_status_phase{namespace="zepto"}
```

For running Pods:

```promql
kube_pod_status_phase{
  namespace="zepto",
  phase="Running"
}
```

---

# 10.19 Monitor Pod Restarts

Use:

```promql
kube_pod_container_status_restarts_total{
  namespace="zepto"
}
```

This is extremely useful for detecting:

```text
CrashLoopBackOff
Application crashes
Container failures
```

---

# 10.20 Monitor Backend Replicas

Query:

```promql
kube_deployment_status_replicas_available{
  namespace="zepto",
  deployment="zepto-backend"
}
```

Expected:

```text
2
```

Desired replicas:

```promql
kube_deployment_spec_replicas{
  namespace="zepto",
  deployment="zepto-backend"
}
```

Expected:

```text
2
```

---

# 10.21 Monitor Frontend Replicas

Available:

```promql
kube_deployment_status_replicas_available{
  namespace="zepto",
  deployment="zepto-frontend"
}
```

Desired:

```promql
kube_deployment_spec_replicas{
  namespace="zepto",
  deployment="zepto-frontend"
}
```

---

# 10.22 Monitor MySQL

Check MySQL Pod:

```promql
kube_pod_info{
  namespace="zepto",
  pod=~"zepto-mysql.*"
}
```

Restart count:

```promql
kube_pod_container_status_restarts_total{
  namespace="zepto",
  pod=~"zepto-mysql.*"
}
```

Later we can add `mysqld_exporter` for actual database metrics such as queries, connections and InnoDB activity.

---

# 10.23 Monitor Pod CPU

A useful query is:

```promql
sum(
  rate(
    container_cpu_usage_seconds_total{
      namespace="zepto",
      container!="",
      image!=""
    }[5m]
  )
) by (pod)
```

This displays CPU usage grouped by Pod.

---

# 10.24 Monitor Pod Memory

Use:

```promql
sum(
  container_memory_working_set_bytes{
    namespace="zepto",
    container!="",
    image!=""
  }
) by (pod)
```

Convert to MB:

```promql
sum(
  container_memory_working_set_bytes{
    namespace="zepto",
    container!="",
    image!=""
  }
) by (pod) / 1024 / 1024
```

---

# 10.25 Monitor Nodes

Node CPU:

```promql
100 -
(
  avg by(instance)
  (
    rate(
      node_cpu_seconds_total{
        mode="idle"
      }[5m]
    )
  ) * 100
)
```

Node memory:

```promql
(
  1 -
  (
    node_memory_MemAvailable_bytes
    /
    node_memory_MemTotal_bytes
  )
) * 100
```

---

# 10.26 Add Prometheus Metrics to Node.js Backend

Kubernetes metrics tell us about infrastructure.

But we also want application metrics:

```text
HTTP requests

Response duration

HTTP status codes

API errors

Node.js process metrics
```

Install the Prometheus client in the backend:

```powershell
cd backend
```

```powershell
npm install prom-client
```

---

# 10.27 Create Backend Metrics Module

Create:

```text
backend/config/metrics.js
```

Add:

```javascript
const client = require("prom-client");

const register = new client.Registry();

client.collectDefaultMetrics({
    register
});

const httpRequestDuration = new client.Histogram({

    name: "zepto_http_request_duration_seconds",

    help: "Duration of HTTP requests in seconds",

    labelNames: [
        "method",
        "route",
        "status_code"
    ],

    buckets: [
        0.05,
        0.1,
        0.25,
        0.5,
        1,
        2,
        5
    ]

});

register.registerMetric(httpRequestDuration);


const httpRequestsTotal = new client.Counter({

    name: "zepto_http_requests_total",

    help: "Total number of HTTP requests",

    labelNames: [
        "method",
        "route",
        "status_code"
    ]

});

register.registerMetric(httpRequestsTotal);


module.exports = {

    register,

    httpRequestDuration,

    httpRequestsTotal

};
```

---

# 10.28 Update backend/app.js

Your application already has Express middleware and `/health`.

Add the metrics functionality without removing your existing health API.

Example final structure:

```javascript
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");

const db = require("./config/db");

const {
    register,
    httpRequestDuration,
    httpRequestsTotal
} = require("./config/metrics");


const app = express();


app.use(cors());

app.use(helmet());

app.use(morgan("dev"));

app.use(express.json());


/*
========================================
PROMETHEUS METRICS MIDDLEWARE
========================================
*/

app.use((req, res, next) => {

    const end = httpRequestDuration.startTimer();

    res.on("finish", () => {

        const route =
            req.route?.path ||
            req.path ||
            "unknown";

        const labels = {

            method: req.method,

            route: route,

            status_code: res.statusCode

        };

        httpRequestsTotal.inc(labels);

        end(labels);

    });

    next();

});


/*
========================================
ROOT API
========================================
*/

app.get("/", (req, res) => {

    res.json({

        message:
            "Zepto Quick Commerce API Running"

    });

});


/*
========================================
HEALTH API
========================================
*/

app.get("/health", async (req, res) => {

    try {

        const [rows] =
            await db.query(
                "SELECT NOW() AS currentTime"
            );

        res.json({

            status: "SUCCESS",

            database: "Connected",

            serverTime:
                rows[0].currentTime

        });

    } catch (error) {

        res.status(500).json({

            status: "FAILED",

            error: error.message

        });

    }

});


/*
========================================
PROMETHEUS METRICS API
========================================
*/

app.get("/metrics", async (req, res) => {

    try {

        res.set(
            "Content-Type",
            register.contentType
        );

        res.end(
            await register.metrics()
        );

    } catch (error) {

        res.status(500).end(
            error.message
        );

    }

});


module.exports = app;
```

---

# 10.29 Test Metrics Locally

Run backend:

```powershell
npm start
```

Open:

```text
http://localhost:5000/metrics
```

You should see Prometheus text-format metrics.

For example:

```text
process_cpu_user_seconds_total

process_resident_memory_bytes

nodejs_heap_size_total_bytes

zepto_http_requests_total

zepto_http_request_duration_seconds
```

---

# 10.30 Update Backend Kubernetes Service

Prometheus `ServiceMonitor` discovers a **Service port by name**, so update:

```text
kubernetes/backend/service.yaml
```

to:

```yaml
apiVersion: v1
kind: Service

metadata:

  name: zepto-backend

  namespace: zepto

  labels:

    app: zepto-backend


spec:

  type: ClusterIP

  selector:

    app: zepto-backend


  ports:

    - name: http

      port: 5000

      targetPort: 5000
```

The important addition is:

```yaml
name: http
```

Apply:

```powershell
kubectl apply -f kubernetes/backend/service.yaml
```

---

# 10.31 Create ServiceMonitor

Create:

```text
monitoring/servicemonitors/backend-servicemonitor.yaml
```

Add:

```yaml
apiVersion: monitoring.coreos.com/v1

kind: ServiceMonitor

metadata:

  name: zepto-backend

  namespace: monitoring

  labels:

    app: zepto-backend


spec:

  namespaceSelector:

    matchNames:

      - zepto


  selector:

    matchLabels:

      app: zepto-backend


  endpoints:

    - port: http

      path: /metrics

      interval: 30s
```

---

# 10.32 Apply ServiceMonitor

```powershell
kubectl apply `
  -f monitoring/servicemonitors/backend-servicemonitor.yaml
```

Verify:

```powershell
kubectl get servicemonitor -n monitoring
```

You should see:

```text
zepto-backend
```

---

# 10.33 Verify Prometheus Backend Target

Go back to Prometheus.

Check:

```text
Status
   |
   v
Targets
```

Look for:

```text
zepto-backend
```

Status should be:

```text
UP
```

---

# 10.34 Query Zepto HTTP Requests

Generate some traffic to the application.

Then run:

```promql
sum(
  rate(
    zepto_http_requests_total[5m]
  )
)
```

By status:

```promql
sum by(status_code) (
  rate(
    zepto_http_requests_total[5m]
  )
)
```

---

# 10.35 Calculate Error Rate

Use:

```promql
sum(
  rate(
    zepto_http_requests_total{
      status_code=~"5.."
    }[5m]
  )
)
```

This tracks backend HTTP 5xx responses.

---

# 10.36 Calculate Request Latency

For the histogram:

```promql
histogram_quantile(
  0.95,
  sum by(le) (
    rate(
      zepto_http_request_duration_seconds_bucket[5m]
    )
  )
)
```

This approximates:

```text
P95 API response latency
```

---

# 10.37 Open Grafana

Start port forwarding if it is not already running:

```powershell
kubectl port-forward `
  service/zepto-monitoring-grafana `
  3000:80 `
  -n monitoring
```

Open Grafana at:

```text
http://localhost:3000
```

---

# 10.38 Verify Prometheus Data Source

With kube-prometheus-stack, Prometheus is normally provisioned automatically.

In Grafana:

```text
Connections
     |
     v
Data Sources
     |
     v
Prometheus
```

Click:

```text
Save & Test
```

Expected:

```text
Successfully queried the Prometheus API
```

---

# 10.39 Existing Kubernetes Dashboards

kube-prometheus-stack provides useful Kubernetes dashboards.

Look under:

```text
Dashboards
   |
   v
Browse
```

You should find dashboards covering areas such as:

```text
Kubernetes / Compute Resources / Cluster

Kubernetes / Compute Resources / Namespace

Kubernetes / Compute Resources / Pod

Kubernetes / Compute Resources / Workload

Node Exporter
```

Use namespace:

```text
zepto
```

to focus on your application.

---

# 10.40 Create Zepto Grafana Dashboard

Create:

```text
Dashboards
   |
   v
New
   |
   v
New Dashboard
```

Name:

```text
Zepto Quick Commerce - Application Monitoring
```

Create panels for:

```text
Backend Requests/sec

Backend P95 Latency

Backend 5xx Errors

Backend Available Replicas

Frontend Available Replicas

Pod CPU

Pod Memory

Pod Restarts

MySQL Pod Status

Node CPU

Node Memory
```

---

# 10.41 Dashboard Panel — Backend Request Rate

PromQL:

```promql
sum(
  rate(
    zepto_http_requests_total[5m]
  )
)
```

Panel:

```text
Zepto Backend - Requests/sec
```

Visualization:

```text
Time series
```

---

# 10.42 Dashboard Panel — Backend P95 Latency

PromQL:

```promql
histogram_quantile(
  0.95,
  sum by(le) (
    rate(
      zepto_http_request_duration_seconds_bucket[5m]
    )
  )
)
```

Panel:

```text
Backend P95 Latency
```

Unit:

```text
seconds
```

---

# 10.43 Dashboard Panel — HTTP 5xx Errors

```promql
sum(
  rate(
    zepto_http_requests_total{
      status_code=~"5.."
    }[5m]
  )
)
```

Panel:

```text
Backend 5xx Error Rate
```

---

# 10.44 Dashboard Panel — Backend Replicas

```promql
kube_deployment_status_replicas_available{
  namespace="zepto",
  deployment="zepto-backend"
}
```

Panel:

```text
Backend Available Replicas
```

Expected:

```text
2
```

---

# 10.45 Dashboard Panel — Frontend Replicas

```promql
kube_deployment_status_replicas_available{
  namespace="zepto",
  deployment="zepto-frontend"
}
```

Expected:

```text
2
```

---

# 10.46 Dashboard Panel — Pod CPU

```promql
sum(
  rate(
    container_cpu_usage_seconds_total{
      namespace="zepto",
      container!="",
      image!=""
    }[5m]
  )
) by (pod)
```

Panel:

```text
Zepto Pod CPU
```

---

# 10.47 Dashboard Panel — Pod Memory

```promql
sum(
  container_memory_working_set_bytes{
    namespace="zepto",
    container!="",
    image!=""
  }
) by (pod)
```

Set unit:

```text
bytes
```

Grafana will display KB/MB/GB automatically.

---

# 10.48 Dashboard Panel — Pod Restarts

```promql
sum by(pod) (
  kube_pod_container_status_restarts_total{
    namespace="zepto"
  }
)
```

Panel:

```text
Zepto Pod Restarts
```

---

# 10.49 Dashboard Panel — MySQL Status

```promql
max(
  kube_pod_status_phase{
    namespace="zepto",
    pod=~"zepto-mysql.*",
    phase="Running"
  }
)
```

Expected healthy value:

```text
1
```

---

# 10.50 Dashboard Layout

A useful dashboard layout is:

```text
+------------------------------------------------+
|       ZEPTO QUICK COMMERCE MONITORING          |
+------------------------------------------------+

+----------------------+-------------------------+
| Backend Requests/sec | Backend P95 Latency     |
+----------------------+-------------------------+

+----------------------+-------------------------+
| Backend 5xx Errors   | Pod Restarts            |
+----------------------+-------------------------+

+----------------------+-------------------------+
| Backend Replicas     | Frontend Replicas       |
+----------------------+-------------------------+

+----------------------+-------------------------+
| Pod CPU              | Pod Memory              |
+----------------------+-------------------------+

+----------------------+-------------------------+
| MySQL Status         | Node CPU                |
+----------------------+-------------------------+

+------------------------------------------------+
|                 Node Memory                    |
+------------------------------------------------+
```

---

# 10.51 Add Prometheus Alerts

Dashboards require someone to look at them.

Alerts automatically notify operators when something is wrong.

Create:

```text
monitoring/prometheus-rules/zepto-alerts.yaml
```

---

# 10.52 Backend Down Alert

```yaml
apiVersion: monitoring.coreos.com/v1

kind: PrometheusRule

metadata:

  name: zepto-alerts

  namespace: monitoring

  labels:

    app: zepto


spec:

  groups:

    - name: zepto.rules

      rules:


        - alert: ZeptoBackendUnavailable

          expr: |
            kube_deployment_status_replicas_available{
              namespace="zepto",
              deployment="zepto-backend"
            } < 1

          for: 2m

          labels:

            severity: critical

          annotations:

            summary: "Zepto backend is unavailable"

            description: "No Zepto backend replicas have been available for more than 2 minutes."
```

---

# 10.53 Frontend Down Alert

Add under the same `rules:` section:

```yaml
        - alert: ZeptoFrontendUnavailable

          expr: |
            kube_deployment_status_replicas_available{
              namespace="zepto",
              deployment="zepto-frontend"
            } < 1

          for: 2m

          labels:

            severity: critical

          annotations:

            summary: "Zepto frontend is unavailable"

            description: "No Zepto frontend replicas have been available for more than 2 minutes."
```

---

# 10.54 High Backend Error Rate Alert

Add:

```yaml
        - alert: ZeptoBackendHigh5xxRate

          expr: |
            sum(
              rate(
                zepto_http_requests_total{
                  status_code=~"5.."
                }[5m]
              )
            ) > 0.1

          for: 5m

          labels:

            severity: warning

          annotations:

            summary: "Zepto backend is returning HTTP 5xx errors"

            description: "The backend 5xx response rate has exceeded the configured threshold."
```

Tune this threshold after you understand normal production traffic.

---

# 10.55 Pod Restart Alert

Add:

```yaml
        - alert: ZeptoPodRestarting

          expr: |
            increase(
              kube_pod_container_status_restarts_total{
                namespace="zepto"
              }[10m]
            ) > 3

          for: 1m

          labels:

            severity: warning

          annotations:

            summary: "Zepto Pod is restarting"

            description: "A Zepto container restarted more than three times during the last 10 minutes."
```

---

# 10.56 Apply Prometheus Rules

Run:

```powershell
kubectl apply `
  -f monitoring/prometheus-rules/zepto-alerts.yaml
```

Verify:

```powershell
kubectl get prometheusrule -n monitoring
```

Expected:

```text
zepto-alerts
```

---

# 10.57 Verify Prometheus Rules

Open Prometheus:

```text
http://localhost:9090
```

Navigate to:

```text
Alerts
```

You should find:

```text
ZeptoBackendUnavailable

ZeptoFrontendUnavailable

ZeptoBackendHigh5xxRate

ZeptoPodRestarting
```

Normally they should show:

```text
Inactive
```

That means the condition is currently false.

---

# 10.58 Test Backend Alert

Scale backend to zero:

```powershell
kubectl scale deployment zepto-backend `
  --replicas=0 `
  -n zepto
```

Check:

```powershell
kubectl get pods -n zepto
```

After the alert's `for:` duration, Prometheus should transition:

```text
Inactive
   |
   v
Pending
   |
   v
Firing
```

---

# 10.59 Restore Backend Immediately After Testing

Run:

```powershell
kubectl scale deployment zepto-backend `
  --replicas=2 `
  -n zepto
```

Verify:

```powershell
kubectl rollout status `
  deployment/zepto-backend `
  -n zepto
```

Then:

```powershell
kubectl get pods -n zepto
```

Expected:

```text
zepto-backend-xxxxx   1/1 Running
zepto-backend-yyyyy   1/1 Running
```

The alert should eventually return to:

```text
Inactive
```

---

# 10.60 Alertmanager

Check:

```powershell
kubectl get pods -n monitoring | Select-String alertmanager
```

Access it:

```powershell
kubectl port-forward `
  service/zepto-monitoring-kube-prometheus-alertmanager `
  9093:9093 `
  -n monitoring
```

Then open:

```text
http://localhost:9093
```

Alertmanager can later route alerts to:

```text
Email

Slack

PagerDuty

Microsoft Teams via supported integrations/webhooks

Other webhook receivers
```

Do not commit notification credentials into Git.

---

# 10.61 Optional — Monitor MySQL Internals

At this point Prometheus can monitor the MySQL Pod from Kubernetes' perspective.

That tells us:

```text
MySQL Pod Running?

CPU?

Memory?

Restart count?
```

But it does not give detailed MySQL metrics such as:

```text
Connections

Queries/sec

Slow queries

InnoDB metrics

Threads

Table locks
```

For these, add a MySQL exporter in a later enhancement.

Architecture:

```text
MySQL
   |
   v
MySQL Exporter
   |
   | /metrics
   v
Prometheus
   |
   v
Grafana
```

---

# 10.62 Rebuild Backend Image

Because we added:

```text
prom-client
```

and:

```text
/metrics
```

the backend Docker image must be rebuilt.

With your CI/CD pipeline, simply commit the changes.

Check:

```powershell
git status
```

You should see changes including:

```text
backend/package.json

backend/package-lock.json

backend/app.js

backend/config/metrics.js

kubernetes/backend/service.yaml

monitoring/
```

---

# 10.63 Commit Monitoring Changes

Create a feature branch:

```powershell
git checkout -b feature/prometheus-grafana-monitoring
```

Add files:

```powershell
git add backend/
```

```powershell
git add kubernetes/backend/service.yaml
```

```powershell
git add monitoring/
```

Commit:

```powershell
git commit -m "Add Prometheus and Grafana monitoring"
```

Push:

```powershell
git push origin feature/prometheus-grafana-monitoring
```

Create your pull request and merge according to your repository workflow.

---

# 10.64 Let CI/CD Deploy the New Backend

After merging/pushing to the deployment branch:

```text
Git Push
   |
   v
GitHub Actions
   |
   +-- Test
   |
   +-- Build Backend
   |
   +-- Build Frontend
   |
   +-- Push Images
   |
   v
Artifact Registry
   |
   v
GKE Rolling Update
```

The new backend will now expose:

```text
/health

/metrics
```

---

# 10.65 Verify Metrics Inside Kubernetes

Do not expose `/metrics` publicly just to test it.

Use:

```powershell
kubectl run prometheus-test `
  --image=curlimages/curl `
  --rm -it `
  --restart=Never `
  -n zepto `
  -- curl http://zepto-backend:5000/metrics
```

You should see metrics such as:

```text
zepto_http_requests_total

zepto_http_request_duration_seconds
```

---

# 10.66 Important Security Issue — Do Not Expose `/metrics` Through Ingress

Our backend service is internal:

```text
ClusterIP
```

Prometheus accesses it inside GKE.

Ideally:

```text
Prometheus
    |
    | internal Kubernetes network
    v
zepto-backend:5000/metrics
```

Avoid deliberately exposing application metrics to the public Internet.

For a hardened production setup, use separate metrics exposure/network policy or other access controls as appropriate.

---

# 10.67 Monitoring Troubleshooting — ServiceMonitor Not Found

Run:

```powershell
kubectl get servicemonitor -n monitoring
```

If Kubernetes says:

```text
the server doesn't have a resource type "servicemonitor"
```

the Prometheus Operator CRDs are not installed.

Check:

```powershell
kubectl get crd | Select-String monitoring.coreos.com
```

You should see resources including:

```text
servicemonitors.monitoring.coreos.com

prometheusrules.monitoring.coreos.com
```

---

# 10.68 Troubleshooting — Backend Target Is DOWN

Check the ServiceMonitor:

```powershell
kubectl describe servicemonitor zepto-backend `
  -n monitoring
```

Check backend Service:

```powershell
kubectl get service zepto-backend `
  -n zepto `
  --show-labels
```

You need:

```text
app=zepto-backend
```

Check the service port:

```powershell
kubectl get service zepto-backend `
  -n zepto `
  -o yaml
```

It must contain:

```yaml
ports:

  - name: http

    port: 5000

    targetPort: 5000
```

The ServiceMonitor must contain:

```yaml
endpoints:

  - port: http
```

The names must match.

---

# 10.69 Troubleshooting — `/metrics` Returns 404

Test:

```powershell
kubectl port-forward `
  service/zepto-backend `
  5000:5000 `
  -n zepto
```

Open:

```text
http://localhost:5000/metrics
```

If:

```text
404 Not Found
```

verify that `app.js` contains:

```javascript
app.get("/metrics", async (req, res) => {

    res.set(
        "Content-Type",
        register.contentType
    );

    res.end(
        await register.metrics()
    );

});
```

Also verify the new backend image was actually deployed.

---

# 10.70 Troubleshooting — Grafana Cannot See Metrics

First check Prometheus.

Run:

```promql
up
```

Then:

```promql
zepto_http_requests_total
```

If Prometheus itself cannot see the metric, Grafana cannot see it either.

Troubleshoot in this order:

```text
Node.js /metrics
       |
       v
Backend Service
       |
       v
ServiceMonitor
       |
       v
Prometheus Target
       |
       v
Prometheus Query
       |
       v
Grafana Data Source
       |
       v
Grafana Panel
```

---

# 10.71 Troubleshooting — Grafana PVC Pending

Check:

```powershell
kubectl get pvc -n monitoring
```

If:

```text
Pending
```

check:

```powershell
kubectl describe pvc PVC_NAME -n monitoring
```

Then:

```powershell
kubectl get storageclass
```

Verify:

```text
standard-rwo
```

exists.

---

# 10.72 Monitoring Resource Usage

Monitoring itself consumes cluster resources.

Check:

```powershell
kubectl top pods -n monitoring
```

And:

```powershell
kubectl top nodes
```

A small training GKE cluster may need more CPU/RAM after installing the full monitoring stack.

If monitoring Pods remain `Pending`, inspect:

```powershell
kubectl describe pod POD_NAME -n monitoring
```

Look for:

```text
Insufficient cpu

Insufficient memory
```

---

# 10.73 Verify Complete Monitoring System

Run:

```powershell
kubectl get pods -n zepto
```

Then:

```powershell
kubectl get pods -n monitoring
```

Then:

```powershell
kubectl get servicemonitor -n monitoring
```

Then:

```powershell
kubectl get prometheusrule -n monitoring
```

Then:

```powershell
kubectl get pvc -n monitoring
```

---

# 10.74 Final Success Checklist

Part 10 is successful when:

```text
[✓] monitoring namespace exists

[✓] kube-prometheus-stack installed

[✓] Prometheus running

[✓] Grafana running

[✓] Alertmanager running

[✓] kube-state-metrics running

[✓] node-exporter running

[✓] Prometheus targets UP

[✓] GKE nodes visible

[✓] Zepto Pods visible

[✓] CPU metrics visible

[✓] Memory metrics visible

[✓] Pod restart metrics visible

[✓] Backend /metrics endpoint working

[✓] prom-client installed

[✓] Backend Service has named http port

[✓] ServiceMonitor created

[✓] Prometheus discovers Zepto backend

[✓] zepto_http_requests_total available

[✓] HTTP latency metrics available

[✓] Grafana Prometheus data source working

[✓] Zepto Grafana dashboard created

[✓] Backend replica panel working

[✓] Frontend replica panel working

[✓] CPU panel working

[✓] Memory panel working

[✓] Pod restart panel working

[✓] PrometheusRule created

[✓] Alerts visible in Prometheus

[✓] Alertmanager running
```

---

# 10.75 Complete DevOps Architecture After Part 10

```text
                              DEVELOPER
                                  |
                                  | git push
                                  v
                              GitHub
                                  |
                                  v
                           GitHub Actions
                                  |
                    +-------------+-------------+
                    |                           |
                    v                           v
                  Test                       Build
                                                |
                                                v
                                      Artifact Registry
                                                |
                                                v
                                               GKE
                                                |
                     +--------------------------+-------------------------+
                     |                          |                         |
                     v                          v                         v
              React Frontend             Node.js Backend               MySQL
                                                |
                                                |
                                                | /metrics
                                                v
                                           Prometheus
                                                |
                         +----------------------+----------------+
                         |                                       |
                         v                                       v
                      Grafana                               Alertmanager
                         |                                       |
                         v                                       v
                    Dashboards                                  Alerts
```

Your Zepto project has now progressed through:

```text
Part 1  -> Architecture & GitHub Repository

Part 2  -> React Frontend

Part 3  -> Node.js Backend APIs

Part 4  -> MySQL Schema & Seed Data

Part 5  -> Dockerization

Part 6  -> GKE Cluster

Part 7  -> Kubernetes Manifests

Part 8  -> GitHub Actions CI/CD

Part 9  -> End-to-End CI/CD Testing

Part 10 -> Prometheus + Grafana Monitoring
```

The logical **Part 11** after this is **centralized logging and observability**: collect React/Ingress/Node.js/MySQL/Kubernetes logs, correlate them with Prometheus metrics, configure GKE/Google Cloud logging, build log-based dashboards/alerts, and establish an end-to-end troubleshooting workflow from **Grafana alert → Prometheus metric → Kubernetes Pod → application logs → root cause**.
