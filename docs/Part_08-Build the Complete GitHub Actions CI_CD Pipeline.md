# Part 8 — Build the Complete GitHub Actions CI/CD Pipeline

Now we will connect everything we have built so far:

```text
Developer
   │
   ▼
GitHub Repository
   │
   ▼
GitHub Actions
   │
   ├── Test React
   ├── Test Node.js
   ├── Build Docker Images
   │
   ▼
Google Artifact Registry
   │
   ├── zepto-frontend
   └── zepto-backend
   │
   ▼
GKE Authentication
   │
   ▼
GKE Cluster
   │
   ├── Frontend
   ├── Backend
   └── MySQL
```

For this project, I recommend **GitHub OIDC + Google Workload Identity Federation**, not a GCP service-account JSON key. GitHub and Google recommend OIDC/WIF because it avoids storing a long-lived GCP credential in GitHub Secrets. ([GitHub Docs][1])

---

# 1. What Will Our Pipeline Do?

When you push code:

```text
git push
     │
     ▼
GitHub
     │
     ▼
GitHub Actions
     │
     ├── Checkout
     │
     ├── Frontend Test
     │
     ├── Backend Test
     │
     ├── Authenticate to GCP
     │
     ├── Docker Build
     │
     ├── Docker Push
     │
     ├── Get GKE Credentials
     │
     ├── kubectl apply
     │
     └── Verify Deployment
```

---

# 2. Final CI/CD Architecture

```text
                  GitHub
                     │
                git push
                     │
                     ▼
              GitHub Actions
                     │
           ┌─────────┴─────────┐
           │                   │
           ▼                   ▼
       Frontend             Backend
        Tests                 Tests
           │                   │
           └─────────┬─────────┘
                     │
                     ▼
             Google OIDC Token
                     │
                     ▼
        Workload Identity Federation
                     │
                     ▼
             Google Service Account
                     │
          ┌──────────┴───────────┐
          │                      │
          ▼                      ▼
   Artifact Registry             GKE
          │                      │
          ▼                      ▼
   Docker Images             Kubernetes
```

---

# 3. Our Existing GCP Information

From your previous steps, we already know:

```text
GCP Project ID:
zepto-ecommerce-class-505916

GKE Cluster:
zepto-gke-cluster

GKE Region:
asia-south1

Artifact Registry:
zepto-repo

Backend Image:
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend:v1.3
```

We will use the same Artifact Registry for the frontend:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend:<tag>
```

---

# 4. Before Creating the Pipeline

We need four things configured in GCP:

```text
1. Artifact Registry
2. GitHub Workload Identity Pool
3. GitHub Workload Identity Provider
4. GitHub Actions Service Account
```

---

# Part A — Configure Google Cloud Authentication

## 5. Enable Required APIs

Run:

```powershell
gcloud services enable `
  iamcredentials.googleapis.com `
  sts.googleapis.com `
  artifactregistry.googleapis.com `
  container.googleapis.com
```

Verify:

```powershell
gcloud services list --enabled
```

---

# 6. Create GitHub Actions Service Account

We'll create:

```text
github-actions-zepto
```

Run:

```powershell
gcloud iam service-accounts create github-actions-zepto `
  --project=zepto-ecommerce-class-505916 `
  --display-name="GitHub Actions Zepto CI/CD"
```

Verify:

```powershell
gcloud iam service-accounts list `
  --project=zepto-ecommerce-class-505916
```

You should see:

```text
github-actions-zepto@zepto-ecommerce-class-505916.iam.gserviceaccount.com
```

We'll call this:

```text
SERVICE_ACCOUNT
```

---

# 7. Give the Service Account Artifact Registry Permission

GitHub Actions needs to push Docker images.

Grant:

```text
Artifact Registry Writer
```

Run:

```powershell
gcloud projects add-iam-policy-binding zepto-ecommerce-class-505916 `
  --member="serviceAccount:github-actions-zepto@zepto-ecommerce-class-505916.iam.gserviceaccount.com" `
  --role="roles/artifactregistry.writer"
```

This allows:

```text
GitHub Actions
       │
       ▼
Artifact Registry
       │
       ├── Push frontend
       └── Push backend
```

