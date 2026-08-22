# Part 12 — Security Hardening and Production Readiness for Zepto Quick Commerce

At this stage, Zepto has:

```text
Part 1  → Architecture
Part 2  → React Frontend
Part 3  → Node.js Backend
Part 4  → MySQL
Part 5  → Docker
Part 6  → GKE
Part 7  → Kubernetes
Part 8  → GitHub Actions CI/CD
Part 9  → End-to-End CI/CD Testing
Part 10 → Prometheus + Grafana
Part 11 → Centralized Logging & Observability
Part 12 → Security Hardening & Production Readiness
```

The goal of Part 12 is to move from:

```text
"Application works"
```

to:

```text
"Application is secure, controlled, monitored and production-ready."
```

Google's current GKE hardening guidance recommends least-privilege IAM/RBAC, Workload Identity Federation, NetworkPolicies, private nodes/control-plane protection, external secret management, workload isolation and admission controls. ([Google Cloud Documentation][1])

---

# 12.1 Production Security Architecture

Our final architecture becomes:

```text
                         INTERNET
                            |
                            v
                    Cloud Load Balancer
                            |
                     Cloud Armor
                            |
                            v
                         Ingress
                            |
                 +----------+----------+
                 |                     |
                 v                     v
          React Frontend          Node.js Backend
                                        |
                                        v
                                   MySQL / Cloud SQL
```

Security layers:

```text
                    SECURITY
                       |
       +---------------+---------------+
       |               |               |
       v               v               v
    Network          Identity        Workload
       |               |               |
       v               v               v
NetworkPolicy       IAM/RBAC       SecurityContext
Cloud Armor         WIF            Non-root
Private GKE         Secrets        Read-only FS
```

---

# 12.2 Security Hardening Checklist

We will implement:

```text
[ ] Kubernetes RBAC
[ ] Workload Identity Federation
[ ] Google Secret Manager
[ ] Kubernetes NetworkPolicies
[ ] Non-root containers
[ ] Read-only root filesystem where practical
[ ] Drop Linux capabilities
[ ] Disable privilege escalation
[ ] Resource requests/limits
[ ] Pod Security Admission
[ ] Private GKE nodes
[ ] GKE network hardening
[ ] Artifact Registry vulnerability scanning
[ ] Image tagging strategy
[ ] GitHub Actions least privilege
[ ] HTTPS
[ ] Cloud Armor
[ ] Security headers
[ ] Database hardening
[ ] Backup strategy
[ ] Audit logging
[ ] Production monitoring
```

---

# 12.3 First Rule — Do Not Put Production Secrets in Git

Currently we have:

```text
kubernetes/secret.yaml
```

with values such as:

```yaml
DB_PASSWORD: "Root@123"
JWT_SECRET: "mySuperSecretKey"
```

This is acceptable for the training environment.

It is **not appropriate for production**.

Google recommends using Secret Manager rather than relying on Kubernetes Secrets where possible. ([Google Cloud Documentation][1])

Production architecture:

```text
Google Secret Manager
        |
        v
Workload Identity
        |
        v
Node.js Backend
        |
        v
Secret value
```

---

# 12.4 Enable Required Google APIs

Run:

```powershell
gcloud services enable secretmanager.googleapis.com
```

Also:

```powershell
gcloud services enable container.googleapis.com
```

And:

```powershell
gcloud services enable artifactregistry.googleapis.com
```

---

# 12.5 Create Production Secrets in Secret Manager

Create database password:

```powershell
echo -n "CHANGE_THIS_PASSWORD" | `
gcloud secrets create zepto-db-password `
  --data-file=-
```

Create JWT secret:

```powershell
echo -n "CHANGE_THIS_JWT_SECRET" | `
gcloud secrets create zepto-jwt-secret `
  --data-file=-
```

Verify:

```powershell
gcloud secrets list
```

You should see:

```text
zepto-db-password
zepto-jwt-secret
```

---

# 12.6 Create a Dedicated Kubernetes ServiceAccount

Do not use the default ServiceAccount for the backend.

Create:

```text
kubernetes/backend/serviceaccount.yaml
```

```yaml
apiVersion: v1

kind: ServiceAccount

metadata:

  name: zepto-backend

  namespace: zepto
```

Apply:

```powershell
kubectl apply -f kubernetes/backend/serviceaccount.yaml
```

Verify:

```powershell
kubectl get serviceaccount -n zepto
```

---

