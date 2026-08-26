# Part 9 - Test the Complete Zepto CI/CD Pipeline End-to-End

Now we will validate the complete flow:

```text
Developer
   |
   | git push
   v
GitHub
   |
   v
GitHub Actions
   |
   +--> Test React
   +--> Test Node.js
   |
   +--> GitHub OIDC
   |       |
   |       v
   |   Workload Identity Federation
   |       |
   |       v
   |   Google Cloud
   |
   +--> Docker Build
   |
   +--> Artifact Registry
   |
   +--> GKE Credentials
   |
   +--> Update Kubernetes Deployment
   |
   v
Zepto Application
   |
   +--> React
   +--> Node.js
   +--> MySQL
```

We will also troubleshoot the most common:

* WIF errors
* Artifact Registry permission errors
* GKE authentication errors
* Kubernetes RBAC errors
* Image pull errors
* Readiness/liveness failures
* Backend-to-MySQL connection errors
* Ingress problems

---

# 9.1 Pre-Test Checklist

Before testing GitHub Actions, verify everything manually.

## Check GCP project

```powershell
gcloud config get-value project
```

Expected:

```text
zepto-ecommerce-class-505916
```

If not:

```powershell
gcloud config set project zepto-ecommerce-class-505916-505916
```

---

# 9.2 Verify GKE

```powershell
gcloud container clusters list
```

Expected:

```text
NAME                 LOCATION      STATUS
zepto-gke-cluster    asia-south1   RUNNING
```

Get credentials:

```powershell
gcloud container clusters get-credentials zepto-gke-cluster `
    --region asia-south1
```

Verify:

```powershell
kubectl get nodes
```

Expected:

```text
STATUS
Ready
Ready
```

---

# 9.3 Verify Zepto Namespace

```powershell
kubectl get namespace zepto
```

Then:

```powershell
kubectl get all -n zepto
```

You should eventually have:

```text
NAME                                  READY
pod/zepto-mysql-xxxxx                 1/1
pod/zepto-backend-xxxxx               1/1
pod/zepto-backend-yyyyy               1/1
pod/zepto-frontend-xxxxx              1/1
pod/zepto-frontend-yyyyy              1/1
```

---

# 9.4 Verify MySQL

```powershell
kubectl get pod -n zepto -l app=zepto-mysql
```

Expected:

```text
READY   STATUS
1/1     Running
```

Check logs:

```powershell
kubectl logs deployment/zepto-mysql -n zepto
```

---

# 9.5 Verify Backend

```powershell
kubectl get deployment zepto-backend -n zepto
```

Expected:

```text
READY   UP-TO-DATE   AVAILABLE
2/2     2            2
```

Check logs:

```powershell
kubectl logs deployment/zepto-backend -n zepto
```

Look for successful database connectivity.

---

# 9.6 Verify Frontend

```powershell
kubectl get deployment zepto-frontend -n zepto
```

Expected:

```text
READY   UP-TO-DATE   AVAILABLE
2/2     2            2
```

---

# 9.7 Verify Services

```powershell
kubectl get services -n zepto
```

Expected:

```text
NAME             TYPE
zepto-mysql      ClusterIP
zepto-backend    ClusterIP
zepto-frontend   ClusterIP
```

This is important.

The MySQL and backend services should **not** be public LoadBalancers.

---

# 9.8 Verify Ingress

```powershell
kubectl get ingress -n zepto
```

You should eventually see:

```text
NAME            CLASS   HOSTS   ADDRESS
zepto-ingress   ...     *       XX.XX.XX.XX
```

The `ADDRESS` is the external IP.

---

# 9.9 Test Backend Internally First

Before testing the external application, test the backend inside Kubernetes.

Run:

```powershell
kubectl run curl-test `
    --image=curlimages/curl `
    --rm -it `
    --restart=Never `
    -n zepto `
    -- curl http://zepto-backend:5000/health
```

Expected:

```json
{
  "status": "SUCCESS",
  "database": "Connected"
}
```

This test proves:

```text
Backend
   |
   v
MySQL Service
   |
   v
MySQL
```

is working.

---

# 9.10 Test MySQL DNS

From the backend Pod:

```powershell
kubectl exec -it deployment/zepto-backend -n zepto -- sh
```

Then:

```sh
printenv | grep DB
```

Expected:

```text
DB_HOST=zepto-mysql
DB_PORT=3306
DB_USER=root
DB_NAME=zepto_db
```

Exit:

```sh
exit
```

---

