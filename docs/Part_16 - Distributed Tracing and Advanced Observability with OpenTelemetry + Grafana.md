# Part 16 — Distributed Tracing and Advanced Observability with OpenTelemetry + Grafana

At the end of Part 15, Zepto has:

```text
Part 10 → Prometheus + Grafana
Part 11 → Centralized Logging
Part 12 → Security Hardening
Part 13 → HA / Scaling / Backup / DR
Part 14 → GitOps + Argo CD
Part 15 → Canary / Blue-Green / Argo Rollouts
```

Now we add **distributed tracing**.

The goal is to answer questions such as:

> "A customer clicked **Place Order**. Why did the request take 2.8 seconds?"

Instead of looking at individual logs, we can see the entire request:

```text
React
  |
  | trace
  v
Node.js API
  |
  +---- Product Service
  |
  +---- MySQL
  |
  +---- External Payment API
```

and identify exactly where the time was spent.

---

# 16.1 What Is Distributed Tracing?

Metrics tell us:

```text
P95 latency = 850 ms
```

Logs tell us:

```text
Order creation started
Database query failed
```

A trace tells us:

```text
POST /api/orders
|
+-- Node.js API              850 ms
|
+-- Validate order            20 ms
|
+-- Check inventory            80 ms
|
+-- MySQL query               650 ms
|
+-- Payment API                90 ms
```

Now we immediately know:

```text
MySQL = 650 ms
```

is the bottleneck.

---

# 16.2 Three Pillars of Observability

Zepto now has:

```text
             OBSERVABILITY
                   |
       +-----------+-----------+
       |           |           |
       v           v           v
    Metrics       Logs       Traces
       |           |           |
       v           v           v
 Prometheus    Logging     OpenTelemetry
       |                       |
       v                       v
    Grafana                 Tempo
```

### Metrics

Answer:

> What is happening?

Example:

```text
CPU = 72%
HTTP 5xx = 0.4%
P95 = 420ms
```

### Logs

Answer:

> What happened?

Example:

```text
Order 123 failed
Database timeout
```

### Traces

Answer:

> Where did the request spend its time?

Example:

```text
API
 |
 +-- MySQL = 650ms
```

---

# 16.3 Recommended Architecture

For the Zepto GKE environment, we will use:

```text
OpenTelemetry
      |
      v
OpenTelemetry Collector
      |
      v
Grafana Tempo
      |
      v
Grafana
```

So:

```text
React
   |
   v
Node.js
   |
   v
OpenTelemetry SDK
   |
   v
OTel Collector
   |
   v
Tempo
   |
   v
Grafana
```

OpenTelemetry provides vendor-neutral instrumentation and telemetry collection. The Collector receives, processes and exports telemetry to observability backends.

---

# 16.4 Why Tempo?

For this project, we'll use **Grafana Tempo** as the tracing backend.

Architecture:

```text
Node.js
   |
   | OTLP
   v
OTel Collector
   |
   | OTLP
   v
Tempo
   |
   v
Grafana
```

Tempo stores traces.

Grafana visualizes them.

---

# 16.5 Trace Example

Imagine this request:

```text
POST /api/orders
```

Trace:

```text
Trace ID:
4bf92f3577b34da6a3ce929d0e0e4736
```

Spans:

```text
POST /api/orders
|
+-- authenticateUser
|      12ms
|
+-- validateCart
|      25ms
|
+-- checkInventory
|      85ms
|
+-- mysql.query
|      430ms
|
+-- payment
|      120ms
|
+-- createOrder
       50ms
```

Total:

```text
722ms
```

---

# 16.6 Trace vs Span

A **trace** represents the complete request.

A **span** represents one operation within that request.

```text
TRACE
|
+-- Span: HTTP request
|
+-- Span: DB query
|
+-- Span: inventory
|
+-- Span: payment
```

Every span has information such as:

```text
Name
Start time
Duration
Status
Attributes
Trace ID
Span ID
Parent Span ID
```

---

# 16.7 Parent/Child Relationship

Example:

```text
Trace
|
+-- HTTP POST /orders
     |
     +-- validateCart
     |
     +-- mysql.query
     |
     +-- payment
```

The database span is a child of the API span.

This creates the request tree.

---

# 16.8 Trace Context

The trace context must travel between services.

For example:

```text
React
 |
 | traceparent
 v
Node.js
 |
 | traceparent
 v
Payment Service
```

This allows multiple services to appear in the same trace.

---

# 16.9 OpenTelemetry Components

We will use:

```text
OpenTelemetry SDK
        |
        v
Instrumentation
        |
        v
OTLP
        |
        v
OpenTelemetry Collector
        |
        v
Tempo
        |
        v
Grafana
```

---

# 16.10 Zepto Architecture After Part 16

```text
                         USERS
                           |
                           v
                    React Frontend
                           |
                           v
                    Node.js Backend
                           |
             +-------------+-------------+
             |             |             |
             v             v             v
           MySQL       Payment API   Other APIs
             |
             |
      OpenTelemetry SDK
             |
             v
      OTel Collector
             |
             v
           Tempo
             |
             v
          Grafana
             |
       +-----+-----+
       |           |
       v           v
   Metrics       Traces
 Prometheus       Tempo
       |           |
       +-----+-----+
             |
             v
          Grafana
```

---

# 16.11 Create Observability Namespace

You can keep observability components in:

```text
observability
```

Create:

```powershell
kubectl create namespace observability
```

Verify:

```powershell
kubectl get namespace observability
```

---

# 16.12 Install Tempo

For a production-style setup, deploy Tempo using the current supported Grafana Helm chart/configuration.

Create:

```text
monitoring/tempo/
```

Structure:

```text
monitoring/
|
+-- tempo/
|   |
|   +-- values.yaml
|
+-- otel/
|   |
|   +-- collector-values.yaml
```