# 12.7 Workload Identity Federation

For production, the backend should have its own Google identity.

Architecture:

```text
Node.js Pod
    |
    v
Kubernetes ServiceAccount
    |
    v
Workload Identity Federation
    |
    v
Google Service Account
    |
    v
Secret Manager
```

This avoids storing a Google service-account JSON key inside the container.

Google explicitly recommends Workload Identity Federation for GKE workloads accessing Google Cloud APIs. ([Google Cloud Documentation][1])

---

# 12.8 Create Google Service Account

```powershell
gcloud iam service-accounts create zepto-backend `
  --project=zepto-ecommerce-class `
  --display-name="Zepto Backend"
```

Service account:

```text
zepto-backend@zepto-ecommerce-class.iam.gserviceaccount.com
```

---

# 12.9 Grant Secret Access

Grant only the required Secret Manager permissions.

For DB password:

```powershell
gcloud secrets add-iam-policy-binding zepto-db-password `
  --member="serviceAccount:zepto-backend@zepto-ecommerce-class.iam.gserviceaccount.com" `
  --role="roles/secretmanager.secretAccessor"
```

For JWT:

```powershell
gcloud secrets add-iam-policy-binding zepto-jwt-secret `
  --member="serviceAccount:zepto-backend@zepto-ecommerce-class.iam.gserviceaccount.com" `
  --role="roles/secretmanager.secretAccessor"
```

This follows least privilege.

---

# 12.10 Bind Kubernetes ServiceAccount

Get the project number:

```powershell
gcloud projects describe zepto-ecommerce-class `
  --format="value(projectNumber)"
```

Then grant the Kubernetes ServiceAccount permission to impersonate the Google ServiceAccount.

Conceptually:

```text
Kubernetes SA
     |
     | Workload Identity
     v
Google SA
     |
     v
Secret Manager
```

The exact principal binding depends on your GKE Workload Identity configuration.

---

# 12.11 Add Annotation

Update:

```text
kubernetes/backend/serviceaccount.yaml
```

```yaml
apiVersion: v1

kind: ServiceAccount

metadata:

  name: zepto-backend

  namespace: zepto

  annotations:

    iam.gke.io/gcp-service-account: zepto-backend@zepto-ecommerce-class.iam.gserviceaccount.com
```

Apply:

```powershell
kubectl apply -f kubernetes/backend/serviceaccount.yaml
```

---

# 12.12 Update Backend Deployment

In:

```text
kubernetes/backend/deployment.yaml
```

add:

```yaml
spec:

  template:

    spec:

      serviceAccountName: zepto-backend
```

So the Pod uses:

```text
zepto-backend
```

instead of:

```text
default
```

---

# 12.13 Kubernetes RBAC

Your GitHub Actions deployment ServiceAccount should **not** have:

```text
cluster-admin
```

You already created a namespace-scoped Role.

Keep:

```text
Role
   |
   v
RoleBinding
   |
   v
github-actions
```

rather than:

```text
cluster-admin
```

Google recommends least privilege using IAM and Kubernetes RBAC. ([Google Cloud Documentation][1])

---

# 12.14 Verify RBAC

Run:

```powershell
kubectl auth can-i get deployments `
  --as=system:serviceaccount:zepto:github-actions `
  -n zepto
```

Expected:

```text
yes
```

Test something it should not have:

```powershell
kubectl auth can-i get secrets `
  --as=system:serviceaccount:zepto:github-actions `
  -n kube-system
```

Expected:

```text
no
```

This demonstrates least privilege.

---

# 12.15 Network Security

By default, Kubernetes networking can allow broad Pod-to-Pod communication.

We want:

```text
Internet
   |
   v
Ingress
   |
   v
Frontend
   |
   v
Backend
   |
   v
MySQL
```

But we do **not** want:

```text
Frontend ---> MySQL
Internet ---> MySQL
Internet ---> Backend
MySQL ---> Backend
```

GKE recommends controlling Pod-to-Pod traffic using NetworkPolicies or equivalent controls. ([Google Cloud Documentation][1])

---

# 12.16 Default Deny NetworkPolicy

Create:

```text
kubernetes/network-policies/default-deny.yaml
```

```yaml
apiVersion: networking.k8s.io/v1

kind: NetworkPolicy

metadata:

  name: default-deny

  namespace: zepto

spec:

  podSelector: {}

  policyTypes:

    - Ingress
    - Egress