# 9.11 Verify Kubernetes Secret

```powershell
kubectl get secret zepto-db-secret -n zepto
```

Expected:

```text
NAME               TYPE
zepto-db-secret    Opaque
```

Do **not** print the actual password into your terminal history or CI logs.

---

# 9.12 Verify Artifact Registry

List Docker images:

```powershell
gcloud artifacts docker images list `
    asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916-505916/zepto-repo
```

You should see repositories/images similar to:

```text
zepto-backend
zepto-frontend
```

For the backend:

```powershell
gcloud artifacts docker images list `
    asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916-505916/zepto-repo/zepto-backend
```

---

# 9.13 Verify Current Backend Image

Run:

```powershell
kubectl get deployment zepto-backend `
    -n zepto `
    -o jsonpath="{.spec.template.spec.containers[0].image}"
```

Expected currently:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916-505916/zepto-repo/zepto-backend:v1.3
```

Do the same for frontend:

```powershell
kubectl get deployment zepto-frontend `
    -n zepto `
    -o jsonpath="{.spec.template.spec.containers[0].image}"
```

---

# 9.14 Verify GitHub WIF Configuration

Now we move to GitHub.

Go to:

```text
GitHub
  |
  v
Your Repository
  |
  v
Settings
  |
  v
Secrets and variables
  |
  v
Actions
```

You should have these **Variables**:

```text
GCP_PROJECT_ID
GAR_LOCATION
GAR_REPOSITORY
GKE_CLUSTER
GKE_LOCATION
K8S_NAMESPACE
```

Values:

```text
GCP_PROJECT_ID = zepto-ecommerce-class-505916-505916
GAR_LOCATION   = asia-south1
GAR_REPOSITORY = zepto-repo
GKE_CLUSTER    = zepto-gke-cluster
GKE_LOCATION   = asia-south1
K8S_NAMESPACE  = zepto
```

---

# 9.15 Verify GitHub Secrets

You should have:

```text
WIF_PROVIDER
WIF_SERVICE_ACCOUNT
```

The service account should be:

```text
github-actions-zepto@zepto-ecommerce-class-505916-505916.iam.gserviceaccount.com
```

---

# 9.16 Verify WIF Provider from GCP

Run:

```powershell
gcloud iam workload-identity-pools providers describe github-provider `
    --project=zepto-ecommerce-class-505916-505916 `
    --location=global `
    --workload-identity-pool=github-pool
```

Check:

```text
state: ACTIVE
```

If the provider isn't active, GitHub authentication will fail.

---

# 9.17 Verify WIF Pool

```powershell
gcloud iam workload-identity-pools describe github-pool `
    --project=zepto-ecommerce-class-505916 `
    --location=global
```

Expected:

```text
state: ACTIVE
```

---

# 9.18 Verify Service Account Binding

Run:

```powershell
gcloud iam service-accounts get-iam-policy `
    github-actions-zepto@zepto-ecommerce-class-505916.iam.gserviceaccount.com `
    --project=zepto-ecommerce-class-505916
```

Look for:

```text
roles/iam.workloadIdentityUser
```

and the GitHub repository principal.

The repository restriction should point to your actual repository:

```text
YOUR_GITHUB_USERNAME/zepto-quick-commerce
```

---

# 9.19 Important WIF Repository Check

This is one of the most common mistakes.

Suppose your GitHub repository is:

```text
mycompany/zepto-quick-commerce
```

Your IAM binding must use:

```text
attribute.repository/mycompany/zepto-quick-commerce
```

Not:

```text
attribute.repository/zepto-quick-commerce
```

Not:

```text
attribute.repository/YOUR_GITHUB_USERNAME/zepto-quick-commerce
```

if `YOUR_GITHUB_USERNAME` wasn't replaced.

---

# 9.20 First End-to-End Test

Now make a small harmless change.

For example:

```text
README.md
```

Add:

```text
CI/CD pipeline test
```

Check:

```powershell
git status
```

Then:

```powershell
git add README.md
```

Commit:

```powershell
git commit -m "Test Zepto CI/CD pipeline"
```

Push:

```powershell
git push origin main
```

If your deployment branch is `development`, push:

```powershell
git push origin development
```

---

# 9.21 Watch GitHub Actions

Go to:

```text
GitHub
  |
  v
Actions
```

You should see:

```text
Zepto Quick Commerce CI/CD
```

Open the latest workflow.

---

# 9.22 Expected Pipeline

The workflow should execute:

```text
Test Application
       |
       v
Build and Push Docker Images
       |
       v
Deploy to GKE
```