---

# 16.13 Tempo Configuration

For a learning environment, start with a simple deployment.

Example conceptual Helm values:

```yaml
tempo:
  reportingEnabled: false

persistence:
  enabled: true
```

For production, use durable object storage rather than relying on ephemeral Pod storage.

A production architecture should be:

```text
Tempo
 |
 v
Object Storage
 |
 +-- Trace blocks
 +-- Long-term retention
```

---

# 16.14 Why Object Storage?

Tracing data can become large.

Suppose:

```text
1000 requests/sec
```

and each request generates multiple spans.

Trace volume grows quickly.

Therefore:

```text
Pod local disk
```

is not an appropriate long-term storage strategy.

Use durable object storage.

---

# 16.15 Tempo Production Architecture

```text
                  Tempo
                    |
                    v
              Object Storage
                    |
       +------------+------------+
       |            |            |
       v            v            v
    Trace A      Trace B      Trace C
```

Retention can then be configured according to your observability requirements and cost constraints.

---

# 16.16 Install OpenTelemetry Collector

The Collector will receive OTLP telemetry from Node.js.

Architecture:

```text
Node.js
 |
 | OTLP
 v
OTel Collector
 |
 | OTLP
 v
Tempo
```

You can deploy the OpenTelemetry Collector using the official OpenTelemetry Helm chart/configuration.

---

# 16.17 Collector Configuration

Create:

```text
monitoring/otel/collector-values.yaml
```

Conceptually:

```yaml
mode: deployment

config:
  receivers:

    otlp:

      protocols:

        grpc:
          endpoint: 0.0.0.0:4317

        http:
          endpoint: 0.0.0.0:4318


  processors:

    batch:


  exporters:

    otlp:

      endpoint: tempo.observability.svc.cluster.local:4317

      tls:

        insecure: true


  service:

    pipelines:

      traces:

        receivers:
          - otlp

        processors:
          - batch

        exporters:
          - otlp
```

For production, configure authentication/TLS according to the actual deployment architecture.

---

# 16.18 Collector Ports

Common OTLP ports:

```text
4317 → OTLP gRPC

4318 → OTLP HTTP
```

Therefore:

```text
Node.js
 |
 | 4318
 v
OTel Collector
 |
 | 4317
 v
Tempo
```

---

# 16.19 Install Collector

Use Helm according to the current OpenTelemetry Collector chart instructions.

Then:

```powershell
kubectl get pods -n observability
```

You should eventually see:

```text
tempo
otel-collector
```

---

# 16.20 Verify Collector

```powershell
kubectl get svc -n observability
```

You should have a Collector service exposing the configured OTLP ports.

---

# 16.21 Node.js OpenTelemetry

Now we instrument your existing backend.

Go to:

```text
backend/
```

Install OpenTelemetry packages.

For a modern Node.js application, use the OpenTelemetry Node SDK and the appropriate instrumentation packages.

For example:

```powershell
npm install \
  @opentelemetry/sdk-node \
  @opentelemetry/api \
  @opentelemetry/exporter-trace-otlp-http \
  @opentelemetry/instrumentation \
  @opentelemetry/instrumentation-http \
  @opentelemetry/instrumentation-express \
  @opentelemetry/instrumentation-mysql2
```

Package names and compatibility should be checked against the OpenTelemetry Node.js documentation before pinning versions.

---

# 16.22 Important: Instrumentation Must Start First

OpenTelemetry initialization should happen before importing the application modules that need instrumentation.

Create:

```text
backend/tracing.js
```

Example:

```javascript
"use strict";

const {
    NodeSDK
} = require("@opentelemetry/sdk-node");

const {
    OTLPTraceExporter
} = require(
    "@opentelemetry/exporter-trace-otlp-http"
);

const {
    getNodeAutoInstrumentations
} = require(
    "@opentelemetry/auto-instrumentations-node"
);


const exporter =
    new OTLPTraceExporter({
        url:
            process.env.OTEL_EXPORTER_OTLP_ENDPOINT ||
            "http://otel-collector.observability.svc.cluster.local:4318/v1/traces"
    });


const sdk = new NodeSDK({

    traceExporter: exporter,

    instrumentations: [
        getNodeAutoInstrumentations()
    ]

});


sdk.start();


process.on(
    "SIGTERM",
    () => {

        sdk.shutdown()
            .then(() => {

                console.log(
                    "OpenTelemetry shut down"
                );

            })
            .catch((error) => {

                console.error(
                    "OpenTelemetry shutdown error",
                    error
                );

            });

    }
);
```

You'll need:

```powershell
npm install @opentelemetry/auto-instrumentations-node
```

---

# 16.23 Update `package.json`

Your backend startup should load tracing before the application.

For example:

```json
{
  "scripts": {
    "start": "node -r ./tracing.js server.js"
  }
}
```

If your project starts through another file, use that actual entry point.

For example, if your entry point is:

```text
backend/server.js
```

then:

```json
"start": "node -r ./tracing.js server.js"
```

---

# 16.24 Alternative Node.js Startup

You can also use:

```powershell
node -r ./tracing.js server.js
```

This loads:

```text
tracing.js
```

before:

```text
server.js
```

which allows auto-instrumentation to hook into supported libraries.

---

# 16.25 Recommended Environment Variables

In Kubernetes:

```yaml
env:

  - name: OTEL_SERVICE_NAME

    value: zepto-backend

  - name: OTEL_EXPORTER_OTLP_ENDPOINT

    value: http://otel-collector.observability.svc.cluster.local:4318

  - name: OTEL_EXPORTER_OTLP_PROTOCOL

    value: http/protobuf
```

---

# 16.26 Service Naming

This is very important.