```

Apply:

```powershell
kubectl apply -f kubernetes/network-policies/default-deny.yaml
```

### Important

Do **not** apply this blindly to a production cluster before creating the required allow rules.

Otherwise you can break:

```text
DNS
Backend
MySQL
Prometheus
Ingress
```

---

# 12.17 Allow DNS

Create:

```text
kubernetes/network-policies/dns.yaml
```

```yaml
apiVersion: networking.k8s.io/v1

kind: NetworkPolicy

metadata:

  name: allow-dns

  namespace: zepto

spec:

  podSelector: {}

  policyTypes:

    - Egress

  egress:

    - to:

        - namespaceSelector: {}

      ports:

        - protocol: UDP
          port: 53

        - protocol: TCP
          port: 53
```

---

# 12.18 Frontend NetworkPolicy

Frontend should accept traffic from the Ingress/load-balancer path and generally only need outbound access to the backend if your frontend architecture requires server-side calls.

For a browser-based React application, API calls normally go through the Ingress and then to backend; the browser itself is not inside the cluster.

A basic frontend policy:

```yaml
apiVersion: networking.k8s.io/v1

kind: NetworkPolicy

metadata:

  name: frontend-policy

  namespace: zepto

spec:

  podSelector:

    matchLabels:

      app: zepto-frontend

  policyTypes:

    - Ingress

  ingress:

    - ports:

        - protocol: TCP
          port: 80
```

---

# 12.19 Backend NetworkPolicy

Backend needs:

```text
Ingress
   |
   v
Backend
   |
   v
MySQL
```

Create:

```text
kubernetes/network-policies/backend.yaml
```

```yaml
apiVersion: networking.k8s.io/v1

kind: NetworkPolicy

metadata:

  name: backend-policy

  namespace: zepto

spec:

  podSelector:

    matchLabels:

      app: zepto-backend

  policyTypes:

    - Ingress
    - Egress

  ingress:

    - ports:

        - protocol: TCP
          port: 5000

  egress:

    - to:

        - podSelector:

            matchLabels:

              app: zepto-mysql

      ports:

        - protocol: TCP
          port: 3306
```

---

# 12.20 MySQL NetworkPolicy

MySQL should only receive traffic from backend.

Create:

```text
kubernetes/network-policies/mysql.yaml
```

```yaml
apiVersion: networking.k8s.io/v1

kind: NetworkPolicy

metadata:

  name: mysql-policy

  namespace: zepto

spec:

  podSelector:

    matchLabels:

      app: zepto-mysql

  policyTypes:

    - Ingress

  ingress:

    - from:

        - podSelector:

            matchLabels:

              app: zepto-backend

      ports:

        - protocol: TCP
          port: 3306
```

Now:

```text
Backend ---> MySQL
```

is allowed.

But:

```text
Frontend ---> MySQL
```

is blocked.

---

# 12.21 Verify NetworkPolicies

```powershell
kubectl get networkpolicy -n zepto
```

Expected:

```text
default-deny
allow-dns
frontend-policy
backend-policy
mysql-policy
```

Test backend health:

```powershell
kubectl run curl-test `
  --image=curlimages/curl `
  --rm -it `
  --restart=Never `
  -n zepto `
  -- curl http://zepto-backend:5000/health
```

Then verify database connectivity.

---

# 12.22 Container Security Context

Your current Pods should be hardened.

Kubernetes security contexts allow you to control privileges such as running as non-root, dropping capabilities, disabling privilege escalation and using a read-only filesystem. ([Kubernetes][2])

For Node.js:

```yaml
securityContext:

  runAsNonRoot: true

  runAsUser: 10001

  allowPrivilegeEscalation: false

  capabilities:

    drop:

      - ALL

  seccompProfile:

    type: RuntimeDefault
```

---

# 12.23 Backend Deployment SecurityContext

Update:

```text
kubernetes/backend/deployment.yaml
```

Add:

```yaml
spec:

  template:

    spec:

      securityContext:

        runAsNonRoot: true

        seccompProfile:

          type: RuntimeDefault

      containers:

        - name: backend

          securityContext:

            runAsNonRoot: true

            runAsUser: 10001

            allowPrivilegeEscalation: false

            capabilities:

              drop:

                - ALL
```

---

# 12.24 Why Non-Root?

Bad:

```text
Container
   |
   v
root
```

Better:

```text
Container
   |
   v
UID 10001
```

If an application vulnerability is exploited, the attacker does not automatically get root privileges inside the container.

