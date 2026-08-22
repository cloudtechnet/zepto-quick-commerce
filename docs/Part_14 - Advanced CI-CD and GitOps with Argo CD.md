# Part 14 — Advanced CI/CD and GitOps with Argo CD

At this stage, Zepto has:

```text
Part 1  → Architecture & GitHub
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
Part 12 → Security Hardening
Part 13 → HA, Scaling, Backup & DR
Part 14 → GitOps with Argo CD
```

The major change in Part 14 is:

### Current deployment model

```text
Developer
    |
    v
GitHub
    |
    v
GitHub Actions
    |
    v
Docker Build
    |
    v
Artifact Registry
    |
    v
kubectl apply
    |
    v
GKE
```

### New GitOps deployment model

```text
Developer
    |
    v
GitHub Application Repository
    |
    v
GitHub Actions
    |
    v
Build + Test + Security Scan
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

The critical difference is:

> **Git becomes the source of truth for the desired Kubernetes state.**

Argo CD continuously compares the desired state stored in Git with the live state in Kubernetes and can synchronize the cluster back to the Git-defined state.

---

# 14.1 What We Will Build

In Part 14 we will implement:

```text
[✓] GitOps repository
[✓] Dev environment
[✓] Staging environment
[✓] Production environment
[✓] Kustomize
[✓] Argo CD
[✓] Argo CD Application
[✓] GitHub Actions build pipeline
[✓] Automatic image push
[✓] GitOps manifest update
[✓] Argo CD synchronization
[✓] Drift detection
[✓] Deployment history
[✓] Rollback through Git
[✓] Production approval workflow
[✓] Environment promotion
[✓] Argo CD RBAC
[✓] GitHub branch protection
```

---

# 14.2 Why GitOps?

Previously GitHub Actions directly executed:

```text
kubectl apply
kubectl set image
```

This works, but creates a problem.

Suppose somebody manually runs:

```powershell
kubectl set image deployment/zepto-backend ...
```

Now:

```text
Git
 |
 | says v1.3
 v
GKE
 |
 | actually running v1.4
```

Git and Kubernetes disagree.

This is called:

```text
Configuration Drift
```

With Argo CD:

```text
Git
 |
 | desired state
 v
Argo CD
 |
 | compare
 v
GKE
```

If GKE differs from Git:

```text
Git != GKE
    |
    v
Argo CD detects drift
```

Argo CD can then synchronize the cluster back to the desired state.

---

# 14.3 Recommended Repository Strategy

For your Zepto project, I recommend **two repositories**.

## Repository 1 — Application

```text
zepto-quick-commerce
```

Contains:

```text
React
Node.js
MySQL schema
Dockerfiles
Tests
GitHub Actions
```

## Repository 2 — GitOps

```text
zepto-quick-commerce-gitops
```

Contains:

```text
Kubernetes manifests
Kustomize overlays
Environment configuration
Argo CD Applications
```

Architecture:

```text
+-----------------------------+
| zepto-quick-commerce        |
|                             |
| React                       |
| Node.js                     |
| Docker                      |
| Tests                       |
| GitHub Actions              |
+-------------+---------------+
              |
              | build image
              v
       Artifact Registry
              ^
              |
              | image reference
              |
+-------------+---------------+
| zepto-quick-commerce-gitops |
|                             |
| dev                         |
| staging                     |
| production                  |
| Argo CD                     |
+-------------+---------------+
              |
              v
           Argo CD
              |
              v
             GKE
```

---

# 14.4 Create GitOps Repository

Create a new GitHub repository:

```text
zepto-quick-commerce-gitops
```

Recommended:

```text
Private repository
```

because production configuration should generally not be exposed unnecessarily.

Clone it:

```powershell
git clone https://github.com/YOUR_ORG/zepto-quick-commerce-gitops.git
```

Enter:

```powershell
cd zepto-quick-commerce-gitops
```

---

# 14.5 GitOps Repository Structure

Create:

```text
zepto-quick-commerce-gitops/
|
+-- apps/
|   |
|   +-- zepto/
|       |
|       +-- base/
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
|   |
|   +-- applications/
|
+-- README.md
```

---

# 14.6 Why Kustomize?

You currently have:

```text
deployment.yaml
service.yaml
ingress.yaml
```

But dev, staging and production need different:

```text
replicas
images
resources
domains
environment variables
```

Instead of copying manifests:

```text
dev/deployment.yaml
staging/deployment.yaml
production/deployment.yaml
```

Kustomize lets you maintain:

```text
Base
 +
Overlay
```

Kustomize is built into Kubernetes tooling and lets you customize manifests without modifying the base files.

---

# 14.7 Kustomize Architecture

```text
                 BASE
                  |
       +----------+----------+
       |          |          |
       v          v          v
      DEV      STAGING   PRODUCTION