Use stable service names:

```text
zepto-frontend
zepto-backend
zepto-mysql
zepto-payment
```

Do not use:

```text
zepto-backend-pod-784bdf8d9c-xk2df
```

as your service name.

The Pod changes.

The logical service does not.

---

# 16.27 Resource Attributes

Useful attributes include:

```text
service.name
service.version
deployment.environment
k8s.namespace.name
k8s.pod.name
k8s.node.name
```

For example:

```text
service.name = zepto-backend

service.version = a83f921

deployment.environment = production
```

---

# 16.28 Configure Environment

In your production overlay:

```yaml
env:

  - name: OTEL_SERVICE_NAME

    value: zepto-backend

  - name: OTEL_RESOURCE_ATTRIBUTES

    value: deployment.environment=production
```

Staging:

```yaml
env:

  - name: OTEL_SERVICE_NAME

    value: zepto-backend

  - name: OTEL_RESOURCE_ATTRIBUTES

    value: deployment.environment=staging
```

Development:

```yaml
env:

  - name: OTEL_SERVICE_NAME

    value: zepto-backend

  - name: OTEL_RESOURCE_ATTRIBUTES

    value: deployment.environment=dev
```

---

# 16.29 Automatic HTTP Tracing

With Node.js auto-instrumentation, HTTP requests can produce spans such as:

```text
HTTP GET /api/products
```

Example:

```text
Trace
|
+-- HTTP GET /api/products
      |
      +-- express middleware
      |
      +-- mysql query
```

---

# 16.30 Express Tracing

Express instrumentation can capture:

```text
GET /api/products
POST /api/orders
GET /api/cart
```

Example:

```text
HTTP POST /api/orders
|
+-- express
|
+-- controller
|
+-- mysql
```

---

# 16.31 MySQL Tracing

MySQL instrumentation can create database spans.

Example:

```text
POST /api/orders
|
+-- mysql.query
      |
      +-- SELECT products
      |
      +-- INSERT order
      |
      +-- UPDATE inventory
```

This is extremely useful for finding slow SQL operations.

---

# 16.32 Manual Spans

Automatic instrumentation is useful, but business logic often needs manual spans.

Suppose you have:

```text
backend/controllers/orderController.js
```

You can create:

```javascript
const {
    trace
} = require("@opentelemetry/api");


const tracer =
    trace.getTracer("zepto-backend");


async function createOrder(req, res) {

    return tracer.startActiveSpan(
        "create-order",
        async (span) => {

            try {

                span.setAttribute(
                    "order.items",
                    req.body.items?.length || 0
                );

                // Business logic here

                res.json({
                    message: "Order created"
                });

            } catch (error) {

                span.recordException(error);

                span.setStatus({
                    code: 2,
                    message: error.message
                });

                throw error;

            } finally {

                span.end();

            }

        }
    );

}
```

---

# 16.33 Don't Put Sensitive Data in Spans

Do **not** add:

```text
password
JWT
credit card
payment secret
DB password
```

as span attributes.

Also avoid putting full customer information into telemetry.

Instead:

```text
order.id = 12345
```

may be acceptable depending on your data policy, while:

```text
customer.password
```

is not.

---

# 16.34 Correlation ID

Distributed tracing gives us:

```text
Trace ID
```

For example:

```text
4bf92f3577b34da6a3ce929d0e0e4736
```

We want the same ID in:

```text
Logs
Metrics context
Traces
```

Then:

```text
Grafana
  |
  v
Trace ID
  |
  +---- Logs
  |
  +---- Metrics
```

---

# 16.35 Add Trace ID to Logs

In Node.js, retrieve the active span:

```javascript
const {
    trace
} = require("@opentelemetry/api");


const span =
    trace.getActiveSpan();


const spanContext =
    span?.spanContext();


console.log(
    JSON.stringify({
        message: "Creating order",
        traceId:
            spanContext?.traceId,
        spanId:
            spanContext?.spanId
    })
);
```

Now logs can contain:

```json
{
  "message": "Creating order",
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
  "spanId": "00f067aa0ba902b7"
}
```

---

# 16.36 Why JSON Logging?

You previously implemented centralized logging.

Instead of:

```text
Creating order
```

use:

```json
{
  "level": "info",
  "message": "Creating order",
  "traceId": "4bf92f...",
  "spanId": "00f067..."
}
```

Now Cloud Logging/Grafana can search the trace ID.

---

# 16.37 Frontend Tracing

Now we trace:

```text
React
 |
 v
Node.js
 |
 v
MySQL
```

Install OpenTelemetry browser packages appropriate for the current OpenTelemetry Web SDK.

The frontend can generate a trace for:

```text
GET /products
POST /cart
POST /orders
```

and propagate the trace context to the backend.

---

# 16.38 Browser Tracing Architecture

```text
React
 |
 | Trace ID
 v
Node.js
 |
 | Same Trace ID
 v
MySQL
```

Without propagation:

```text
React Trace A

Node.js Trace B
```

With propagation:

```text
Trace A
 |
 +-- React
 |
 +-- Node.js
 |
 +-- MySQL
```

---

# 16.39 CORS Consideration

When browser tracing sends trace context to another origin, your backend must permit the relevant trace headers.

The important propagation header is typically:

```text
traceparent
```

Your CORS configuration should allow the necessary headers.

For example:

```javascript
app.use(cors({
    origin: process.env.FRONTEND_URL,
    allowedHeaders: [
        "Content-Type",
        "Authorization",
        "traceparent",
        "tracestate"
    ]
}));
```

Adjust this to your actual frontend/API architecture.

---

# 16.40 Don't Use `*` in Production CORS

Avoid:

```javascript
origin: "*"
```

for production if your application uses authenticated requests.

Prefer:

```text
https://www.zepto.example.com
```