Google recommends appropriate Artifact Registry permissions for the identity that pushes images. ([Google Cloud Documentation][2])

---

# 8. Give the Service Account GKE Access

The workflow also needs to obtain GKE credentials.

Grant Cluster Viewer:

```powershell
gcloud projects add-iam-policy-binding zepto-ecommerce-class-505916 `
  --member="serviceAccount:github-actions-zepto@zepto-ecommerce-class-505916.iam.gserviceaccount.com" `
  --role="roles/container.clusterViewer"
```

The `get-gke-credentials` action documents `roles/container.clusterViewer` as the minimum Google Cloud role needed to view the GKE cluster. ([GitHub][3])

But that's only the Google Cloud API permission.

We also need to authorize the identity to perform Kubernetes operations inside the cluster.

We'll do that shortly.

---

# 9. Create Workload Identity Pool

Create:

```text
github-pool
```

Run:

```powershell
gcloud iam workload-identity-pools create github-pool `
  --project=zepto-ecommerce-class-505916 `
  --location=global `
  --display-name="GitHub Actions Pool"
```

Verify:

```powershell
gcloud iam workload-identity-pools list `
  --project=zepto-ecommerce-class-505916 `
  --location=global
```

---

# 10. Create GitHub OIDC Provider

We need to tell GCP:

> Trust OIDC tokens issued by GitHub.

Create provider:

```powershell
gcloud iam workload-identity-pools providers create-oidc github-provider `
  --project=zepto-ecommerce-class-505916 `
  --location=global `
  --workload-identity-pool=github-pool `
  --display-name="GitHub Actions Provider" `
  --issuer-uri="https://token.actions.githubusercontent.com/" `
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref"
```

GitHub's OIDC issuer is `https://token.actions.githubusercontent.com`, and GitHub recommends restricting the trust relationship with claims/conditions rather than allowing arbitrary repositories. ([GitHub Docs][1])

---

# 11. Find Your GCP Project Number

We need the **project number**, not the project ID, for the WIF provider resource name.

Run:

```powershell
gcloud projects describe zepto-ecommerce-class-505916 `
  --format="value(projectNumber)"
```

Example:

```text
390473865339
```

Save this value.

We'll call it:

```text
PROJECT_NUMBER
```

---

# 12. Find Your GitHub Repository Name

Your repository appears to be:

```text
zepto-quick-commerce
```

You need your GitHub username/organization.

For example:

```text
cloudtechnet/zepto-quick-commerce
```

The complete repository identifier is:

```text
YOUR_GITHUB_USERNAME/zepto-quick-commerce
```

Example:

```text
cloudtechnet/zepto-quick-commerce
```

---

# 13. Allow Only Your GitHub Repository

This is very important.

We don't want:

```text
Any GitHub repository
       ↓
GCP
       ↓
Your resources
```

We want:

```text
YOUR REPOSITORY
       ↓
GitHub OIDC
       ↓
WIF
       ↓
GitHub Actions Service Account
```

Grant Workload Identity User:

```powershell
gcloud iam service-accounts add-iam-policy-binding `
  github-actions-zepto@zepto-ecommerce-class-505916.iam.gserviceaccount.com `
  --project=zepto-ecommerce-class-505916 `
  --role=roles/iam.workloadIdentityUser `
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GITHUB_USERNAME/zepto-quick-commerce"
```

Replace:

```text
PROJECT_NUMBER
```

and:

```text
YOUR_GITHUB_USERNAME
```

with your actual values.

Google's WIF documentation recommends restricting access using attributes/principal sets rather than granting an entire pool broad access. ([Google Cloud Documentation][4])

---

# 14. Get the WIF Provider Name

Run:

```powershell
gcloud iam workload-identity-pools providers describe github-provider `
  --project=zepto-ecommerce-class-505916 `
  --location=global `
  --workload-identity-pool=github-pool `
  --format="value(name)"