```

Base:

```text
Common configuration
```

Overlay:

```text
Environment-specific configuration
```

---

# 14.8 Create Base Directory

```powershell
mkdir apps
mkdir apps\zepto
mkdir apps\zepto\base
```

Base structure:

```text
apps/
└── zepto/
    └── base/
        ├── deployment-backend.yaml
        ├── deployment-frontend.yaml
        ├── service-backend.yaml
        ├── service-frontend.yaml
        ├── ingress.yaml
        ├── namespace.yaml
        └── kustomization.yaml
```

---

# 14.9 Base Kustomization

Create:

```text
apps/zepto/base/kustomization.yaml
```

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1

kind: Kustomization

resources:

  - namespace.yaml

  - deployment-backend.yaml

  - deployment-frontend.yaml

  - service-backend.yaml

  - service-frontend.yaml

  - ingress.yaml
```

---

# 14.10 Base Backend Deployment

Example:

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
```

Notice:

```text
image: zepto-backend
```

There is no registry URL or tag here.

The overlay will supply it.

---

# 14.11 Base Frontend Deployment

```yaml
apiVersion: apps/v1

kind: Deployment

metadata:

  name: zepto-frontend

  namespace: zepto

spec:

  replicas: 3

  selector:

    matchLabels:

      app: zepto-frontend

  template:

    metadata:

      labels:

        app: zepto-frontend

    spec:

      containers:

        - name: frontend

          image: zepto-frontend

          ports:

            - containerPort: 80
```

---

# 14.12 Dev Overlay

Create:

```text
apps/zepto/overlays/dev/
```

Structure:

```text
dev/
├── kustomization.yaml
└── namespace-patch.yaml
```

---

# 14.13 Dev Kustomization

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1

kind: Kustomization

namespace: zepto-dev

resources:

  - ../../base

images:

  - name: zepto-backend

    newName: asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend

    newTag: dev

  - name: zepto-frontend

    newName: asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-frontend

    newTag: dev
```

---

# 14.14 Staging Overlay

Create:

```text
apps/zepto/overlays/staging/
```

`kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1

kind: Kustomization

namespace: zepto-staging

resources:

  - ../../base

images:

  - name: zepto-backend

    newName: asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend

    newTag: staging

  - name: zepto-frontend

    newName: asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-frontend

    newTag: staging
```

---

# 14.15 Production Overlay

Create:

```text
apps/zepto/overlays/production/
```

`kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1

kind: Kustomization

namespace: zepto

resources:

  - ../../base

images:

  - name: zepto-backend

    newName: asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend

    newTag: production

  - name: zepto-frontend

    newName: asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-frontend

    newTag: production
```

In the real GitOps flow, don't use mutable `production` tags. Use immutable Git SHA tags:

```text
a83f921
```

For example:

```yaml
newTag: a83f921
```

---

# 14.16 Important: Image Tags

Your current image is:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:v1.3
```

GitOps should eventually use:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:a83f921
```

This gives you:

```text
Git Commit
     |
     v
Docker Image
     |
     v
GKE
```

and makes rollback much easier.

---

# 14.17 Test Kustomize Locally

From the GitOps repository:

```powershell
kubectl kustomize apps/zepto/overlays/dev
```

You should see generated Kubernetes YAML.

For staging:

```powershell
kubectl kustomize apps/zepto/overlays/staging
```

Production:

```powershell
kubectl kustomize apps/zepto/overlays/production
```

---

# 14.18 Validate Before Argo CD

You can also run:

```powershell
kubectl apply `
  --dry-run=client `
  -k apps/zepto/overlays/dev
```

For production:

```powershell
kubectl apply `
  --dry-run=client `
  -k apps/zepto/overlays/production
```

This catches basic manifest problems before Argo CD sees them.

---

# 14.19 Create GitOps Branches

Recommended:

```text
main
```

contains production-ready configuration.

For changes:

```text
feature/update-backend-image
```

Then:

```text
Pull Request
     |
     v
Review
     |
     v
Merge
     |
     v
Argo CD
```

---

# 14.20 Install Argo CD

Argo CD is installed inside Kubernetes.

Create namespace:

```powershell
kubectl create namespace argocd
```

Install Argo CD using the current official installation instructions. The official Argo CD documentation provides the installation manifests and deployment procedures.

After installation:

```powershell
kubectl get pods -n argocd
```

You should see components such as:

```text
argocd-server
argocd-repo-server
argocd-application-controller
argocd-dex-server
argocd-redis
```

The exact component set can vary by Argo CD version/configuration.

---

# 14.21 Verify Argo CD

```powershell
kubectl get pods -n argocd
```

Everything should eventually show:

```text
Running
```

Check services:

```powershell
kubectl get svc -n argocd
```

---

# 14.22 Access Argo CD

For initial lab access, use port forwarding:

```powershell
kubectl port-forward svc/argocd-server `
  -n argocd `
  8080:443
```

Then open:

```text
https://localhost:8080
```

Do not expose the Argo CD API publicly just for convenience.

For production, protect it with HTTPS, authentication, network controls and appropriate RBAC.

---

# 14.23 Get Initial Admin Password

For initial bootstrap:

```powershell
argocd admin initial-password -n argocd
```

Depending on your installation/client version, you can also retrieve the initial Secret directly.

After first login:

```text
Change/remove the initial bootstrap credential
```

and use a proper identity provider or tightly controlled administrative accounts.

---

# 14.24 Install Argo CD CLI

Install the Argo CD CLI appropriate for your OS.

Verify:

```powershell
argocd version
```

Login through the forwarded endpoint:

```powershell
argocd login localhost:8080 --insecure
```

Then:

```powershell
argocd account get-user-info
```

---

# 14.25 Connect Argo CD to GitHub

Argo CD needs access to:

```text
zepto-quick-commerce-gitops
```

For a public repository, no Git credential is required.

For a private repository, configure repository credentials using an appropriate GitHub authentication mechanism.

Do not commit:

```text
GitHub token
PAT
SSH private key
```

into the GitOps repository.

---

# 14.26 Create Argo CD Project

Create:

```text
argocd/projects/zepto-project.yaml
```

```yaml
apiVersion: argoproj.io/v1alpha1

kind: AppProject

metadata:

  name: zepto

  namespace: argocd

spec:

  description: Zepto Quick Commerce

  sourceRepos:

    - "https://github.com/YOUR_ORG/zepto-quick-commerce-gitops.git"

  destinations:

    - namespace: zepto

      server: https://kubernetes.default.svc

    - namespace: zepto-staging

      server: https://kubernetes.default.svc

    - namespace: zepto-dev

      server: https://kubernetes.default.svc

  clusterResourceWhitelist:

    - group: ""

      kind: Namespace

  namespaceResourceWhitelist:

    - group: "*"

      kind: "*"
```

Replace:

```text
YOUR_ORG
```

with your GitHub organization/user.

---

# 14.27 Why Argo CD Project?

It limits:

```text
Which Git repositories?
        |
        v
Which clusters?
        |
        v
Which namespaces?
        |
        v
Which resources?
```

This is another least-privilege control.

---

# 14.28 Create Dev Application

Create:

```text
argocd/applications/zepto-dev.yaml
```

```yaml
apiVersion: argoproj.io/v1alpha1

kind: Application

metadata:

  name: zepto-dev

  namespace: argocd

spec:

  project: zepto

  source:

    repoURL: https://github.com/YOUR_ORG/zepto-quick-commerce-gitops.git

    targetRevision: main

    path: apps/zepto/overlays/dev

  destination:

    server: https://kubernetes.default.svc

    namespace: zepto-dev

  syncPolicy:

    automated:

      prune: true

      selfHeal: true

    syncOptions:

      - CreateNamespace=true
```

---

# 14.29 What Does `selfHeal` Mean?

Suppose Git says:

```text
backend image = a83f921
```

but someone manually changes Kubernetes:

```text
backend image = b921f88
```

Argo CD sees:

```text
Git ≠ Cluster
```

Because:

```yaml
selfHeal: true
```

Argo CD can reconcile the live cluster back to the Git-defined state.

---

# 14.30 What Does `prune` Mean?

Suppose you delete a Kubernetes manifest from Git.

Without pruning:

```text
Git
 |
 | resource removed
 v
Argo CD
 |
 v
Old resource may remain
```

With:

```yaml
prune: true
```

Argo CD can remove resources that are no longer defined by the application.

Use this carefully, particularly for production resources.

---

# 14.31 Create Staging Application

```text
argocd/applications/zepto-staging.yaml
```

```yaml
apiVersion: argoproj.io/v1alpha1

kind: Application

metadata:

  name: zepto-staging

  namespace: argocd

spec:

  project: zepto

  source:

    repoURL: https://github.com/YOUR_ORG/zepto-quick-commerce-gitops.git

    targetRevision: main

    path: apps/zepto/overlays/staging

  destination:

    server: https://kubernetes.default.svc

    namespace: zepto-staging

  syncPolicy:

    automated:

      prune: true

      selfHeal: true

    syncOptions:

      - CreateNamespace=true
```

---

# 14.32 Production Application

For production, I recommend **manual synchronization initially**.

Create:

```text
argocd/applications/zepto-production.yaml
```

```yaml
apiVersion: argoproj.io/v1alpha1

kind: Application

metadata:

  name: zepto-production

  namespace: argocd

spec:

  project: zepto

  source:

    repoURL: https://github.com/YOUR_ORG/zepto-quick-commerce-gitops.git

    targetRevision: main

    path: apps/zepto/overlays/production

  destination:

    server: https://kubernetes.default.svc

    namespace: zepto

  syncPolicy:

    syncOptions:

      - CreateNamespace=true
```