or your actual production domain.

---

# 16.41 Trace Sampling

Tracing every request can become expensive.

Suppose:

```text
1000 requests/sec
```

You might not want:

```text
1000 traces/sec
```

stored forever.

Sampling can help.

Example:

```text
100%
Development

25%
Staging

5-10%
Production
```

But always sample intelligently; retain error traces and important business transactions.

---

# 16.42 Head vs Tail Sampling

### Head Sampling

Decision is made at the beginning.

```text
Request
 |
 +-- sampled → trace
 |
 +-- not sampled → discard
```

### Tail Sampling

Collector waits to see the trace and decides later.

For example:

```text
Successful fast request
→ discard

500 error
→ keep

Slow request
→ keep
```

For production observability, tail sampling can be very useful.

---

# 16.43 Tail Sampling Architecture

```text
Applications
     |
     v
OTel Collector
     |
     v
Tail Sampling
   /      \
Keep     Drop
 |         |
 v         v
Tempo    discard
```

For example:

```text
Keep if:

status = ERROR
OR
duration > 1 second
OR
important business transaction
```

---

# 16.44 Collector Processor

A production collector can include processors such as:

```text
batch
memory_limiter
attributes
resource
tail_sampling
```

Conceptually:

```yaml
processors:

  memory_limiter:

    check_interval: 1s

    limit_percentage: 75

    spike_limit_percentage: 15


  batch:

    timeout: 5s
```

Exact configuration should be tuned to the Collector deployment and version.

---

# 16.45 Resource Protection

Observability itself must not take down the application.

Therefore:

```text
Application
 |
 v
Collector
 |
 +-- Memory limit
 +-- CPU limit
 +-- Batch
 +-- Retry
```

The Collector needs resource requests/limits and appropriate scaling.

---

# 16.46 Collector High Availability

For production:

```text
                    OTel
                      |
          +-----------+-----------+
          |                       |
          v                       v
      Collector 1            Collector 2
          |                       |
          +-----------+-----------+
                      |
                      v
                    Tempo
```

Do not rely on a single Collector Pod for production telemetry.

---

# 16.47 Collector HPA

You can scale Collector Pods based on:

```text
CPU
Memory
Telemetry throughput
```

For example:

```yaml
minReplicas: 2
maxReplicas: 5
```

depending on workload.

---

# 16.48 Tempo High Availability

Production architecture:

```text
                 OTel Collectors
                       |
                       v
               +-------+-------+
               |               |
               v               v
           Tempo Query     Tempo Distributor
                               |
                       +-------+-------+
                       |               |
                       v               v
                  Tempo Ingester   Tempo Ingester
                       |
                       v
                  Object Storage
```

For a learning cluster, use a simpler topology.

For production, use the supported scalable Tempo architecture.

---

# 16.49 Grafana Data Sources

Grafana should now have:

```text
Prometheus
Tempo
Loki / Cloud Logging
```

Conceptually:

```text
Grafana
 |
 +-- Prometheus
 |
 +-- Tempo
 |
 +-- Logs
```

---

# 16.50 Add Tempo Data Source

In Grafana:

```text
Connections
   |
   v
Data Sources
   |
   v
Add data source
   |
   v
Tempo
```

Use the internal Tempo service address.

For example:

```text
http://tempo.observability.svc.cluster.local:3200
```

The exact service name depends on your Helm installation.

---

# 16.51 Test Tempo

In Grafana:

```text
Explore
 |
 v
Tempo
```

Search for:

```text
Service:
zepto-backend
```

You should eventually see:

```text
GET /api/products
POST /api/orders
GET /api/categories
```

---

# 16.52 First End-to-End Trace

Open the Zepto frontend.

Perform:

```text
Login
 |
 v
Products
 |
 v
Add to Cart
 |
 v
Checkout
 |
 v
Place Order
```

Then go to Grafana → Tempo.

Search:

```text
Service = zepto-backend
```

Open the trace.

Expected:

```text
POST /api/orders
|
+-- express
|
+-- createOrder
|
+-- mysql.query
|
+-- inventory
|
+-- payment
```

---

# 16.53 Trace Waterfall

Grafana will show something conceptually like:

```text
0ms                                             1000ms

POST /api/orders
|-----------------------------------------------|

  validate
  |----|

  inventory
      |----------|

  mysql
           |-----------------------------|

  payment
                                    |------|
```

This is called a:

```text
Trace Waterfall
```

---

# 16.54 Finding a Slow Query

Suppose:

```text
POST /api/orders = 2.3 sec
```

Trace:

```text
POST /api/orders
|
+-- validation        20ms
|
+-- inventory         100ms
|
+-- MySQL             2,000ms
|
+-- payment           120ms
```

Immediately:

```text
MySQL
  |
  v
2 seconds
```

is the likely bottleneck.

---

# 16.55 Trace-to-Logs

Now click the trace/span.

Use:

```text
Trace ID
```

to find logs.

Example:

```text
Trace ID:
4bf92f3577b34da6a3ce929d0e0e4736
```

Search logs for:

```text
traceId="4bf92f3577b34da6a3ce929d0e0e4736"
```

Now you can see:

```text
Trace
 |
 +-- Span
 |
 +-- Log
```

---

# 16.56 Trace-to-Metrics

Suppose Grafana shows:

```text
P95 latency = 1.2 sec
```

Click into a trace.

You find:

```text
MySQL = 900ms
```

Then investigate Prometheus:

```promql
rate(mysql_queries_total[5m])
```

and:

```promql
mysql_query_duration_seconds
```

Now:

```text
Metrics
   |
   v
Problem detected
   |
   v
Trace
   |
   v
Slow operation
   |
   v
Logs
   |
   v
Root cause
```

This is advanced observability.

---