---

# 12.25 Update Backend Dockerfile

Your backend Dockerfile should create a non-root user.

Example:

```dockerfile
FROM node:22-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev

COPY . .

RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 5000

CMD ["node", "server.js"]
```

The important line is:

```dockerfile
USER appuser
```

---

# 12.26 Frontend Container Security

If using Nginx, run the container using a non-root configuration where practical.

Your production frontend should avoid unnecessary privileges.

Also make sure:

```text
No SSH
No debugging tools
No package manager
No credentials
```

are included in the final image unless required.

---

# 12.27 Multi-Stage Frontend Dockerfile

A good React production image uses multi-stage builds:

```dockerfile
FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build


FROM nginx:alpine

COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

This means the final image doesn't contain the entire Node.js development environment.

---

# 12.28 Minimize Docker Images

Avoid:

```dockerfile
FROM ubuntu
```

when you only need Node.js.

Prefer:

```dockerfile
FROM node:22-alpine
```

or another minimal supported base image.

The goal is:

```text
Smaller image
      |
      +-- fewer packages
      |
      +-- fewer vulnerabilities
      |
      +-- faster deployment
```

---

# 12.29 Add .dockerignore

Backend:

```text
backend/.dockerignore
```

```text
node_modules
npm-debug.log
.git
.gitignore
.env
.env.*
coverage
Dockerfile
README.md
```

Frontend:

```text
frontend/.dockerignore
```

```text
node_modules
npm-debug.log
.git
.gitignore
.env
.env.*
coverage
Dockerfile
README.md
```

Never send:

```text
.env
```

into your Docker build context.

---

# 12.30 Secrets in .gitignore

Your root `.gitignore` should include:

```text
.env
.env.*
*.pem
*.key
*.crt
credentials.json
service-account.json
node_modules/
```

But remember:

```text
.gitignore
```

does not remove a file already committed to Git.

If a secret has ever been committed, rotate it.

---

# 12.31 Artifact Registry Vulnerability Scanning

Artifact Registry/Artifact Analysis supports vulnerability scanning of container images. ([Google Cloud Documentation][3])

Enable the required service:

```powershell
gcloud services enable containerscanning.googleapis.com
```

Then inspect images through Artifact Registry/Security Command Center according to the scanning configuration available in your project.

---

# 12.32 Scan Backend Image

List images:

```powershell
gcloud artifacts docker images list `
  asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo
```

Find:

```text
zepto-backend
```

Then inspect vulnerability findings through Google Cloud's Artifact Analysis/Security Command Center interfaces.

---

# 12.33 CI/CD Security Gate

Your current pipeline:

```text
Test
  |
  v
Build
  |
  v
Push
  |
  v
Deploy
```

Production should become:

```text
Test
  |
  v
Security Scan
  |
  v
Build
  |
  v
Image Scan
  |
  v
Approve
  |
  v
Deploy
```

---

# 12.34 Image Tagging

Never use only:

```text
latest
```

Production should use immutable tags.

Your current approach:

```text
zepto-backend:<GIT_SHA>
```

is good.

Example:

```text
zepto-backend:a83f921
```

This lets you determine exactly which source commit produced the running image.

---

# 12.35 Production Image Flow

```text
Git Commit
    |
    v
a83f921
    |
    v
Docker Build
    |
    v
zepto-backend:a83f921
    |
    v
Artifact Registry
    |
    v
GKE
```

---

# 12.36 Rollback

Suppose the new version is:

```text
a83f921
```

and it has a production problem.

Check:

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

# 12.37 Better Rollback

If you know the previous image:

```powershell
kubectl set image deployment/zepto-backend `
  backend=asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:PREVIOUS_SHA `
  -n zepto
```

This is preferable because it explicitly identifies the desired version.

---

# 12.38 Pod Security Admission

Kubernetes provides Pod Security Standards with:

```text
Privileged
Baseline
Restricted
```

`Restricted` is the most restrictive profile and follows current Pod-hardening practices. ([Kubernetes][4])

For the Zepto application namespace, aim toward:

```text
Restricted
```

but test compatibility before enforcing it.

---

# 12.39 Label Namespace for Pod Security

First inspect:

```powershell
kubectl get namespace zepto --show-labels
```

Then, after confirming your Pods comply:

```powershell
kubectl label namespace zepto `
  pod-security.kubernetes.io/enforce=restricted `
  pod-security.kubernetes.io/audit=restricted `
  pod-security.kubernetes.io/warn=restricted `
  --overwrite
```