```

You will get:

```text
projects/390473865339/locations/global/workloadIdentityPools/github-pool/providers/github-provider
```

Save this.

This is your:

```text
WIF_PROVIDER
```

Important: the GitHub `auth` action needs the **full provider path**, including `/providers/github-provider`. ([GitHub][5])

---

# 15. Test the Service Account IAM Configuration

You can check:

```powershell
gcloud iam service-accounts get-iam-policy `
  github-actions-zepto@zepto-ecommerce-class-505916.iam.gserviceaccount.com
```

Look for:

```text
roles/iam.workloadIdentityUser
```

and your GitHub repository principal.

---

# Part B — Configure GKE Kubernetes Permissions

## 16. Why Do We Need Two Types of Permissions?

This is an important DevOps concept.

GitHub Actions needs:

### Google Cloud permission

```text
Can I access the GKE cluster?
```

and:

### Kubernetes permission

```text
Can I deploy resources inside the cluster?
```

They are different authorization layers.

```text
GitHub Actions
      │
      ▼
Google IAM
      │
      ▼
GKE Cluster
      │
      ▼
Kubernetes RBAC
      │
      ▼
Deployments / Services / Secrets
```

---

# 17. Create Kubernetes ServiceAccount

We'll use a Kubernetes ServiceAccount:

```text
github-actions
```

Create:

```text
kubernetes/github-actions-rbac.yaml
```

For the initial training pipeline, use:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: github-actions
  namespace: zepto

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: github-actions-deployer
  namespace: zepto

rules:
  - apiGroups: [""]
    resources:
      - pods
      - services
      - configmaps
      - secrets
      - persistentvolumeclaims
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  - apiGroups: ["apps"]
    resources:
      - deployments
      - replicasets
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

  - apiGroups: ["networking.k8s.io"]
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: github-actions-deployer
  namespace: zepto

subjects:
  - kind: ServiceAccount
    name: github-actions
    namespace: zepto

roleRef:
  kind: Role
  name: github-actions-deployer
  apiGroup: rbac.authorization.k8s.io
```

Apply:

```powershell
kubectl apply -f kubernetes/github-actions-rbac.yaml
```

Verify:

```powershell
kubectl get role -n zepto
kubectl get rolebinding -n zepto
```

---

# 18. Important Note About GKE Authentication

For a modern GitHub Actions pipeline, don't create a long-lived Kubernetes token and put it into GitHub Secrets.

We'll use:

```text
GitHub OIDC
      ↓
Google WIF
      ↓
Google credentials
      ↓
get-gke-credentials
      ↓
kubectl
```

The Google `get-gke-credentials` action supports WIF and configures a kubeconfig for `kubectl`. ([GitHub][3])

---

# Part C — GitHub Repository Variables

## 19. Create GitHub Repository Variables

Go to your GitHub repository:

```text
Settings
   ↓
Secrets and variables
   ↓
Actions
   ↓
Variables
```

Create these **Repository Variables**:

| Variable         | Value                   |
| ---------------- | ----------------------- |
| `GCP_PROJECT_ID` | `zepto-ecommerce-class-505916` |
| `GAR_LOCATION`   | `asia-south1`           |
| `GAR_REPOSITORY` | `zepto-repo`            |
| `GKE_CLUSTER`    | `zepto-gke-cluster`     |
| `GKE_LOCATION`   | `asia-south1`           |
| `K8S_NAMESPACE`  | `zepto`                 |

---

# 20. Create GitHub Secrets

Go to:

```text
Settings
   ↓
Secrets and variables
   ↓
Actions
   ↓
Secrets
```

Create:

```text
WIF_PROVIDER
```

Value:

```text
projects/390473865339/locations/global/workloadIdentityPools/github-pool/providers/github-provider
```

And:

```text
WIF_SERVICE_ACCOUNT
```

Value:

```text
github-actions-zepto@zepto-ecommerce-class-505916.iam.gserviceaccount.com
```

We are **not** creating:

```text
GCP_SA_KEY
```

That's intentional.

We don't want a long-lived service-account JSON key in GitHub. GitHub's current OIDC guidance specifically uses `id-token: write` and short-lived federated authentication instead. ([GitHub Docs][1])

---

# Part D — Create GitHub Actions Workflow

## 21. Create Workflow Directory

Your repository should have:

```text
.github/
└── workflows/
```

Create:

```text
.github/workflows/deploy.yml
```

---

# 22. Complete CI/CD Pipeline

This workflow will:

```text
Checkout
   ↓