# 16.57 RED Method

For services, monitor:

```text
R = Rate
E = Errors
D = Duration
```

For Zepto backend:

```text
Rate:
requests/sec

Errors:
5xx/sec

Duration:
P95/P99
```

Grafana:

```text
+--------------------------------------+
| Zepto Backend RED Dashboard          |
+--------------------------------------+
| Request Rate     | 120 req/sec       |
| Error Rate       | 0.05%             |
| P95              | 220ms             |
| P99              | 480ms             |
+--------------------------------------+
```

---

# 16.58 USE Method

For infrastructure:

```text
U = Utilization
S = Saturation
E = Errors
```

Example:

```text
Node CPU utilization
Node memory utilization
Disk saturation
Network errors
```

Combine:

```text
RED → Application
USE → Infrastructure
```

---

# 16.59 Service Dependency Map

As your architecture grows:

```text
React
 |
 v
Backend
 |
 +---- MySQL
 |
 +---- Payment
 |
 +---- Inventory
 |
 +---- Notification
```

Tracing can show service dependencies.

This becomes extremely useful when the application becomes microservice-oriented.

---

# 16.60 Example Dependency Problem

Grafana shows:

```text
Node.js
 |
 +---- Inventory API
 |
 |      1.8 sec
 |
 +---- MySQL
        100ms
```

You immediately know:

```text
Inventory API
```

is causing latency.

Without tracing, you might waste time tuning MySQL.

---

# 16.61 Add Trace IDs to Node.js Logs

Your existing `morgan` middleware:

```javascript
app.use(morgan("dev"));
```

is useful for local development but not ideal as the sole production logging mechanism.

Use structured logs in production.

Example helper:

```javascript
const {
    trace
} = require("@opentelemetry/api");


function log(
    level,
    message,
    metadata = {}
) {

    const activeSpan =
        trace.getActiveSpan();

    const context =
        activeSpan?.spanContext();

    console.log(
        JSON.stringify({
            timestamp:
                new Date().toISOString(),

            level,

            message,

            traceId:
                context?.traceId || null,

            spanId:
                context?.spanId || null,

            ...metadata
        })
    );

}
```

Use:

```javascript
log(
    "info",
    "Order created",
    {
        orderId: order.id
    }
);
```

---

# 16.62 Error Logging

```javascript
try {

    // operation

} catch (error) {

    const activeSpan =
        trace.getActiveSpan();

    activeSpan?.recordException(error);

    activeSpan?.setStatus({
        code: 2,
        message: error.message
    });

    log(
        "error",
        "Order creation failed",
        {
            error:
                error.message
        }
    );

    throw error;
}
```

Now the same failure appears in:

```text
Trace
+
Logs
```

---

# 16.63 Avoid Sensitive Trace Attributes

Never add:

```text
password
authorization token
credit card
CVV
database password
secret
```

Avoid excessive:

```text
customer email
phone
address
```

Use:

```text
orderId
productId
request type
```

where appropriate.

---

# 16.64 Kubernetes Resource Attributes

With Kubernetes metadata enrichment, traces can contain:

```text
k8s.namespace.name
k8s.pod.name
k8s.node.name
k8s.deployment.name
```

Then you can answer:

> Which Pod handled the slow request?

Example:

```text
Pod:
zepto-backend-74dbf5c9f6-x7m9k
```

Then:

```powershell
kubectl logs zepto-backend-74dbf5c9f6-x7m9k -n zepto
```

---

# 16.65 Connect Tracing to Part 15

This is particularly powerful for Canary deployments.

You already have:

```text
Stable
Canary
```

Now monitor:

```text
Stable P95:
220ms

Canary P95:
650ms
```

Argo Rollouts:

```text
Canary SLO FAILED
```

Then:

```text
Automatic rollback
```

Architecture:

```text
Canary
  |
  v
OpenTelemetry
  |
  v
Tempo
  |
  v
Prometheus / metrics
  |
  v
Argo Rollouts
  |
  v
Rollback
```

---

# 16.66 Canary + Trace-Based Troubleshooting

Suppose:

```text
Canary:
5% traffic
```

Prometheus reports:

```text
P95:
800ms
```

Open Tempo.

Trace:

```text
POST /api/orders
|
+-- MySQL = 100ms
|
+-- Payment = 650ms
```

Now you know:

```text
Payment integration
```

is causing the regression.

---

# 16.67 Release Decision

```text
Canary v1.7
     |
     v
P95 increased
     |
     v
Trace investigation
     |
     v
Payment API latency
     |
     v
Release Analysis
     |
     v
FAIL
     |
     v
Automatic Rollback
```

This is a powerful combination of Parts 10, 14, 15 and 16.

---

# 16.68 Production Sampling Strategy

A reasonable starting strategy:

```text
Development
100%

Staging
25%

Production
5-10%
```

But retain:

```text
100% errors
100% critical checkout traces
100% slow traces
```

if your telemetry volume and cost allow it.

---

# 16.69 Important: Don't Over-Instrument

Bad:

```text
Every function
Every variable
Every loop
Every database object
```

This generates enormous telemetry.

Prefer important business operations:

```text
createOrder
checkout
payment
inventory
searchProducts
login
```

---

# 16.70 Important Backend Spans

For Zepto:

```text
HTTP
 |
 +-- authenticate
 |
 +-- getProducts
 |
 +-- searchProducts
 |
 +-- addToCart
 |
 +-- checkout
 |     |
 |     +-- inventory
 |     +-- payment
 |     +-- createOrder
 |
 +-- getOrder
```

These give meaningful traces.

---

# 16.71 Frontend User Journey

Later, frontend tracing can represent:

```text
User Journey
 |
 +-- Load homepage
 |
 +-- Search "Milk"
 |
 +-- Product API
 |
 +-- Add product
 |
 +-- Cart API
 |
 +-- Checkout
 |
 +-- Order API
```

This is sometimes called:

```text
End-to-End User Journey Tracing
```

---

# 16.72 Trace Propagation

The key header:

```text
traceparent
```

might look like:

```text
00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```

It contains trace context used to connect spans across services.

Do not manually generate these headers unless you have a specific reason; OpenTelemetry instrumentation should handle propagation.

---

# 16.73 HTTP Request Example

Conceptually:

```text
React

GET /api/products
traceparent:
00-abc123-xyz789-01
```

Node.js receives it.

OpenTelemetry extracts the context:

```text
Trace ID:
abc123
```

Node.js then creates:

```text
Span:
GET /api/products
```

MySQL span becomes:

```text
Trace:
abc123
```

Therefore all operations are connected.

---

# 16.74 Verify Trace Propagation

Open Grafana Tempo.

Search:

```text
service.name = zepto-backend
```

Select a trace.

You should see:

```text
HTTP request
 |
 +-- Express
 |
 +-- MySQL
```

If you also instrument React:

```text
React
 |
 +-- Node.js
      |
      +-- MySQL
```

---

# 16.75 Troubleshooting: No Traces

If no traces appear:

### Step 1

Check Node.js environment:

```powershell
kubectl exec -it POD_NAME -n zepto -- env | Select-String OTEL
```

You should see:

```text
OTEL_SERVICE_NAME
OTEL_EXPORTER_OTLP_ENDPOINT
```

### Step 2

Check Collector:

```powershell
kubectl logs deployment/otel-collector -n observability
```

### Step 3

Check Tempo:

```powershell
kubectl logs deployment/tempo -n observability
```

The exact resource names depend on your Helm deployment.

---

# 16.76 Troubleshooting: Collector Cannot Reach Tempo

Check services:

```powershell
kubectl get svc -n observability
```

Test DNS from a temporary Pod:

```powershell
kubectl run dns-test `
  -n observability `
  --image=busybox:1.36 `
  --rm -it `
  -- nslookup tempo.observability.svc.cluster.local
```

If DNS works:

```text
DNS ✓
```

Then investigate:

```text
Service port
NetworkPolicy
Collector endpoint
Tempo listener
```

---

# 16.77 Troubleshooting: Prometheus Analysis Fails

If Part 15 analysis suddenly fails after adding tracing:

Check:

```text
Metric name
Labels
Namespace
Service
Prometheus URL
```

Tracing itself should not change your Prometheus queries, but instrumentation may expose different metric labels depending on your implementation.

---

# 16.78 Troubleshooting: High Telemetry Volume

Symptoms:

```text
Collector CPU high
Collector memory high
Tempo storage growing rapidly
```

Actions:

```text
Reduce sampling
Use tail sampling
Increase batching
Scale Collector
Adjust retention
Filter noisy endpoints
```

Do not simply delete telemetry without understanding what is important.

---

# 16.79 Trace Retention

Example policy:

```text
Production:
7-14 days

Staging:
3-7 days

Development:
1-3 days
```

These are starting points only.

Longer retention increases storage cost.

Critical incident traces may need longer retention depending on organizational policy.

---

# 16.80 Observability Cost

Telemetry costs money.

You now have:

```text
Metrics
+
Logs
+
Traces
```

Volume:

```text
Metrics → moderate
Logs → high
Traces → potentially very high
```

Therefore:

```text
Sampling
Retention
Filtering
Aggregation
```

are important.

---

# 16.81 Grafana Unified Observability

Your Grafana dashboard can now contain:

```text
+-----------------------------------------------------+
|                ZEPTO OBSERVABILITY                  |
+-----------------------------------------------------+

Requests/sec         125

Error rate           0.03%

P95 latency          220ms

Active Pods           6

CPU                   48%

Memory                62%

+-----------------------------------------------------+
| Trace Explorer                                      |
+-----------------------------------------------------+

POST /api/orders
  |
  +-- checkout       30ms
  +-- inventory      90ms
  +-- mysql         110ms
  +-- payment       150ms

Total                 380ms
+-----------------------------------------------------+
```

---

# 16.82 Dashboard Panels

Create panels for:

```text
Application:

Request rate
Error rate
P95
P99

Infrastructure:

CPU
Memory
Pods
Nodes

Database:

Connections
Query latency
Errors

Tracing:

Trace rate
Error traces
Slow traces

Release:

Canary version
Stable version
Canary error rate
Canary latency
```

---

# 16.83 RED Dashboard

Create:

```text
monitoring/grafana/dashboards/zepto-red.json
```

Panels:

```text
Request Rate
Error Rate
P50
P95
P99
```

---

# 16.84 Trace Dashboard

Create:

```text
monitoring/grafana/dashboards/zepto-tracing.json
```

Panels:

```text
Traces/min
Error traces
Slow traces
Average duration
P95 duration
```

---

# 16.85 Release Dashboard

Create:

```text
monitoring/grafana/dashboards/zepto-release.json
```

Panels:

```text
Stable version
Canary version
Canary weight
Canary error rate
Canary P95
Analysis status
Rollback count
```

---

# 16.86 Alert Rules

Example:

```text
Canary error rate > 1%
```

```text
Canary P95 > 500ms
```

```text
Availability < 99.9%
```

```text
Collector unavailable
```

```text
Tempo unavailable
```

```text
Trace ingestion failure
```

---

# 16.87 Observability Failure Should Not Take Down Zepto

This principle is important.

If Tempo fails:

```text
Tempo ❌
```

Zepto should still work:

```text
React ✓
Node.js ✓
MySQL ✓
```

Tracing is:

```text
Non-critical path
```

Therefore your application should not block user requests waiting for Tempo.