---

# 9.23 Stage 1 — Test Application

Expected:

```text
✓ Checkout Source Code

✓ Setup Node.js

✓ Install Frontend Dependencies

✓ Build Frontend

✓ Install Backend Dependencies

✓ Check Backend Application
```

If this succeeds:

```text
TEST = SUCCESS
```

---

# 9.24 Stage 2 — Authenticate to Google Cloud

Expected:

```text
Authenticate to Google Cloud
```

This step:

```yaml
uses: google-github-actions/auth@v3
```

uses:

```text
GitHub OIDC
     |
     v
WIF Provider
     |
     v
Google Service Account
```

---

# 9.25 Stage 3 — Configure Docker

Expected:

```text
Configure Docker for Artifact Registry
```

The command is:

```bash
gcloud auth configure-docker asia-south1-docker.pkg.dev
```

---

# 9.26 Stage 4 — Build Images

GitHub Actions builds:

```text
zepto-frontend:<commit-sha>
zepto-backend:<commit-sha>
```

Example:

```text
zepto-frontend:a83f921
zepto-backend:a83f921
```

---

# 9.27 Stage 5 — Push Images

Expected:

```text
Push Frontend Image
Push Backend Image
```

The backend path should be:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend:a83f921
```

---

# 9.28 Stage 6 — Get GKE Credentials

Expected:

```text
Get GKE Credentials
```

This step:

```yaml
uses: google-github-actions/get-gke-credentials@v3
```

creates Kubernetes credentials for the GitHub Actions runner.

---

# 9.29 Stage 7 — Update Backend

The pipeline executes:

```bash
kubectl set image deployment/zepto-backend \
backend=asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend:<TAG>
```

Kubernetes then starts a rolling update.

---

# 9.30 Stage 8 — Update Frontend

The pipeline executes:

```bash
kubectl set image deployment/zepto-frontend \
frontend=asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend:<TAG>
```

---

# 9.31 Stage 9 — Verify Rollout

GitHub Actions executes:

```bash
kubectl rollout status deployment/zepto-backend
```

and:

```bash
kubectl rollout status deployment/zepto-frontend
```

Expected:

```text
deployment "zepto-backend" successfully rolled out
deployment "zepto-frontend" successfully rolled out
```

---

# 9.32 Verify Deployment from Your Machine

After GitHub Actions finishes:

```powershell
kubectl get deployments -n zepto
```

Expected:

```text
NAME             READY
zepto-backend    2/2
zepto-frontend   2/2
zepto-mysql      1/1
```

---

# 9.33 Verify New Image

```powershell
kubectl get deployment zepto-backend `
    -n zepto `
    -o jsonpath="{.spec.template.spec.containers[0].image}"
```

You should now see:

```text
.../zepto-backend:<NEW_GIT_SHA>
```

This proves:

```text
Git Push
   |
   v
GitHub Actions
   |
   v
GKE Deployment Updated
```

---

# 9.34 Verify Pod Creation Time

```powershell
kubectl get pods -n zepto
```

Look at:

```text
AGE
```

The backend Pods should have a new age after deployment.

---

# 9.35 Verify Rollout History

```powershell
kubectl rollout history deployment/zepto-backend -n zepto
```

And:

```powershell
kubectl rollout history deployment/zepto-frontend -n zepto
```

---

# 9.36 Test External Application

Get Ingress IP:

```powershell
kubectl get ingress zepto-ingress -n zepto
```

Suppose:

```text
ADDRESS = 34.100.20.10
```

Open:

```text
http://34.100.20.10/
```

Expected:

```text
Zepto React Application
```

Backend:

```text
http://34.100.20.10/api/health
```

Expected:

```json
{
  "status": "SUCCESS",
  "database": "Connected"
}
```

---

# 9.37 End-to-End Verification

The final test should prove:

```text
Browser
   |
   v
Google Load Balancer
   |
   v
Ingress
   |
   +--------------------+
   |                    |
   v                    v
React                Node.js
Frontend              Backend
                         |
                         v
                       MySQL
```

And the deployment path should prove:

```text
Git Push
   |
   v
GitHub Actions
   |
   +--> Build
   |
   +--> Artifact Registry
   |
   +--> GKE
   |
   v