Test frontend
   ↓
Test backend
   ↓
Authenticate to GCP
   ↓
Configure Docker
   ↓
Build frontend
   ↓
Build backend
   ↓
Push images
   ↓
Get GKE credentials
   ↓
Deploy Kubernetes
   ↓
Wait for rollout
   ↓
Verify
```

Use the following workflow:

```yaml
name: Zepto Quick Commerce CI/CD

on:
  push:
    branches:
      - main
      - development

  workflow_dispatch:

permissions:
  contents: read
  id-token: write

env:
  PROJECT_ID: ${{ vars.GCP_PROJECT_ID }}
  GAR_LOCATION: ${{ vars.GAR_LOCATION }}
  GAR_REPOSITORY: ${{ vars.GAR_REPOSITORY }}
  GKE_CLUSTER: ${{ vars.GKE_CLUSTER }}
  GKE_LOCATION: ${{ vars.GKE_LOCATION }}
  K8S_NAMESPACE: ${{ vars.K8S_NAMESPACE }}

jobs:

  # ==========================================
  # JOB 1: TEST APPLICATION
  # ==========================================

  test:

    name: Test Application

    runs-on: ubuntu-latest

    steps:

      - name: Checkout Source Code
        uses: actions/checkout@v4

      # ----------------------------------------
      # Frontend Test
      # ----------------------------------------

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
          cache-dependency-path: frontend/package-lock.json

      - name: Install Frontend Dependencies
        working-directory: frontend
        run: npm ci

      - name: Build Frontend
        working-directory: frontend
        run: npm run build

      # ----------------------------------------
      # Backend Test
      # ----------------------------------------

      - name: Install Backend Dependencies
        working-directory: backend
        run: npm ci

      - name: Check Backend Application
        working-directory: backend
        run: node --check server.js


  # ==========================================
  # JOB 2: BUILD AND PUSH DOCKER IMAGES
  # ==========================================

  build-and-push:

    name: Build and Push Docker Images

    runs-on: ubuntu-latest

    needs: test

    permissions:
      contents: read
      id-token: write

    steps:

      - name: Checkout Source Code
        uses: actions/checkout@v4

      # ----------------------------------------
      # Authenticate to Google Cloud
      # ----------------------------------------

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v3
        with:
          project_id: ${{ env.PROJECT_ID }}
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      # ----------------------------------------
      # Setup gcloud
      # ----------------------------------------

      - name: Setup Google Cloud CLI
        uses: google-github-actions/setup-gcloud@v3

      # ----------------------------------------
      # Configure Docker
      # ----------------------------------------

      - name: Configure Docker for Artifact Registry
        run: |
          gcloud auth configure-docker \
            ${{ env.GAR_LOCATION }}-docker.pkg.dev \
            --quiet

      # ----------------------------------------
      # Docker Image Tag
      # ----------------------------------------

      - name: Set Image Tag
        run: |
          echo "IMAGE_TAG=${GITHUB_SHA::7}" >> $GITHUB_ENV

      # ----------------------------------------
      # Build Frontend Image
      # ----------------------------------------

      - name: Build Frontend Docker Image
        run: |
          docker build \
            -t ${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/zepto-frontend:${{ env.IMAGE_TAG }} \
            ./frontend

      # ----------------------------------------
      # Build Backend Image
      # ----------------------------------------

      - name: Build Backend Docker Image
        run: |
          docker build \
            -t ${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/zepto-backend:${{ env.IMAGE_TAG }} \
            ./backend

      # ----------------------------------------
      # Push Frontend
      # ----------------------------------------

      - name: Push Frontend Image
        run: |
          docker push \
            ${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/zepto-frontend:${{ env.IMAGE_TAG }}

      # ----------------------------------------
      # Push Backend
      # ----------------------------------------

      - name: Push Backend Image
        run: |
          docker push \
            ${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/zepto-backend:${{ env.IMAGE_TAG }}


  # ==========================================
  # JOB 3: DEPLOY TO GKE
  # ==========================================

  deploy:

    name: Deploy to GKE

    runs-on: ubuntu-latest

    needs: build-and-push

    permissions:
      contents: read
      id-token: write

    steps:

      - name: Checkout Source Code
        uses: actions/checkout@v4

      # ----------------------------------------
      # Authenticate to Google Cloud
      # ----------------------------------------

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v3
        with:
          project_id: ${{ env.PROJECT_ID }}
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      # ----------------------------------------
      # Setup Google Cloud CLI
      # ----------------------------------------

      - name: Setup Google Cloud CLI
        uses: google-github-actions/setup-gcloud@v3

      # ----------------------------------------
      # Get GKE Credentials
      # ----------------------------------------

      - name: Get GKE Credentials
        uses: google-github-actions/get-gke-credentials@v3
        with:
          cluster_name: ${{ env.GKE_CLUSTER }}
          location: ${{ env.GKE_LOCATION }}
          project_id: ${{ env.PROJECT_ID }}

      # ----------------------------------------
      # Set Image Tag
      # ----------------------------------------

      - name: Set Image Tag
        run: |
          echo "IMAGE_TAG=${GITHUB_SHA::7}" >> $GITHUB_ENV

      # ----------------------------------------
      # Update Backend Image
      # ----------------------------------------

      - name: Update Backend Image
        run: |
          kubectl -n ${{ env.K8S_NAMESPACE }} set image \
            deployment/zepto-backend \
            backend=${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/zepto-backend:${{ env.IMAGE_TAG }}

      # ----------------------------------------
      # Update Frontend Image
      # ----------------------------------------

      - name: Update Frontend Image
        run: |
          kubectl -n ${{ env.K8S_NAMESPACE }} set image \
            deployment/zepto-frontend \
            frontend=${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.GAR_REPOSITORY }}/zepto-frontend:${{ env.IMAGE_TAG }}

      # ----------------------------------------
      # Wait for Backend Rollout
      # ----------------------------------------

      - name: Verify Backend Deployment
        run: |
          kubectl rollout status \
            deployment/zepto-backend \
            -n ${{ env.K8S_NAMESPACE }} \
            --timeout=180s

      # ----------------------------------------
      # Wait for Frontend Rollout
      # ----------------------------------------

      - name: Verify Frontend Deployment
        run: |
          kubectl rollout status \
            deployment/zepto-frontend \
            -n ${{ env.K8S_NAMESPACE }} \
            --timeout=180s

      # ----------------------------------------
      # Verify Pods
      # ----------------------------------------

      - name: Verify Kubernetes Resources
        run: |
          kubectl get pods -n ${{ env.K8S_NAMESPACE }}
          kubectl get services -n ${{ env.K8S_NAMESPACE }}
          kubectl get ingress -n ${{ env.K8S_NAMESPACE }}
```

---

# 23. Why Are We Using Git Commit SHA as the Image Tag?

Instead of:

```text
v1
v2
v3
```

we use:

```text
GITHUB_SHA
```

Example:

```text
a83f921
```

Therefore:

```text
zepto-backend:a83f921
```

and:

```text
zepto-frontend:a83f921
```

This gives us a direct relationship:

```text
Git Commit
    │
    ▼
a83f921
    │
    ├── zepto-backend:a83f921
    │
    └── zepto-frontend:a83f921
```

This is much better for traceability.

---

# 24. One Important Change to Your Kubernetes Deployment

Previously your backend deployment had:

```yaml
image: asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend:v1.3
```

That's fine for manual testing.

But now GitHub Actions will dynamically update it.

The workflow runs:

```bash
kubectl set image deployment/zepto-backend ...
```

So every commit gets a new image:

```text
Commit A
   ↓
backend:a123456

Commit B
   ↓
backend:b789012

Commit C
   ↓
backend:c456789
```

---

# 25. Same for Frontend

Your Kubernetes Deployment should have the container name:

```yaml
containers:
  - name: frontend
```

because our pipeline runs:

```bash
kubectl set image deployment/zepto-frontend frontend=IMAGE
```

Similarly, backend must have:

```yaml
containers:
  - name: backend
```

because we run:

```bash
kubectl set image deployment/zepto-backend backend=IMAGE
```

Check:

```powershell
kubectl get deployment zepto-backend -n zepto -o yaml
```

and:

```powershell
kubectl get deployment zepto-frontend -n zepto -o yaml
```

---

# 26. Pipeline Flow in Detail

## Stage 1 — Developer

Developer changes:

```text
React
Node.js
Kubernetes
```

Then:

```bash
git add .
git commit -m "Add product API"
git push origin development
```

---

## Stage 2 — GitHub Actions

GitHub detects:

```text
push
```

and starts:

```text
Zepto Quick Commerce CI/CD
```

---

## Stage 3 — Testing

```text
Frontend
   ↓
npm ci
   ↓
npm run build
```

Backend:

```text
npm ci
   ↓
node --check
```

---

# 27. Stage 4 — GCP Authentication

GitHub generates:

```text
GitHub OIDC Token
```

Then:

```text
GitHub OIDC
     ↓
Google Workload Identity Federation
     ↓
GitHub Actions Service Account
```

No JSON key is stored in GitHub.

GitHub requires `id-token: write` for the workflow/job to request the OIDC token. ([GitHub Docs][1])

---

# 28. Stage 5 — Docker Build

Frontend:

```text
frontend/Dockerfile
       ↓
Docker Build
       ↓
zepto-frontend:<commit-sha>
```

Backend:

```text
backend/Dockerfile
       ↓
Docker Build
       ↓
zepto-backend:<commit-sha>
```

---

# 29. Stage 6 — Artifact Registry

Images go to:

```text
asia-south1-docker.pkg.dev
```

Repository:

```text
zepto-repo
```

So:

```text
asia-south1-docker.pkg.dev/
    zepto-ecommerce-class-505916/
        zepto-repo/
            zepto-frontend:a83f921

asia-south1-docker.pkg.dev/
    zepto-ecommerce-class-505916/
        zepto-repo/
            zepto-backend:a83f921
```

Artifact Registry Docker image paths follow the structure of location, project, repository, and image path. ([Google Cloud Documentation][6])

---

# 30. Stage 7 — Connect to GKE

The pipeline uses:

```text
google-github-actions/get-gke-credentials
```

Then:

```bash
kubectl
```

can communicate with:

```text
zepto-gke-cluster
```

The action creates a kubeconfig for the workflow runner. ([GitHub][3])

---

# 31. Stage 8 — Kubernetes Deployment

GitHub Actions runs:

```bash
kubectl set image
```

Backend:

```text
Deployment
     ↓
New Image
     ↓
New ReplicaSet
     ↓
New Pods
```

Frontend does the same.

---

# 32. Rolling Update

Suppose currently:

```text
Backend v1
├── Pod 1
└── Pod 2
```

GitHub Actions deploys:

```text
Backend v2
```

Kubernetes gradually replaces the old Pods:

```text
Pod 1 v1
Pod 2 v1

       ↓

Pod 1 v2
Pod 2 v1

       ↓

Pod 1 v2
Pod 2 v2
```

This is a **rolling update**.

---

# 33. Stage 9 — Verify Deployment

The pipeline executes:

```bash
kubectl rollout status
```

If successful:

```text
deployment successfully rolled out
```

If unsuccessful:

```text
Workflow FAILED
```

This is important because GitHub Actions should not report success just because `kubectl set image` completed.

---

# 34. Your Final Repository Structure

After Part 8:

```text
zepto-quick-commerce/
│
├── architecture/
│
├── backend/
│   ├── config/
│   ├── controllers/
│   ├── middleware/
│   ├── models/
│   ├── routes/
│   ├── app.js
│   ├── server.js
│   ├── package.json
│   ├── Dockerfile
│   └── .dockerignore
│
├── frontend/
│   ├── src/
│   ├── public/
│   ├── package.json
│   ├── Dockerfile
│   ├── nginx.conf
│   └── .dockerignore
│
├── database/
│   ├── init.sql
│   ├── sample-data.sql
│   └── README.md
│
├── kubernetes/
│   │
│   ├── namespace.yaml
│   ├── secret.yaml
│   ├── github-actions-rbac.yaml
│   │
│   ├── backend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   │
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   │
│   ├── mysql/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── pvc.yaml
│   │
│   ├── ingress/
│   │   └── ingress.yaml
│   │
│   └── hpa/
│
├── scripts/
│
├── .github/
│   └── workflows/
│       └── deploy.yml       ← NEW
│
├── .gitignore
├── LICENSE
└── README.md
```

---

# 35. Important Security Change

You currently have a Kubernetes Secret containing:

```yaml
DB_PASSWORD: "Root@123"
JWT_SECRET: "mySuperSecretKey"
```

Do **not** push that real `secret.yaml` to GitHub.

Your `.gitignore` should contain:

```gitignore
kubernetes/secret.yaml
```

Keep:

```text
kubernetes/secret.yaml
```

only on your local machine for now.

Later, we'll improve this architecture to:

```text
Google Secret Manager
        ↓
GKE
        ↓
Backend
```

---

# 36. Test the Pipeline

First commit the workflow:

```powershell
git checkout -b feature/github-actions-cicd
```

Then:

```powershell
git add .github/workflows/deploy.yml
```

Commit:

```powershell
git commit -m "Add GitHub Actions CI/CD pipeline"
```

Push:

```powershell
git push origin feature/github-actions-cicd
```

Create a Pull Request.

After merging into `development`, GitHub Actions should start automatically because our workflow has:

```yaml
on:
  push:
    branches:
      - main
      - development
```

You can also manually start it from:

```text
GitHub
   ↓
Actions
   ↓
Zepto Quick Commerce CI/CD
   ↓
Run workflow
```

---

# 37. What You Should See in GitHub Actions

```text
Zepto Quick Commerce CI/CD

✓ Checkout Source Code
✓ Setup Node.js
✓ Install Frontend Dependencies
✓ Build Frontend
✓ Install Backend Dependencies
✓ Check Backend Application

✓ Authenticate to Google Cloud
✓ Setup Google Cloud CLI
✓ Configure Docker
✓ Build Frontend Docker Image
✓ Build Backend Docker Image
✓ Push Frontend Image
✓ Push Backend Image

✓ Authenticate to Google Cloud
✓ Get GKE Credentials
✓ Update Backend Image
✓ Update Frontend Image
✓ Verify Backend Deployment
✓ Verify Frontend Deployment
✓ Verify Kubernetes Resources
```

---

# 38. Final CI/CD Flow

```text
                    DEVELOPER
                        │
                        │ git push
                        ▼
                 ┌─────────────┐
                 │   GitHub    │
                 └──────┬──────┘
                        │
                        ▼
              ┌──────────────────┐
              │ GitHub Actions   │
              └────────┬─────────┘
                       │
                 ┌─────┴─────┐
                 │           │
                 ▼           ▼
              React         Node.js
               Test          Test
                 │           │
                 └─────┬─────┘
                       │
                       ▼
                 GitHub OIDC
                       │
                       ▼
            Workload Identity
              Federation
                       │
                       ▼
              Google Cloud IAM
                       │
             ┌─────────┴─────────┐
             │                   │
             ▼                   ▼
       Artifact Registry        GKE
             │                   │
             ▼                   ▼
        Docker Images       Kubernetes
             │                   │
       ┌─────┴─────┐       ┌─────┴─────┐
       ▼           ▼       ▼           ▼
    Frontend     Backend  Frontend   Backend
                              │
                              ▼
                           MySQL
```

## One important correction before you run this

Your current GKE cluster is **Standard**, and your Kubernetes manifests currently contain a manually created `github-actions-rbac.yaml`. The exact authorization path for `kubectl` depends on the GKE cluster's authentication/RBAC configuration. So **don't troubleshoot the pipeline by blindly adding `cluster-admin`**. Start with the least privilege above; if the workflow authenticates successfully but `kubectl` gets `Forbidden`, we'll inspect the exact GKE authorization error and adjust only the required permissions.

Also, WIF/IAM changes can take several minutes to propagate; Google's current `auth` documentation notes that propagation can take up to about five minutes. ([GitHub][7])