### Recommended rollout approach

Start with:

```text
warn
audit
```

Then move to:

```text
enforce
```

after testing.

---

# 12.40 Resource Requests and Limits

You already have:

```yaml
resources:

  requests:

    cpu: "250m"

    memory: "256Mi"

  limits:

    cpu: "500m"

    memory: "512Mi"
```

This is important for:

```text
Predictability
Scheduling
Noisy-neighbor protection
Capacity planning
```

---

# 12.41 Add MySQL Resources

For the training environment:

```yaml
resources:

  requests:

    cpu: "250m"

    memory: "512Mi"

  limits:

    cpu: "1000m"

    memory: "1Gi"
```

Production values must be determined from actual workload measurements.

---

# 12.42 ResourceQuota

Create:

```text
kubernetes/resource-quota.yaml
```

```yaml
apiVersion: v1

kind: ResourceQuota

metadata:

  name: zepto-quota

  namespace: zepto

spec:

  hard:

    requests.cpu: "2"

    requests.memory: 4Gi

    limits.cpu: "4"

    limits.memory: 8Gi

    pods: "20"
```

Apply:

```powershell
kubectl apply -f kubernetes/resource-quota.yaml
```

---

# 12.43 LimitRange

Create:

```text
kubernetes/limit-range.yaml
```

```yaml
apiVersion: v1

kind: LimitRange

metadata:

  name: zepto-limits

  namespace: zepto

spec:

  limits:

    - type: Container

      default:

        cpu: "500m"

        memory: "512Mi"

      defaultRequest:

        cpu: "100m"

        memory: "128Mi"
```

Apply:

```powershell
kubectl apply -f kubernetes/limit-range.yaml
```

---

# 12.44 HTTPS

Production should not use:

```text
http://
```

Use:

```text
https://
```

Architecture:

```text
User
 |
 | HTTPS
 v
Google Load Balancer
 |
 v
Ingress
 |
 v
Frontend / Backend
```

---

# 12.45 Managed TLS Certificate

For a real domain such as:

```text
www.zepto-example.com
```

use a Google-managed certificate or another approved certificate-management approach.

Example concept:

```yaml
apiVersion: networking.gke.io/v1

kind: ManagedCertificate

metadata:

  name: zepto-certificate

  namespace: zepto

spec:

  domains:

    - www.zepto-example.com
```

You must replace the domain with one you control.

---

# 12.46 Do Not Use Fake Production Domains

For training:

```text
EXTERNAL-IP
```

is fine.

For production:

```text
https://zepto.example.com
```

requires:

```text
DNS
TLS certificate
HTTPS configuration
```

---

# 12.47 Security Headers

Your Node.js backend already uses:

```javascript
helmet()
```

Good.

Helmet can provide important HTTP security headers.

Continue using:

```javascript
app.use(helmet());
```

---

# 12.48 CORS

Avoid:

```javascript
app.use(cors());
```

for production if the API should only be accessed from your frontend.

Instead:

```javascript
app.use(
    cors({
        origin: process.env.FRONTEND_URL,
        credentials: true
    })
);
```

For example:

```text
FRONTEND_URL=https://www.zepto-example.com
```

---

# 12.49 Production Environment Variables

Do not hardcode:

```javascript
origin: "http://localhost:3000"
```

Use:

```text
FRONTEND_URL
```

and:

```text
NODE_ENV=production
```

---

# 12.50 MySQL Production Recommendation

Currently:

```text
GKE
 |
 +-- MySQL Pod
      |
      +-- PVC
```

This is suitable for learning.

For production:

```text
GKE
 |
 +-- Node.js
 |
 +-- React
 |
 v
Cloud SQL for MySQL
```

Why?

```text
Managed backups
High availability options
Maintenance
Monitoring
Database operations
```

For a real production system, I strongly recommend moving MySQL out of the application cluster.

---

# 12.51 MySQL Backup

At minimum:

```text
Database
   |
   v
Automated Backup
   |
   v
Recovery
```

For your current GKE MySQL lab, ensure the PVC is backed up appropriately.

For production, Cloud SQL provides managed backup capabilities.

---

# 12.52 Database Credentials

Never:

```text
DB_PASSWORD=Root@123
```

in:

```text
GitHub
Dockerfile
Git
README
Kubernetes Deployment
```

Use:

```text
Secret Manager
```

instead.

---