---

# 16.88 Sampling and Async Export

Telemetry should generally be exported asynchronously.

Conceptually:

```text
User Request
 |
 v
Node.js
 |
 +---- Response immediately
 |
 +---- Telemetry export asynchronously
              |
              v
          Collector
```

Don't make:

```text
User request
 |
 v
Wait for Tempo
 |
 v
Response
```

because observability should not increase application latency unnecessarily.

---

# 16.89 Complete Observability Flow

```text
                      USER
                        |
                        v
                     React
                        |
                  Trace Context
                        |
                        v
                   Node.js API
                        |
             +----------+----------+
             |          |          |
             v          v          v
          Express     MySQL     Payment
             |          |          |
             +----------+----------+
                        |
                        v
                  OTel SDK
                        |
                        v
                OTel Collector
                        |
              +---------+---------+
              |                   |
              v                   v
            Tempo             Prometheus
              |                   |
              v                   v
           Grafana             Grafana
              |                   |
              +---------+---------+
                        |
                        v
                   Correlated
                  Observability
```

---

# 16.90 Correlation Across All Three Pillars

Now a production incident can be investigated like this:

```text
ALERT
 |
 v
Prometheus
 |
 | P95 increased
 v
Grafana
 |
 | Find slow trace
 v
Tempo
 |
 | Find MySQL span
 v
Trace ID
 |
 v
Logs
 |
 | Database timeout
 v
Root Cause
```

This is the real goal of distributed observability.

---

# 16.91 Production Incident Example

Alert:

```text
Zepto P95 > 500ms
```

Grafana:

```text
P95 = 1.2 sec
```

Tempo:

```text
POST /api/orders
```

Trace:

```text
API          1.2 sec
 |
 +-- Inventory      100ms
 |
 +-- MySQL          950ms
 |
 +-- Payment         80ms
```

Logs:

```text
MySQL connection pool exhausted
```

Prometheus:

```text
DB connections = 100%
```

Root cause:

```text
Database connection pool saturation
```

Now the engineering team knows exactly where to investigate.

---

# 16.92 Connect to Part 15 Automated Rollback

The final relationship:

```text
Argo Rollouts
      |
      v
Canary
      |
      v
Prometheus
      |
      v
SLO
      |
      v
FAIL
      |
      v
Rollback
```

Meanwhile:

```text
Tempo
 |
 v
Detailed trace
 |
 v
Root cause investigation
```

So automated systems handle:

```text
Detection
Rollback
```

while engineers use:

```text
Metrics
Logs
Traces
```

to understand:

```text
Why?
```

---

# 16.93 Update GitOps Repository

Your GitOps repository now contains:

```text
zepto-quick-commerce-gitops/
|
+-- apps/
|
+-- argocd/
|
+-- observability/
|   |
|   +-- tempo/
|   |
|   +-- otel/
|       |
|       +-- collector-values.yaml
|
+-- docs/
|   |
|   +-- progressive-delivery.md
|   +-- observability.md
|   +-- tracing.md
|
+-- README.md
```

---

# 16.94 Recommended Documentation

Create:

```text
docs/tracing.md
```

Content:

```markdown
# Zepto Distributed Tracing

## Components

- OpenTelemetry SDK
- OpenTelemetry Collector
- Grafana Tempo
- Grafana

## Trace Flow

React
→ Node.js
→ MySQL
→ OTel Collector
→ Tempo
→ Grafana

## Service Names

- zepto-frontend
- zepto-backend

## Important Traces

- Product search
- Cart
- Checkout
- Order creation
- Payment

## Troubleshooting

1. Check application OTEL variables
2. Check Collector
3. Check Tempo
4. Check Grafana data source
5. Verify trace propagation

## Sensitive Data

Never store:

- Passwords
- Tokens
- Payment information
- Database credentials
```

---

# 16.95 Production Runbook

Create:

```text
docs/runbooks/tracing-down.md
```

```markdown
# Tracing Down Runbook

## Symptoms

- No traces in Grafana
- Collector errors
- Tempo unavailable

## Step 1

Check Collector:

kubectl get pods -n observability

## Step 2

Check Collector logs:

kubectl logs deployment/otel-collector -n observability

## Step 3

Check Tempo:

kubectl get pods -n observability

## Step 4

Check Services:

kubectl get svc -n observability

## Step 5

Check Backend:

kubectl logs deployment/zepto-backend -n zepto

## Step 6

Verify OTEL environment:

kubectl exec POD_NAME -n zepto -- env

## Important

Application availability must not depend on tracing availability.
```

---

# 16.96 Part 16 Folder Structure

Your overall project is now:

```text
zepto-quick-commerce/
|
+-- frontend/
|
+-- backend/
|   |
|   +-- tracing.js
|   +-- controllers/
|   +-- routes/
|   +-- config/
|   +-- app.js
|   +-- server.js
|
+-- database/
|
+-- tests/
|
+-- monitoring/
|   |
|   +-- prometheus/
|   +-- grafana/
|   +-- tempo/
|   +-- otel/
|
+-- docs/
|   |
|   +-- observability.md
|   +-- tracing.md
|   +-- runbooks/
|
+-- .github/
|   +-- workflows/
|
+-- Dockerfile
|
+-- README.md
```

And GitOps:

```text
zepto-quick-commerce-gitops/
|
+-- apps/
|   |
|   +-- zepto/
|       |
|       +-- base/
|       +-- overlays/
|
+-- argocd/
|   |
|   +-- applications/
|   +-- projects/
|
+-- observability/
|   |
|   +-- tempo/
|   +-- otel/
|
+-- docs/
|   |
|   +-- tracing.md
|   +-- progressive-delivery.md
|
+-- README.md
```

---

# 16.97 Part 16 Testing Plan