Notice there is no:

```yaml
automated:
```

for production.

---

# 14.33 Why Manual Production Sync?

Development:

```text
Git
 |
 v
Argo CD
 |
 v
Automatic deployment
```

Production:

```text
Git
 |
 v
Argo CD
 |
 v
Review
 |
 v
Manual Sync
 |
 v
Production
```

This gives you a production approval gate.

---

# 14.34 Apply Argo CD Projects

```powershell
kubectl apply -f argocd/projects/zepto-project.yaml
```

Then:

```powershell
kubectl apply -f argocd/applications/zepto-dev.yaml
```

```powershell
kubectl apply -f argocd/applications/zepto-staging.yaml
```

```powershell
kubectl apply -f argocd/applications/zepto-production.yaml
```

---

# 14.35 Check Applications

```powershell
kubectl get applications -n argocd
```

You should see:

```text
NAME               SYNC STATUS   HEALTH STATUS
zepto-dev          Synced        Healthy
zepto-staging      Synced        Healthy
zepto-production   Synced        Healthy
```

Initially production might show:

```text
OutOfSync
```

if it has not yet been manually synchronized.

---

# 14.36 Argo CD CLI

Check:

```powershell
argocd app list
```

Example:

```text
NAME              SYNC STATUS   HEALTH
zepto-dev         Synced        Healthy
zepto-staging     Synced        Healthy
zepto-production  Synced        Healthy
```

---

# 14.37 Sync Development

```powershell
argocd app sync zepto-dev
```

Then:

```powershell
argocd app get zepto-dev
```

---

# 14.38 Sync Staging

```powershell
argocd app sync zepto-staging
```

Then:

```powershell
argocd app get zepto-staging
```

---

# 14.39 Production Sync

For production:

```powershell
argocd app sync zepto-production
```

This should happen only after:

```text
CI passed
       |
       v
Staging passed
       |
       v
Smoke tests passed
       |
       v
Production approval
       |
       v
Argo CD Sync
```

---

# 14.40 New CI/CD Architecture

The old pipeline:

```text
GitHub
   |
   v
GitHub Actions
   |
   v
kubectl
   |
   v
GKE
```

becomes:

```text
GitHub Application Repository
            |
            v
       GitHub Actions
            |
     +------+------+
     |             |
     v             v
   Tests        Docker Build
                    |
                    v
             Artifact Registry
                    |
                    v
            Update GitOps Repo
                    |
                    v
             Argo CD detects
                    |
                    v
                  GKE
```

---

# 14.41 GitHub Actions Responsibility

GitHub Actions should now:

```text
[✓] Checkout source
[✓] Run tests
[✓] Build Docker image
[✓] Scan image
[✓] Push image
[✓] Update GitOps repository
```

It should **not** normally do:

```text
kubectl apply
```

for application deployment.

Argo CD owns that part.

---

# 14.42 GitHub Actions Example

Your application repository:

```text
.github/workflows/deploy.yml
```

could conceptually become:

```yaml
name: Zepto CI

on:

  push:

    branches:

      - main

permissions:

  contents: write

  id-token: write


jobs:

  build:

    runs-on: ubuntu-latest

    steps:

      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Backend Tests
        working-directory: backend
        run: |
          npm ci
          npm test

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WIF_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Configure Docker
        run: |
          gcloud auth configure-docker asia-south1-docker.pkg.dev

      - name: Build Backend
        run: |
          docker build \
            -t asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:${{ github.sha }} \
            ./backend

      - name: Push Backend
        run: |
          docker push \
            asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:${{ github.sha }}
```

---

# 14.43 Update GitOps Repository

After pushing the image, the workflow needs to update:

```text
apps/zepto/overlays/dev/kustomization.yaml
```

from:

```yaml
newTag: old-sha
```

to:

```yaml
newTag: NEW_GITHUB_SHA
```

One simple approach:

```bash
cd gitops

kustomize edit set image \
  zepto-backend=asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:${GITHUB_SHA}
```

Then:

```bash
git add .
git commit -m "Deploy backend ${GITHUB_SHA}"
git push
```

---

# 14.44 Better GitOps Promotion Model

Don't update production immediately.

Use:

```text
main application
       |
       v
Build image
       |
       v
Update DEV
       |
       v
Argo CD DEV
       |
       v
Tests
       |
       v
Promote STAGING
       |
       v
Argo CD STAGING
       |
       v
Smoke Tests
       |
       v
Pull Request
       |
       v
Promote PRODUCTION
       |
       v
Argo CD
       |
       v
Production
```

This is a much stronger CI/CD model.

---

# 14.45 GitOps Promotion

For example:

```text
Git SHA:

a83f921
```

Dev:

```yaml
newTag: a83f921
```

After successful testing:

```text
Staging:
newTag: a83f921
```

After approval:

```text
Production:
newTag: a83f921
```