# 12.53 GitHub Actions Security

Your workflow already uses:

```yaml
permissions:

  contents: read

  id-token: write
```

This is good.

Do not change to:

```yaml
permissions: write-all
```

unless there is a specific requirement.

---

# 12.54 GitHub Branch Protection

Protect:

```text
main
```

Recommended:

```text
Pull Request required
At least 1 reviewer
Status checks required
No direct pushes
```

Flow:

```text
feature branch
      |
      v
Pull Request
      |
      v
CI tests
      |
      v
Code review
      |
      v
main
      |
      v
Production deployment
```

---

# 12.55 Separate Environments

A mature architecture should have:

```text
Development
      |
      v
QA / Staging
      |
      v
Production
```

For example:

```text
GKE dev cluster
GKE staging cluster
GKE production cluster
```

or carefully separated namespaces/environments depending on organizational requirements.

---

# 12.56 Production Promotion

Do not automatically deploy every feature branch to production.

Recommended:

```text
feature/*
    |
    v
Pull Request
    |
    v
CI
    |
    v
main
    |
    v
Build Image
    |
    v
Staging
    |
    v
Validation
    |
    v
Production Approval
    |
    v
Production GKE
```

---

# 12.57 Audit Logging

Google Cloud Audit Logs record administrative and access activities and are useful for troubleshooting, auditing and incident response. ([Google Cloud Documentation][5])

For security investigations ask:

```text
Who?
What?
When?
Which resource?
From where?
```

Example:

```text
Who changed deployment?
Who accessed Secret Manager?
Who changed IAM?
Who modified GKE?
```

---

# 12.58 Security Command Center

For production Google Cloud environments, consider Security Command Center.

It can help with:

```text
Security findings
Misconfigurations
Vulnerabilities
Threat detection
Security posture
```

Google's GKE security guidance specifically recommends Security Command Center for checking security posture and common misconfigurations. ([Google Cloud Documentation][1])

---

# 12.59 Cloud Armor

For Internet-facing applications:

```text
Internet
   |
   v
Cloud Armor
   |
   v
Load Balancer
   |
   v
GKE Ingress
```

Cloud Armor can provide:

```text
WAF protection
DDoS-related protection
IP filtering
Security policies
```

GKE networking guidance recommends considering Cloud Armor security policies for Ingress. ([Google Cloud Documentation][6])

---

# 12.60 Production Architecture

The recommended mature Zepto architecture becomes:

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
                                          |
                                          |
                                  +-------+-------+
                                  |               |
                                  v               v
                            Secret Manager     Cloud SQL
                                  |
                                  v
                           Workload Identity
```

Monitoring:

```text
GKE
 |
 +-- Prometheus
 |
 +-- Grafana
 |
 +-- Cloud Logging
 |
 +-- Cloud Monitoring
 |
 +-- Audit Logs
 |
 +-- Security Command Center
```

---

# 12.61 Production Security Layers

Think about security as multiple layers:

```text
Layer 1
Cloud / GCP IAM
       |
       v
Layer 2
GKE Control Plane
       |
       v
Layer 3
Network Policies
       |
       v
Layer 4
Ingress / Cloud Armor
       |
       v
Layer 5
Kubernetes RBAC
       |
       v
Layer 6
Pod Security
       |
       v
Layer 7
Container Security
       |
       v
Layer 8
Application Security
       |
       v
Layer 9
Database Security
       |
       v
Layer 10
Monitoring / Logging
```

---

# 12.62 Verify Current Security Posture

Run:

```powershell
kubectl get networkpolicy -n zepto
```

```powershell
kubectl get serviceaccount -n zepto
```

```powershell
kubectl get role -n zepto
```

```powershell
kubectl get rolebinding -n zepto
```

```powershell
kubectl get resourcequota -n zepto
```

```powershell
kubectl get limitrange -n zepto
```

---

# 12.63 Verify Pods Don't Run as Root

Check:

```powershell
kubectl get pod POD_NAME -n zepto `
  -o jsonpath="{.spec.securityContext.runAsNonRoot}"
```

Expected:

```text
true
```

Check container:

```powershell
kubectl get pod POD_NAME -n zepto `
  -o jsonpath="{.spec.containers[0].securityContext.allowPrivilegeEscalation}"