New Application Version
```

---

# 9.38 Troubleshooting — WIF Errors

## Error 1

```text
Failed to generate Google Cloud access token
```

Check:

```text
WIF_PROVIDER
```

It must be the complete provider name.

Example:

```text
projects/123456789012/locations/global/workloadIdentityPools/github-pool/providers/github-provider
```

---

## Error 2

```text
Permission denied on resource project
```

Check:

```text
WIF_SERVICE_ACCOUNT
```

Expected:

```text
github-actions-zepto@zepto-ecommerce-class-505916.iam.gserviceaccount.com
```

---

## Error 3

```text
The caller does not have permission
```

Check the service-account IAM policy:

```powershell
gcloud iam service-accounts get-iam-policy `
    github-actions-zepto@zepto-ecommerce-class-505916.iam.gserviceaccount.com `
    --project=zepto-ecommerce-class-505916
```

You need:

```text
roles/iam.workloadIdentityUser
```

---

# 9.39 WIF Repository Mismatch

Error can occur when the GitHub repository doesn't match the IAM condition.

Example actual repository:

```text
myuser/zepto-quick-commerce
```

But IAM binding:

```text
otheruser/zepto-quick-commerce
```

Result:

```text
Authentication FAILED
```

Fix the IAM binding to the actual repository.

---

# 9.40 WIF Provider Not Active

Check:

```powershell
gcloud iam workload-identity-pools providers describe github-provider `
    --project=zepto-ecommerce-class-505916 `
    --location=global `
    --workload-identity-pool=github-pool
```

Look for:

```text
state: ACTIVE
```

---

# 9.41 Troubleshooting — Artifact Registry

## Error

```text
denied: Permission denied
```

Check service account role:

```powershell
gcloud projects get-iam-policy zepto-ecommerce-class-505916 `
    --flatten="bindings[].members" `
    --filter="bindings.members:github-actions-zepto@zepto-ecommerce-class-505916.iam.gserviceaccount.com"
```

The service account needs:

```text
roles/artifactregistry.writer
```

---

# 9.42 Verify Artifact Registry Repository

```powershell
gcloud artifacts repositories list `
    --project=zepto-ecommerce-class-505916 `
    --location=asia-south1
```

Expected:

```text
zepto-repo
```

---

# 9.43 Verify Image Path

Correct:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend:TAG
```

Breakdown:

```text
asia-south1-docker.pkg.dev
        |
        +-- GCP project
        |      |
        |      +-- zepto-ecommerce-class-505916
        |
        +-- repository
        |      |
        |      +-- zepto-repo
        |
        +-- image
               |
               +-- zepto-backend
```

---

# 9.44 Troubleshooting — GKE Permission

## Error

```text
Permission denied while accessing GKE
```

Check:

```text
roles/container.clusterViewer
```

for the GitHub Actions service account.

However, note that this is only one layer.

There are two authorization layers:

```text
Google IAM
    |
    v
Can GitHub Actions access the GKE cluster?
    |
    v
Kubernetes RBAC
    |
    v
Can GitHub Actions modify resources?
```

Both must be correct.

---

# 9.45 Troubleshooting — Kubernetes RBAC

## Error

```text
Error from server (Forbidden)
```

Example:

```text
User cannot patch resource deployments
```

This means Kubernetes RBAC does not allow the required action.

Check:

```powershell
kubectl get role github-actions-deployer -n zepto
```

Check RoleBinding:

```powershell
kubectl get rolebinding github-actions-deployer -n zepto
```

---

# 9.46 Important GKE Authentication Detail

The GitHub Actions workflow authenticates to Google Cloud using:

```text
GitHub OIDC
```

But the Kubernetes API authorization is separate.

Therefore:

```text
Google Cloud authentication SUCCESS
```

does not automatically mean:

```text
Kubernetes authorization SUCCESS
```

---

# 9.47 Troubleshooting — ImagePullBackOff

If:

```powershell
kubectl get pods -n zepto
```

shows:

```text
ImagePullBackOff
```

run:

```powershell
kubectl describe pod POD_NAME -n zepto
```

Look at:

```text
Events
```

Common causes:

```text
Wrong image name
Wrong image tag
Artifact Registry access issue
Image does not exist
Node cannot access registry
```

---

# 9.48 Verify Image Exists

```powershell
gcloud artifacts docker images list `
    asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo
```

If the GitHub Actions image is:

```text
zepto-backend:a83f921
```

verify that tag exists.

---

# 9.49 Troubleshooting — CrashLoopBackOff

If:

```text
CrashLoopBackOff
```

run:

```powershell
kubectl logs POD_NAME -n zepto
```

Also:

```powershell
kubectl logs POD_NAME -n zepto --previous
```

Check:

```text
DB_HOST
DB_PORT
DB_USER
DB_PASSWORD
DB_NAME
PORT
```

---

# 9.50 Troubleshooting — Backend Health Probe

If backend Pods show:

```text
0/1
```

check:

```powershell
kubectl describe pod POD_NAME -n zepto
```

Look for:

```text
Readiness probe failed
```

The backend must expose:

```text
GET /health
```

on:

```text
port 5000
```

Test locally inside the Pod:

```powershell
kubectl exec -it POD_NAME -n zepto -- sh
```

Then:

```sh
wget -qO- http://localhost:5000/health
```

or if curl exists:

```sh
curl http://localhost:5000/health
```

---

# 9.51 Troubleshooting — MySQL Connection

If `/health` returns:

```json
{
  "status": "FAILED"
}
```

check:

```powershell
kubectl get service zepto-mysql -n zepto
```

Then:

```powershell
kubectl get endpoints zepto-mysql -n zepto
```

There should be an endpoint.

If there is no endpoint, check:

```powershell
kubectl get pods -n zepto -l app=zepto-mysql
```

---

# 9.52 Verify Backend Environment

```powershell
kubectl exec deployment/zepto-backend -n zepto -- printenv
```

Verify:

```text
DB_HOST=zepto-mysql
DB_PORT=3306
DB_USER=root
DB_NAME=zepto_db
```

Do not expose secrets unnecessarily in logs or screenshots.

---

# 9.53 Troubleshooting — Ingress Has No IP

Check:

```powershell
kubectl get ingress -n zepto
```

If:

```text
ADDRESS
```

is empty, inspect:

```powershell
kubectl describe ingress zepto-ingress -n zepto
```

Look at:

```text
Events
```

Ingress/load-balancer provisioning can take some time.

---

# 9.54 Troubleshooting — Frontend Works but API Fails

If:

```text
http://EXTERNAL-IP/
```

works but:

```text
http://EXTERNAL-IP/api/health
```

fails, check:

```powershell
kubectl get ingress -n zepto
```

Then:

```powershell
kubectl get service zepto-backend -n zepto
```

Then:

```powershell
kubectl get endpoints zepto-backend -n zepto
```

There should be backend Pod IPs.

---

# 9.55 Troubleshooting — React Calls Wrong API URL

Open browser developer tools:

```text
F12
  |
  v
Network
```

Check the request.

Wrong:

```text
http://localhost:5000/api/products
```

Correct production pattern:

```text
/api/products
```

React configuration:

```env
VITE_API_URL=/api
```

---

# 9.56 Troubleshooting — Pipeline Says Deployment Not Found

Error:

```text
deployment.apps "zepto-backend" not found
```

Check:

```powershell
kubectl get deployment -n zepto
```

Expected:

```text
zepto-backend
zepto-frontend
zepto-mysql
```

If the namespace is wrong, verify:

```yaml
namespace: zepto
```

The GitHub workflow must use:

```text
K8S_NAMESPACE=zepto
```

---

# 9.57 Troubleshooting — Container Name Not Found

Error:

```text
unable to find container named "backend"
```

Check:

```powershell
kubectl get deployment zepto-backend `
    -n zepto `
    -o jsonpath="{.spec.template.spec.containers[*].name}"
```

Expected:

```text
backend
```

For frontend:

```powershell
kubectl get deployment zepto-frontend `
    -n zepto `
    -o jsonpath="{.spec.template.spec.containers[*].name}"
```

Expected:

```text
frontend
```

---

# 9.58 Troubleshooting — Pipeline Succeeds but Application Doesn't Change

Check GitHub Actions image tag:

```text
a83f921
```

Then:

```powershell
kubectl get deployment zepto-backend `
    -n zepto `
    -o jsonpath="{.spec.template.spec.containers[0].image}"
```

If it still says:

```text
:v1.3
```

the deployment was not updated.

Check GitHub Actions:

```text
Update Backend Image
Update Frontend Image
```

---

# 9.59 Check Kubernetes Events

When debugging almost any deployment issue:

```powershell
kubectl get events -n zepto --sort-by=.lastTimestamp
```

This is one of the most useful troubleshooting commands.

---

# 9.60 Complete Diagnostic Command Set

Run:

```powershell
kubectl get nodes

kubectl get all -n zepto

kubectl get pvc -n zepto

kubectl get ingress -n zepto

kubectl get events -n zepto --sort-by=.lastTimestamp

kubectl get deployments -n zepto

kubectl get services -n zepto

kubectl get endpoints -n zepto
```