The **same image** is promoted across environments.

This is important.

You don't rebuild a different image for production.

---

# 14.46 Build Once, Promote Many

Bad:

```text
DEV
 |
 +-- build image A

STAGING
 |
 +-- build image B

PRODUCTION
 |
 +-- build image C
```

Better:

```text
Source
 |
 v
Build once
 |
 v
Image a83f921
 |
 +--> DEV
 |
 +--> STAGING
 |
 +--> PRODUCTION
```

This ensures the artifact tested in staging is the artifact deployed to production.

---

# 14.47 Environment Structure

Your GitOps repository should now be:

```text
apps/
└── zepto/
    |
    +── base/
    |
    +── overlays/
        |
        +── dev/
        |
        +── staging/
        |
        +── production/
```

---

# 14.48 Environment Differences

## Development

```text
replicas: 1-2
small resources
dev domain
debug logging
automatic sync
```

## Staging

```text
replicas: 2-3
production-like configuration
staging domain
production-like tests
automatic/manual sync depending on policy
```

## Production

```text
replicas: 3+
HA
strict security
production domain
manual approval
monitoring
backup
```

---

# 14.49 Environment-Specific Replica Patch

For dev:

```yaml
apiVersion: apps/v1

kind: Deployment

metadata:

  name: zepto-backend

spec:

  replicas: 1
```

For staging:

```yaml
apiVersion: apps/v1

kind: Deployment

metadata:

  name: zepto-backend

spec:

  replicas: 2
```

Production:

```yaml
apiVersion: apps/v1

kind: Deployment

metadata:

  name: zepto-backend

spec:

  replicas: 3
```

---

# 14.50 Kustomize Patch

Example:

```text
apps/zepto/overlays/dev/backend-replicas.yaml
```

```yaml
apiVersion: apps/v1

kind: Deployment

metadata:

  name: zepto-backend

spec:

  replicas: 1
```

Then:

```yaml
patches:

  - path: backend-replicas.yaml
```

in the dev `kustomization.yaml`.

---

# 14.51 Production Domain

Production overlay can patch:

```text
zepto.example.com
```

while dev uses:

```text
dev.zepto.example.com
```

and staging:

```text
staging.zepto.example.com
```

---

# 14.52 Argo CD Drift Detection

Suppose Git says:

```text
backend image = a83f921
```

Someone manually executes:

```powershell
kubectl set image deployment/zepto-backend `
  backend=...:bad-version `
  -n zepto
```

Now:

```text
Git:
a83f921

GKE:
bad-version
```

Argo CD:

```text
OutOfSync
```

If self-healing is enabled:

```text
Argo CD
 |
 v
Restore Git state
```

---

# 14.53 Test Drift Detection

After deployment:

```powershell
kubectl get application zepto-dev -n argocd
```

Then manually modify a deployment in dev:

```powershell
kubectl scale deployment zepto-backend `
  --replicas=1 `
  -n zepto-dev
```

Argo CD should detect that the live state differs from the desired state if the application definition manages that replica count.

---

# 14.54 Observe Argo CD

```powershell
argocd app get zepto-dev
```

You may see:

```text
Sync Status: OutOfSync
```

Then Argo CD reconciles it.

After synchronization:

```text
Sync Status: Synced
Health: Healthy
```

---

# 14.55 Argo CD Application Health

Argo CD doesn't just track whether YAML was applied.

It can show application health:

```text
Healthy
Progressing
Degraded
Suspended
Missing
Unknown
```

This gives you a central deployment view.

---

# 14.56 Argo CD Dashboard

The UI should conceptually look like:

```text
+----------------------------------------------------+
|                Argo CD Applications                |
+----------------------------------------------------+
|                                                    |
| zepto-dev         Synced      Healthy              |
| zepto-staging     Synced      Healthy              |
| zepto-production  Synced      Healthy              |
|                                                    |
+----------------------------------------------------+
```

---

# 14.57 Argo CD RBAC

Don't give every user:

```text
admin
```

Use roles.

Example:

```text
Developer
 |
 +-- View applications
 +-- View logs/status

DevOps
 |
 +-- Sync dev/staging

Production Admin
 |
 +-- Sync production
```

Argo CD supports project-level and application-level access control.

---

# 14.58 Production Separation

Ideally:

```text
Developer
    |
    +--> DEV
    |
    +--> STAGING

Production Team
    |
    +--> PRODUCTION
```

This prevents accidental production deployments.

---

# 14.59 Production Git Branch Protection

Protect:

```text
main
```

Require:

```text
Pull Request
+
Review
+
CI checks
```

For production GitOps changes:

```text
Pull Request
       |
       v
Review
       |
       v
Merge
       |
       v
Argo CD detects change
       |
       v
Production Sync
```

---

# 14.60 GitOps Rollback

This is one of the biggest benefits.

Suppose production currently has:

```text
a83f921
```