```

Expected:

```text
false
```

---

# 12.64 Security Test — MySQL Should Not Be Public

Run:

```powershell
kubectl get service zepto-mysql -n zepto
```

Expected:

```text
TYPE
ClusterIP
```

Not:

```text
LoadBalancer
```

Not:

```text
NodePort
```

---

# 12.65 Security Test — Backend Should Not Be Public Directly

Run:

```powershell
kubectl get service zepto-backend -n zepto
```

Expected:

```text
ClusterIP
```

Public access should be through:

```text
HTTPS
  |
  v
Ingress
  |
  v
Backend
```

---

# 12.66 Security Test — Frontend

Frontend can be exposed through Ingress:

```text
Internet
   |
   v
HTTPS
   |
   v
Ingress
   |
   v
Frontend
```

The backend should remain a ClusterIP service.

---

# 12.67 Security Test — Secret Exposure

Search Git:

```powershell
git grep -n "Root@123"
```

Also:

```powershell
git grep -n "mySuperSecretKey"
```

The production repository should return no real production credentials.

If these are only lab credentials, rotate them before production.

---

# 12.68 Security Test — Docker Images

Check:

```powershell
docker images
```

Then verify:

```text
No credentials
No .env
No private keys
No SSH keys
```

were accidentally copied into the image.

---

# 12.69 Production Readiness Checklist

### Application

```text
[ ] Passwords hashed
[ ] JWT secrets stored securely
[ ] CORS restricted
[ ] Helmet enabled
[ ] Input validation
[ ] Error handling
[ ] Rate limiting
[ ] No sensitive logs
```

### Container

```text
[ ] Minimal base image
[ ] Multi-stage build
[ ] Non-root
[ ] No privilege escalation
[ ] Drop capabilities
[ ] Read-only filesystem where possible
[ ] Vulnerability scanning
```

### Kubernetes

```text
[ ] RBAC
[ ] NetworkPolicies
[ ] Pod Security
[ ] ResourceQuota
[ ] LimitRange
[ ] Probes
[ ] Requests/limits
[ ] Separate ServiceAccounts
```

### GKE

```text
[ ] Workload Identity Federation
[ ] Private nodes
[ ] Control-plane access restricted
[ ] VPC-native networking
[ ] Network security
[ ] Audit logging
```

### Secrets

```text
[ ] Secret Manager
[ ] No secrets in Git
[ ] No secrets in Docker images
[ ] No secrets in logs
```

### CI/CD

```text
[ ] OIDC/WIF
[ ] Least privilege
[ ] Immutable image tags
[ ] Vulnerability scanning
[ ] Branch protection
[ ] PR approval
[ ] Rollback strategy
```

### Observability

```text
[ ] Prometheus
[ ] Grafana
[ ] Cloud Logging
[ ] Alerts
[ ] Audit logs
[ ] Incident response
```

---

# 12.70 Updated Repository Structure

After Part 12:

```text
zepto-quick-commerce/
|
+-- frontend/
|   +-- Dockerfile
|   +-- .dockerignore
|
+-- backend/
|   |
|   +-- config/
|   |   +-- db.js
|   |   +-- metrics.js
|   |   +-- logger.js
|   |
|   +-- middleware/
|   |   +-- requestId.js
|   |
|   +-- Dockerfile
|   +-- .dockerignore
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
|   |   +-- default-deny.yaml
|   |   +-- allow-dns.yaml
|   |   +-- frontend.yaml
|   |   +-- backend.yaml
|   |   +-- mysql.yaml
|   |
|   +-- backend/
|   |   +-- deployment.yaml
|   |   +-- service.yaml
|   |   +-- serviceaccount.yaml
|   |
|   +-- frontend/
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

# 12.71 Git Commit

Create the security branch:

```powershell
git checkout -b feature/security-hardening
```

Add changes:

```powershell
git add kubernetes/
git add backend/
git add frontend/
git add .gitignore
```

Commit:

```powershell
git commit -m "Harden Zepto application for production"
```

Push:

```powershell
git push origin feature/security-hardening
```

Create a Pull Request.

---

# 12.72 Final Production Deployment Flow

The CI/CD pipeline should eventually look like:

```text
Developer
    |
    v
Feature Branch
    |
    v
Pull Request
    |
    +-------------------+
    |                   |
    v                   v
Unit Tests         Security Checks
    |                   |
    +---------+---------+
              |
              v
            Merge
              |
              v
             main
              |
              v
       Build Docker Image
              |
              v
       Vulnerability Scan
              |
              v
       Artifact Registry
              |
              v
           Staging
              |
              v
        Smoke Tests
              |
              v
        Approval Gate
              |
              v
         Production
              |
              v
             GKE
              |
      +-------+-------+
      |               |
      v               v
   Frontend        Backend
                      |
                      v
                  Cloud SQL
```