Backend:

```powershell
kubectl logs deployment/zepto-backend -n zepto
```

MySQL:

```powershell
kubectl logs deployment/zepto-mysql -n zepto
```

Frontend:

```powershell
kubectl logs deployment/zepto-frontend -n zepto
```

---

# 9.61 The Golden End-to-End Test

Perform this exact sequence.

## Step 1 — Check current version

```powershell
kubectl get deployment zepto-backend `
    -n zepto `
    -o jsonpath="{.spec.template.spec.containers[0].image}"
```

Example:

```text
zepto-backend:abc1234
```

---

## Step 2 — Make a code change

Example:

```text
backend/
```

Change something harmless, such as an API response message.

---

## Step 3 — Commit

```powershell
git add .
```

```powershell
git commit -m "Test automatic deployment"
```

---

## Step 4 — Push

```powershell
git push origin main
```

---

## Step 5 — GitHub Actions

Go to:

```text
GitHub → Actions
```

Wait for:

```text
Zepto Quick Commerce CI/CD
```

to become:

```text
SUCCESS
```

---

## Step 6 — Check New Image

On your machine:

```powershell
kubectl get deployment zepto-backend `
    -n zepto `
    -o jsonpath="{.spec.template.spec.containers[0].image}"
```

Expected:

```text
zepto-backend:<NEW_COMMIT_SHA>
```

---

## Step 7 — Check Pods

```powershell
kubectl get pods -n zepto
```

Expected:

```text
2/2 Running
```

for backend.

---

## Step 8 — Test Health

```text
http://EXTERNAL-IP/api/health
```

Expected:

```json
{
  "status": "SUCCESS",
  "database": "Connected"
}
```

---

## Step 9 — Test React

Open:

```text
http://EXTERNAL-IP/
```

The new application version should be visible.

---

# 9.62 Final Success Criteria

Part 9 is successful when all of these are true:

```text
[✓] GKE cluster RUNNING

[✓] Nodes Ready

[✓] Namespace zepto exists

[✓] MySQL Pod Running

[✓] MySQL PVC Bound

[✓] Backend Pods Running

[✓] Frontend Pods Running

[✓] Backend connects to MySQL

[✓] /health returns SUCCESS

[✓] Artifact Registry contains images

[✓] WIF authentication succeeds

[✓] GitHub Actions authentication succeeds

[✓] Docker images build successfully

[✓] Docker images push successfully

[✓] GKE credentials acquired

[✓] Kubernetes deployment updated

[✓] Rolling deployment succeeds

[✓] New image tag appears in GKE

[✓] Ingress has external IP

[✓] React application accessible

[✓] Backend API accessible

[✓] Git push automatically deploys new version
```

---

# 9.63 Final Zepto CI/CD Flow

```text
                         DEVELOPER
                             |
                             |
                       git push main
                             |
                             v
                        +---------+
                        |  GitHub |
                        +----+----+
                             |
                             v
                    +----------------+
                    | GitHub Actions |
                    +-------+--------+
                            |
             +--------------+--------------+
             |                             |
             v                             v
       Test Frontend                 Test Backend
             |                             |
             +--------------+--------------+
                            |
                            v
                    GitHub OIDC Token
                            |
                            v
               Workload Identity Federation
                            |
                            v
                Google Cloud Service Account
                            |
              +-------------+-------------+
              |                           |
              v                           v
      Artifact Registry                  GKE
              |                           |
       +------+-------+           +-------+-------+
       |              |           |               |
       v              v           v               v
Frontend Image   Backend Image  Frontend        Backend
                               Deployment      Deployment
                                                   |
                                                   v
                                                 MySQL
                                                   |
                                                   v
                                                PVC/Disk
```

---

# Part 9 Complete

At this point, the complete Zepto deployment lifecycle is:

```text
Part 1  → Architecture & GitHub Repository
Part 2  → React Frontend
Part 3  → Node.js Backend APIs
Part 4  → MySQL Schema & Seed Data
Part 5  → Dockerization
Part 6  → GKE Cluster
Part 7  → Kubernetes Manifests
Part 8  → GitHub Actions CI/CD
Part 9  → End-to-End Testing & Troubleshooting
```

The final target is:

```text
git push
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
GKE
   |
   v
Zepto Quick Commerce
```

**A successful Part 9 means a developer can make a Git push and the new Zepto application version is automatically built, stored in Artifact Registry, deployed to GKE, rolled out, and verified.**
'''