You deploy:

```text
b921f88
```

Something goes wrong.

Instead of:

```powershell
kubectl rollout undo
```

you can revert the GitOps commit.

```text
GitOps history:

a83f921
   |
   v
b921f88
```

Revert:

```text
b921f88
   |
   X
   |
   v
a83f921
```

Argo CD sees the Git change and restores:

```text
a83f921
```

This gives you a complete Git-based audit trail.

---

# 14.61 GitOps Rollback Flow

```text
Production
    |
    v
Problem detected
    |
    v
GitOps commit identified
    |
    v
git revert
    |
    v
Pull Request
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
GKE rollback
```

---

# 14.62 Argo CD Notifications

You can later configure notifications for:

```text
Sync succeeded
Sync failed
Application degraded
Application out of sync
Deployment completed
```

Send notifications to:

```text
Slack
Email
Microsoft Teams
PagerDuty
```

For production, this connects your deployment system to the observability system from Part 11.

---

# 14.63 GitOps + Monitoring

Final flow:

```text
GitHub
   |
   v
Argo CD
   |
   v
GKE
   |
   +----------+
   |          |
   v          v
Prometheus  Cloud Logging
   |          |
   v          v
Grafana    Logs Explorer
   |
   v
Alerts
```

---

# 14.64 GitOps + Security

The complete security chain:

```text
Developer
    |
    v
GitHub PR
    |
    +--> Code Scan
    +--> Dependency Scan
    +--> Docker Scan
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
GKE
    |
    +--> RBAC
    +--> NetworkPolicy
    +--> Pod Security
    +--> Workload Identity
```

---

# 14.65 GitOps + HA

Now combine Part 13:

```text
Argo CD
   |
   v
GKE
   |
   +-- HPA
   |
   +-- Cluster Autoscaler
   |
   +-- PDB
   |
   +-- Multi-zone
   |
   +-- RollingUpdate
```

Therefore:

```text
GitOps
+
HA
+
Security
+
Observability
```

becomes a production-grade deployment platform.

---

# 14.66 What Happens When Developer Pushes Code?

This is the most important end-to-end workflow.

Developer changes:

```text
backend/controllers/productController.js
```

Then:

```powershell
git add .
git commit -m "Improve product API"
git push origin feature/product-api
```

---

# 14.67 Pull Request

GitHub:

```text
feature/product-api
       |
       v
Pull Request
       |
       +-- Unit Tests
       +-- Lint
       +-- Security Scan
       +-- Docker Build Test
```

Merge into:

```text
main
```

---

# 14.68 GitHub Actions

GitHub Actions:

```text
Checkout
   |
   v
npm test
   |
   v
Docker build
   |
   v
Security scan
   |
   v
Artifact Registry
```

Image:

```text
zepto-backend:a83f921
```

---

# 14.69 GitOps Update

GitHub Actions updates:

```text
apps/zepto/overlays/dev/kustomization.yaml
```

from:

```yaml
newTag: old-sha
```

to:

```yaml
newTag: a83f921
```

Then:

```text
GitOps repository
       |
       v
Commit
       |
       v
Push
```

---

# 14.70 Argo CD Detects Change

Argo CD:

```text
Git
 |
 | newTag = a83f921
 v
Argo CD
 |
 | compare
 v
GKE
```

Argo CD determines:

```text
OutOfSync
```

Then:

```text
Sync
```

---

# 14.71 GKE Deployment

Kubernetes performs:

```text
Old Pods
    |
    v
New Pods
    |
    v
Readiness checks
    |
    v
Traffic shifted
    |
    v
Old Pods terminated
```

---

# 14.72 Monitoring

Prometheus:

```text
CPU
Memory
Requests
Latency
5xx
Pod count
```

Cloud Logging:

```text
Application logs
Kubernetes logs
Errors
```

Grafana:

```text
Healthy
```

---

# 14.73 Complete GitOps Flow

```text
                    DEVELOPER
                        |
                        v
                GitHub Application
                        |
                        v
                   Pull Request
                        |
             +----------+----------+
             |                     |
             v                     v
           Tests              Security Scan
             |                     |
             +----------+----------+
                        |
                        v
                      Merge
                        |
                        v
                 GitHub Actions
                        |
                 +------+------+
                 |             |
                 v             v
              Docker        Tests
                 |
                 v
          Artifact Registry
                 |
                 v
            Update GitOps
                 |
                 v
          GitOps Repository
                 |
                 v
              Argo CD
                 |
                 v
                GKE
                 |
        +--------+--------+
        |                 |
        v                 v
     Prometheus       Cloud Logging
        |
        v
      Grafana
        |
        v
      Alerts
```

---

# 14.74 GitOps Repository Final Structure

After Part 14:

```text
zepto-quick-commerce-gitops/
|
+-- apps/
|   |
|   +-- zepto/
|       |
|       +-- base/
|       |   |
|       |   +-- namespace.yaml
|       |   +-- deployment-backend.yaml
|       |   +-- deployment-frontend.yaml
|       |   +-- service-backend.yaml
|       |   +-- service-frontend.yaml
|       |   +-- ingress.yaml
|       |   +-- kustomization.yaml
|       |
|       +-- overlays/
|           |
|           +-- dev/
|           |   +-- kustomization.yaml
|           |   +-- backend-replicas.yaml
|           |
|           +-- staging/
|           |   +-- kustomization.yaml
|           |   +-- backend-replicas.yaml
|           |
|           +-- production/
|               +-- kustomization.yaml
|               +-- backend-replicas.yaml
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
+-- README.md
```

---

# 14.75 Application Repository Structure

Your original repository remains:

```text
zepto-quick-commerce/
|
+-- frontend/
|
+-- backend/
|
+-- database/
|
+-- tests/
|
+-- monitoring/
|
+-- docs/
|
+-- .github/
|   |
|   +-- workflows/
|       +-- ci.yml
|       +-- build-image.yml
|
+-- Dockerfile
|
+-- README.md
```

The Kubernetes production manifests gradually move to:

```text
zepto-quick-commerce-gitops
```

This is the key GitOps change.

---

# 14.76 What Should Remain in Application Repo?

Keep:

```text
Dockerfile
application code
unit tests
integration tests
database schema
CI workflows
security scanning configuration
```

Move/centralize:

```text
Kubernetes deployment configuration
environment overlays
Argo CD Applications
production manifests
```

into:

```text
zepto-quick-commerce-gitops
```

---

# 14.77 What Should NOT Be Stored in GitOps?

Never commit:

```text
DB_PASSWORD
JWT_SECRET
GCP service-account JSON
GitHub PAT
TLS private key
Cloud credentials
```

Use the Secret Manager/Workload Identity approach established in Part 12.

---

# 14.78 Commit GitOps Repository

After creating the manifests:

```powershell
git add .
```

Commit:

```powershell
git commit -m "Add Zepto GitOps deployment structure"
```

Push:

```powershell
git push origin main
```

---

# 14.79 Validate Everything

Run:

```powershell
kubectl kustomize apps/zepto/overlays/dev
```

Then:

```powershell
kubectl kustomize apps/zepto/overlays/staging
```

Then:

```powershell
kubectl kustomize apps/zepto/overlays/production
```

Validate:

```powershell
kubectl apply `
  --dry-run=client `
  -k apps/zepto/overlays/production
```

Then check Argo CD:

```powershell
argocd app list
```

---

# 14.80 Part 14 Testing Checklist

## GitOps

```text
[ ] GitOps repository created
[ ] Kustomize base created
[ ] Dev overlay created
[ ] Staging overlay created
[ ] Production overlay created
```

## Argo CD

```text
[ ] Argo CD installed
[ ] Git repository connected
[ ] Argo CD Project created
[ ] Dev Application created
[ ] Staging Application created
[ ] Production Application created
```

## CI/CD

```text
[ ] GitHub Actions builds image
[ ] Image pushed to Artifact Registry
[ ] GitOps repository updated
[ ] Argo CD detects change
[ ] Dev automatically deployed
[ ] Staging promoted
[ ] Production manually approved
```

## Reliability

```text
[ ] HPA works
[ ] PDB works
[ ] Rolling update works
[ ] Rollback works
[ ] Multi-zone scheduling works
```

## Security

```text
[ ] WIF
[ ] RBAC
[ ] NetworkPolicy
[ ] Secret Manager
[ ] No credentials in Git
```

---

# 14.81 Test 1 — Git Push

Change:

```text
backend/
```

Push:

```powershell
git push
```

Expected:

```text
GitHub Actions
      |
      v
Docker image
      |
      v
Artifact Registry
      |
      v
GitOps commit
      |
      v
Argo CD
      |
      v
GKE
```

---

# 14.82 Test 2 — Verify Argo CD

```powershell
argocd app get zepto-dev
```

Expected:

```text
Sync Status: Synced
Health Status: Healthy
```

---

# 14.83 Test 3 — Verify GKE

```powershell
kubectl get pods -n zepto-dev
```

Then:

```powershell
kubectl get deployment -n zepto-dev
```

Then:

```powershell
kubectl get service -n zepto-dev
```

---

# 14.84 Test 4 — Verify Image

```powershell
kubectl get deployment zepto-backend `
  -n zepto-dev `
  -o jsonpath="{.spec.template.spec.containers[0].image}"
```

Expected:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:a83f921
```

---

# 14.85 Test 5 — Test Drift

Manually modify the deployment:

```powershell
kubectl scale deployment zepto-backend `
  --replicas=1 `
  -n zepto-dev