---

# 12.73 Security Incident Flow

If something goes wrong:

```text
Alert
  |
  v
Grafana / Cloud Monitoring
  |
  v
Prometheus Metric
  |
  v
Cloud Logging
  |
  v
Kubernetes Pod
  |
  v
Application Error
  |
  v
Security / Root Cause Analysis
  |
  v
Fix
  |
  v
Pull Request
  |
  v
CI Security Checks
  |
  v
Production Deployment
```

---

# 12.74 Final Part 12 Architecture

```text
                             INTERNET
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
                 +--------------+--------------+
                 |                             |
                 v                             v
          React Frontend                Node.js Backend
                                               |
                                +--------------+--------------+
                                |                             |
                                v                             v
                         Secret Manager                  Cloud SQL
                                ^
                                |
                       Workload Identity
                                |
                                v
                              GKE


             +-----------------------------------------+
             |                GKE Cluster               |
             |                                          |
             |  NetworkPolicies                         |
             |  RBAC                                    |
             |  Pod Security                            |
             |  ResourceQuota                           |
             |  LimitRange                               |
             |  Non-root containers                      |
             +-----------------------------------------+
                                |
                +---------------+---------------+
                |               |               |
                v               v               v
            Prometheus       Grafana       Cloud Logging
                |                               |
                +---------------+---------------+
                                |
                                v
                          Incident Response
```

---

# 12.75 Part 12 Success Criteria

Part 12 is complete when:

```text
[✓] Production secrets moved toward Secret Manager

[✓] No production credentials in Git

[✓] Backend has dedicated ServiceAccount

[✓] Workload Identity Federation configured

[✓] Google IAM follows least privilege

[✓] Kubernetes RBAC follows least privilege

[✓] MySQL is internal ClusterIP

[✓] Backend is internal ClusterIP

[✓] NetworkPolicies implemented

[✓] DNS explicitly allowed

[✓] Backend -> MySQL allowed

[✓] Frontend -> MySQL blocked

[✓] Containers run as non-root

[✓] Privilege escalation disabled

[✓] Linux capabilities dropped

[✓] Resource requests configured

[✓] Resource limits configured

[✓] ResourceQuota configured

[✓] LimitRange configured

[✓] Pod Security considered/enforced

[✓] Docker images minimized

[✓] .dockerignore configured

[✓] Artifact Registry vulnerability scanning considered

[✓] Immutable image tags used

[✓] HTTPS planned/configured

[✓] CORS restricted

[✓] Security headers enabled

[✓] Audit logging available

[✓] Prometheus monitoring active

[✓] Centralized logging active

[✓] Rollback procedure tested
```

---

# 12.76 Important Production Note

Do **not** apply every security manifest from this tutorial blindly to your existing cluster.

Especially test these before enforcing them:

```text
NetworkPolicy
Pod Security restricted
readOnlyRootFilesystem
non-root
ResourceQuota
private nodes
control-plane restrictions
```

A security change can legitimately break application connectivity.

Use this sequence:

```text
Development
    |
    v
Test
    |
    v
Staging
    |
    v
Security validation
    |
    v
Production
```

GKE's current security guidance emphasizes defense in depth, least privilege, workload identity, network isolation and external secret management. ([Google Cloud Documentation][1])

---

# 12.77 Zepto Project — Complete Journey So Far

```text
Part 1
Architecture & GitHub
       |
       v
Part 2
React Frontend
       |
       v
Part 3
Node.js Backend
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
Centralized Logging
       |
       v
Part 12
Security Hardening
       |
       v
Production-Ready Zepto
```

## Next Logical Step — Part 13

The next logical step is **Part 13 — High Availability, Scaling, Backup, Disaster Recovery and Production Operations**.

That part should cover:

```text
GKE node pools
Horizontal Pod Autoscaler
Vertical Pod Autoscaler
Cluster autoscaling
PodDisruptionBudget
Multi-zone deployment
Cloud SQL HA
Database backups
Point-in-time recovery
Application rollback
Disaster recovery
RTO / RPO
Load testing
Capacity planning
Zero-downtime deployments
Production runbooks
```

This will take the Zepto project from **"secure and monitored"** to **"resilient and operationally production-ready."**