Perform these tests in DEV first.

### Test 1 — Backend Trace

```text
GET /api/products
```

Verify:

```text
Node.js trace
```

---

### Test 2 — Database Trace

```text
GET /api/products
```

Verify:

```text
HTTP span
   |
   v
MySQL span
```

---

### Test 3 — Error Trace

Generate a controlled application error.

Verify:

```text
Trace status = ERROR
```

and:

```text
Exception recorded
```

---

### Test 4 — Trace ID in Logs

Take:

```text
Trace ID
```

Search logs.

Verify:

```text
Trace ID
appears in logs
```

---

### Test 5 — Slow Request

Create a controlled delay in DEV.

Example:

```javascript
await new Promise(
    resolve => setTimeout(resolve, 1000)
);
```

Call endpoint.

Expected:

```text
Trace duration ≈ 1 sec
```

---

### Test 6 — Canary

Deploy a new version.

```text
5% Canary
```

Verify:

```text
Canary traces
```

are distinguishable from stable traces.

---

### Test 7 — Automated Rollback

Make the canary violate the SLO.

Expected:

```text
AnalysisRun FAILED
        |
        v
Rollout ABORTED
        |
        v
Stable Version
```

---

# 16.98 Part 16 Verification Commands

Check OpenTelemetry:

```powershell
kubectl get pods -n observability
```

Check services:

```powershell
kubectl get svc -n observability
```

Check Collector logs:

```powershell
kubectl logs deployment/otel-collector -n observability
```

Check Tempo:

```powershell
kubectl get pods -n observability
```

Check backend:

```powershell
kubectl get pods -n zepto
```

Check environment:

```powershell
kubectl exec POD_NAME -n zepto -- env | Select-String OTEL
```

Check rollout:

```powershell
kubectl argo rollouts get rollout zepto-backend -n zepto
```

---

# 16.99 Part 16 Success Criteria

Part 16 is complete when:

```text
[✓] OpenTelemetry Collector deployed

[✓] Tempo deployed

[✓] Grafana connected to Tempo

[✓] Node.js OpenTelemetry SDK installed

[✓] Node.js auto-instrumentation enabled

[✓] HTTP spans visible

[✓] Express spans visible

[✓] MySQL spans visible

[✓] Manual business spans implemented

[✓] Trace propagation working

[✓] Trace IDs included in logs

[✓] Logs correlated with traces

[✓] Prometheus correlated with traces

[✓] Error traces visible

[✓] Slow traces visible

[✓] Sampling configured

[✓] Collector resource limits configured

[✓] Trace retention defined

[✓] Canary traces visible

[✓] SLO-based rollout analysis working

[✓] Automated rollback tested

[✓] Tracing runbook created
```

---

# 16.100 Final Zepto Observability Architecture

After Part 16:

```text
                              USER
                                |
                                v
                         React Frontend
                                |
                         Trace Context
                                |
                                v
                         Node.js Backend
                                |
              +-----------------+----------------+
              |                 |                |
              v                 v                v
            Express           MySQL          Payment
              |                 |                |
              +-----------------+----------------+
                                |
                                v
                       OpenTelemetry SDK
                                |
                                v
                     OpenTelemetry Collector
                                |
                 +--------------+--------------+
                 |                             |
                 v                             v
              Tempo                       Prometheus
                 |                             |
                 v                             |
              Grafana <------------------------+
                 |
        +--------+---------+
        |        |         |
        v        v         v
      Logs    Metrics    Traces
        |        |         |
        +--------+---------+
                 |
                 v
          Root Cause Analysis
```

And for releases:

```text
                 GitOps
                    |
                    v
                 Argo CD
                    |
                    v
              Argo Rollouts
                    |
                    v
                 Canary
                    |
          +---------+---------+
          |         |         |
          v         v         v
       Metrics    Logs      Traces
          |         |         |
          +---------+---------+
                    |
                    v
                 SLO Gate
                 /     \
              PASS     FAIL
               |         |
               v         v
            Continue   Rollback
```

---

# 16.101 The Big Picture

The Zepto platform has now evolved into a sophisticated cloud-native architecture:

```text
PART 1
Architecture
       ↓
PART 2
React
       ↓
PART 3
Node.js
       ↓
PART 4
MySQL
       ↓
PART 5
Docker
       ↓
PART 6
GKE
       ↓
PART 7
Kubernetes
       ↓
PART 8
GitHub Actions
       ↓
PART 9
CI/CD Validation
       ↓
PART 10
Prometheus + Grafana
       ↓
PART 11
Centralized Logging
       ↓
PART 12
Security Hardening
       ↓
PART 13
HA + Scaling + DR
       ↓
PART 14
GitOps + Argo CD
       ↓
PART 15
Progressive Delivery
       ↓
PART 16
OpenTelemetry
+ Tempo
+ Distributed Tracing
+ Trace/Log/Metric Correlation
```

The most important operational capability you gain in Part 16 is this:

```text
                ALERT
                  |
                  v
              PROMETHEUS
                  |
                  | P95 high
                  v
               GRAFANA
                  |
                  | Find trace
                  v
                TEMPO
                  |
                  | Trace ID
                  v
                LOGS
                  |
                  | Error message
                  v
              ROOT CAUSE
                  |
                  v
             ARGO ROLLOUT
                  |
                  v
              ROLLBACK
```

So the platform can now answer all three critical observability questions:

```text
Metrics → WHAT is wrong?

Logs   → WHAT happened?

Traces → WHERE and WHY did it happen?
```

And because Part 15 already introduced progressive delivery, the same observability data can now become a **release safety mechanism**, not merely a dashboard: Prometheus/SLO measurements can stop a bad canary, while Tempo and correlated logs give engineers the detailed evidence needed to diagnose the failure.