```

Then:

```powershell
argocd app get zepto-dev
```

If the desired state is three replicas:

```text
OutOfSync
```

Argo CD should reconcile it depending on your sync policy.

---

# 14.86 Test 6 — Rollback

Create a bad GitOps commit:

```text
newTag: BAD_VERSION
```

Push.

Argo CD deploys it.

Observe:

```text
Health: Degraded
```

Then revert the GitOps commit:

```powershell
git revert COMMIT_ID
git push
```

Argo CD detects:

```text
Git changed
```

and restores the previous version.

---

# 14.87 Production Deployment Policy

I recommend:

### DEV

```text
Automatic
```

### STAGING

```text
Automatic or approval-based
```

### PRODUCTION

```text
Pull Request
+
Review
+
Argo CD manual sync
```

This gives you:

```text
Fast development
+
Controlled production
```

---

# 14.88 Final Architecture After Part 14

```text
                         DEVELOPER
                             |
                             v
                   GitHub Application Repo
                             |
                             v
                        Pull Request
                             |
                   +---------+---------+
                   |                   |
                   v                   v
                 Tests             Security
                   |                   |
                   +---------+---------+
                             |
                             v
                          main
                             |
                             v
                     GitHub Actions
                             |
                    +--------+--------+
                    |                 |
                    v                 v
               Docker Build       Tests/Scan
                    |
                    v
              Artifact Registry
                    |
                    v
              GitOps Repo Update
                    |
                    v
          zepto-quick-commerce-gitops
                    |
                    v
                 Argo CD
                    |
          +---------+---------+
          |         |         |
          v         v         v
         DEV     STAGING   PRODUCTION
          |         |         |
          +---------+---------+
                    |
                    v
                   GKE
                    |
       +------------+-------------+
       |            |             |
       v            v             v
   Frontend      Backend       Cloud SQL
       |            |
       |            +---- HPA
       |            +---- PDB
       |            +---- WIF
       |            +---- NetworkPolicy
       |
       +-------------------------+
                                 |
                 +---------------+---------------+
                 |                               |
                 v                               v
             Prometheus                    Cloud Logging
                 |                               |
                 v                               v
              Grafana                     Logs Explorer
```

---

# 14.89 Part 14 — Final Success Criteria

You have successfully completed Part 14 when:

```text
[✓] Separate GitOps repository created

[✓] Kubernetes manifests moved to GitOps model

[✓] Kustomize base created

[✓] Dev overlay created

[✓] Staging overlay created

[✓] Production overlay created

[✓] Argo CD installed in GKE

[✓] Argo CD connected to GitHub

[✓] Argo CD Project configured

[✓] Dev Application configured

[✓] Staging Application configured

[✓] Production Application configured

[✓] Dev automatic synchronization working

[✓] Production approval workflow working

[✓] Git commit produces Docker image

[✓] Docker image pushed to Artifact Registry

[✓] GitOps repository automatically updated

[✓] Argo CD detects Git changes

[✓] Argo CD deploys to GKE

[✓] Drift detection tested

[✓] Self-healing tested

[✓] Rollback through Git tested

[✓] Immutable image SHA tags used

[✓] Same image promoted DEV → STAGING → PROD

[✓] GitHub branch protection configured

[✓] Argo CD RBAC configured

[✓] Production deployment is controlled
```

---

# 14.90 The Zepto Platform Is Now Becoming Enterprise-Style

Your complete journey is now:

```text
                 ZEPTO QUICK COMMERCE
                         |
                         v
              +----------------------+
              |   React Frontend     |
              +----------+-----------+
                         |
                         v
              +----------------------+
              |   Node.js Backend    |
              +----------+-----------+
                         |
                         v
              +----------------------+
              |      MySQL/Cloud SQL |
              +----------------------+

                         |
                         v

              +----------------------+
              |       Docker         |
              +----------+-----------+
                         |
                         v
              +----------------------+
              |         GKE          |
              +----------+-----------+
                         |
            +------------+-------------+
            |            |             |
            v            v             v
           HA           HPA        NetworkPolicy
            |            |             |
            +------------+-------------+
                         |
                         v
                  Prometheus/Grafana
                         |
                         v
                  Cloud Logging
                         |
                         v
                    Observability

                         +
                         
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
                         GKE
```

## The key principle from Part 14

The most important transition is:

```text
OLD:

GitHub Actions
      |
      v
   kubectl
      |
      v
     GKE
```

to:

```text
NEW:

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

**GitHub Actions builds and publishes the software; GitOps defines what should run; Argo CD reconciles that desired state into GKE.**

The next logical step is **Part 15 — Progressive Delivery: Canary Deployments, Blue-Green Deployments, Argo Rollouts, Automated Rollback and SLO-Based Release Gates**. This builds directly on Part 14 and lets you move from a normal rolling deployment to controlled production releases such as **5% → 25% → 50% → 100% traffic**, while Prometheus/Grafana metrics determine whether the release should continue or automatically roll back.
