# Part 6: Create and Configure the GKE Cluster

Now we will take the **Zepto Quick Commerce** application from Docker and prepare the **Google Kubernetes Engine (GKE)** environment where our React frontend, Node.js backend, and MySQL database will run.

For this project, I recommend **GKE Standard** for the training lab because it lets students understand Kubernetes nodes, node pools, networking, workloads, and scaling more directly. Google currently recommends Autopilot for many production workloads, but Standard is useful when teaching Kubernetes administration. ([Google Cloud Documentation][1])

---

# 1. What We Are Going to Build

Our final architecture will be:

```text
                    Internet
                       │
                       ▼
                GKE LoadBalancer
                       │
                       ▼
              React Frontend Pods
                       │
                       ▼
              Node.js Backend Pods
                       │
                       ▼
                 MySQL Service
                       │
                       ▼
              MySQL Database Pod
                       │
                       ▼
              Persistent Disk
```

Later, GitHub Actions will automatically deploy new versions into this cluster.

---

# 2. GCP Resources

We will create/use:

```text
Google Cloud Project
        │
        ├── GKE Cluster
        │
        ├── Node Pool
        │
        ├── VPC Network
        │
        ├── Subnet
        │
        └── Kubernetes Workloads
```

---

# 3. Prerequisites

Before creating the cluster, install/configure:

* Google Cloud account
* Google Cloud project
* Billing enabled
* Google Cloud CLI (`gcloud`)
* `kubectl`
* Docker
* Git

Google's current GKE documentation requires the Kubernetes Engine API and an initialized/up-to-date Google Cloud CLI for CLI-based cluster management. ([Google Cloud Documentation][2])

---

# Step 1: Verify Google Cloud CLI

Open PowerShell or Command Prompt.

```powershell
gcloud --version
```

You should see something similar to:

```text
Google Cloud SDK
gcloud version ...
```

If you already have `gcloud`, update it:

```powershell
gcloud components update
```

---

# Step 2: Login to Google Cloud

```powershell
gcloud auth login
```

A browser will open.

Login using the Google account that has access to your GCP project. Google documents `gcloud auth login` as the standard CLI authentication flow. ([Google Cloud Documentation][3])

---

# Step 3: Check Your Projects

```powershell
gcloud projects list
```

Example:

```text
PROJECT_ID              NAME
-----------------------------------------
cloudtechnet-dev        Cloud Technet Dev
zepto-project           Zepto Project
```

---

# Step 4: Select Your Project

Suppose your project ID is:

```text
zepto-project-123
```

Run:

```powershell
gcloud config set project zepto-project-123
```

Verify:

```powershell
gcloud config get-value project
```

Expected:

```text
zepto-project-123
```

> **Important:** Replace `zepto-project-123` with your actual GCP Project ID.

---

# Step 5: Enable Required APIs

Enable the Kubernetes Engine API:

```powershell
gcloud services enable container.googleapis.com
```

You can also enable Artifact Registry now because we'll use a container registry later:

```powershell
gcloud services enable artifactregistry.googleapis.com
```

Verify:

```powershell
gcloud services list --enabled
```

Look for:

```text
container.googleapis.com
artifactregistry.googleapis.com
```

---

# Step 6: Set Default Region

For this training project, let's use:

```text
asia-south1
```

This is the Mumbai region.

Run:

```powershell
gcloud config set compute/region asia-south1
```

Verify:

```powershell
gcloud config get-value compute/region
```

Expected:

```text
asia-south1
```

Google recommends setting a default region or zone to avoid location errors when using GKE commands. ([Google Cloud Documentation][2])

---

# Step 7: Choose the GKE Cluster Name

Let's use:

```text
zepto-gke-cluster
```

Our final configuration:

```text
Cluster:
    zepto-gke-cluster

Region:
    asia-south1

Mode:
    Standard

Node Count:
    2

Machine Type:
    e2-standard-2
```

For a learning environment, you can reduce the machine type/count if cost is a concern.

---

# Step 8: Create the GKE Cluster

Run:

```powershell
gcloud container clusters create zepto-gke-cluster `
    --region asia-south1 `
    --machine-type e2-standard-2 `
    --num-nodes 2 `
    --disk-type pd-balanced `
    --disk-size 30GB `
    --release-channel regular `
    --enable-ip-alias
```

### What does this command mean?

```text
gcloud container clusters create
```

Create a GKE cluster.

```text
zepto-gke-cluster
```

Cluster name.

```text
--region asia-south1
```

Create a regional cluster.

```text
--machine-type e2-standard-2
```

Node VM type.

```text
--num-nodes 2
```

Two nodes.

```text
--disk-type pd-balanced
```

Use balanced persistent disks.

```text
--disk-size 30GB
```

30 GB boot disk per node.

```text
--release-channel regular
```

Use GKE's Regular release channel.

```text
--enable-ip-alias
```

Enable VPC-native/IP alias networking.

---

# Step 9: Wait for Cluster Creation

You may see:

```text
Creating cluster zepto-gke-cluster...
```

Then:

```text
Creating cluster zepto-gke-cluster...done.
```

Cluster creation can take several minutes.

---

# Step 10: Verify the Cluster

```powershell
gcloud container clusters list
```

Expected:

```text
NAME                 LOCATION      STATUS
zepto-gke-cluster    asia-south1   RUNNING
```

---

# Step 11: Get GKE Credentials

This is a **very important step**.

Your local `kubectl` needs credentials to communicate with the GKE cluster.

Run:

```powershell
gcloud container clusters get-credentials zepto-gke-cluster `
    --region asia-south1
```

Google's current documentation states that `get-credentials` updates your kubeconfig with the cluster endpoint and credentials so `kubectl` can communicate with that GKE cluster. ([Google Cloud Documentation][4])

You should see something similar to:

```text
Fetching cluster endpoint and auth data.
kubeconfig entry generated for zepto-gke-cluster.
```

---

# Step 12: Verify kubectl

Run:

```powershell
kubectl version --client
```

Then:

```powershell
kubectl cluster-info
```

Expected:

```text
Kubernetes control plane is running at ...
```

Google also recommends `kubectl cluster-info` as a way to verify authentication/access to the Kubernetes API server. ([Google Cloud Documentation][3])

---

# Step 13: Check Current Kubernetes Context

```powershell
kubectl config current-context
```

You should get a context similar to:

```text
gke_zepto-project-123_asia-south1_zepto-gke-cluster
```

This tells you that your local `kubectl` is connected to the Zepto GKE cluster.

---

# Step 14: Check Kubernetes Nodes

This is one of the most important verification commands:

```powershell
kubectl get nodes
```

Expected:

```text
NAME                                      STATUS   ROLES
gke-zepto-gke-cluster-xxxxx               Ready    <none>
gke-zepto-gke-cluster-yyyyy               Ready    <none>
```

The important value is:

```text
STATUS = Ready
```

---

# Step 15: Get More Node Information

```powershell
kubectl get nodes -o wide
```

You will see:

```text
NAME
STATUS
ROLES
AGE
VERSION
INTERNAL-IP
EXTERNAL-IP
OS-IMAGE
KERNEL-VERSION
CONTAINER-RUNTIME
```

---

# Step 16: Check Cluster Information

```powershell
kubectl cluster-info
```

Then:

```powershell
kubectl get namespaces
```

Expected namespaces include:

```text
default
kube-system
kube-public
kube-node-lease
```

---

# Step 17: Create Application Namespace

We don't want to deploy the Zepto application into the default namespace.

Create:

```text
zepto
```

Run:

```powershell
kubectl create namespace zepto
```

Verify:

```powershell
kubectl get namespaces
```

You should see:

```text
zepto
```

---

# Step 18: Set Zepto as Your Current Namespace

You can configure the current context:

```powershell
kubectl config set-context --current --namespace=zepto
```

Verify:

```powershell
kubectl config view --minify --output 'jsonpath={..namespace}'
```

Expected:

```text
zepto
```

Now commands such as:

```powershell
kubectl get pods
```

will automatically operate against the `zepto` namespace.

---

# Step 19: Test the Cluster

Before deploying Zepto, let's deploy a simple NGINX test application.

```powershell
kubectl create deployment nginx-test `
    --image=nginx:alpine
```

Check:

```powershell
kubectl get deployments
```

Expected:

```text
NAME         READY
nginx-test   1/1
```

Check pods:

```powershell
kubectl get pods
```

Expected:

```text
nginx-test-xxxxx   1/1   Running
```

---

# Step 20: Delete Test Application

We don't need this test application.

```powershell
kubectl delete deployment nginx-test
```

Verify:

```powershell
kubectl get pods
```

Expected:

```text
No resources found
```

---

# Step 21: Check GKE Nodes from GCP

You can also verify the cluster from the Google Cloud Console.

Go to:

[Google Cloud Console](https://console.cloud.google.com/?utm_source=chatgpt.com)

Then:

```text
Google Cloud Console
        ↓
Kubernetes Engine
        ↓
Clusters
        ↓
zepto-gke-cluster
```

You should see:

```text
Cluster Status: Running

Nodes: 2

Location: asia-south1
```

---

# Step 22: Final GKE Architecture

At this stage we have:

```text
             Google Cloud Project
                     │
                     ▼
              GKE Cluster
        zepto-gke-cluster
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
       Node 1                 Node 2
          │                     │
          └──────────┬──────────┘
                     │
                     ▼
              Namespace
                 zepto
```

Nothing from the actual Zepto application has been deployed yet.

That's intentional.

---

# Step 23: Verify Everything

Run these commands one by one:

### GCP Project

```powershell
gcloud config get-value project
```

### Cluster

```powershell
gcloud container clusters list
```

### Kubernetes Context

```powershell
kubectl config current-context
```

### Cluster

```powershell
kubectl cluster-info
```

### Nodes

```powershell
kubectl get nodes
```

### Namespace

```powershell
kubectl get namespaces
```

### Current Namespace

```powershell
kubectl get pods
```

---

# Expected Final Result

```text
GCP Project
     │
     ▼
GKE Cluster
zepto-gke-cluster
     │
     ├── Node 1
     │
     └── Node 2
          │
          ▼
      Namespace
         zepto
```

---

# Important: Do NOT Deploy MySQL Yet

At this stage, don't manually deploy the MySQL container.

In the next module we'll create Kubernetes manifests for:

```text
kubernetes/
│
├── namespace.yaml
│
├── mysql/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── pvc.yaml
│
├── backend/
│   ├── deployment.yaml
│   └── service.yaml
│
└── frontend/
    ├── deployment.yaml
    └── service.yaml
```

This will allow Kubernetes to manage the complete application.

---

# What We Have Completed

```text
Part 1
GitHub Repository
        ↓
Part 2
React Frontend
        ↓
Part 3
Node.js Backend
        ↓
Part 4
MySQL Database
        ↓
Part 5
Docker Images
        ↓
Part 6
GKE Cluster              ✅
        ↓
Part 7
Kubernetes Manifests     ← NEXT
        ↓
Part 8
GitHub Actions CI/CD
        ↓
Part 9
Production Deployment
```

## One Important Change for Your Project

Earlier we used **Docker Hub** for the images. For the eventual GKE + GitHub Actions implementation, I recommend switching to **Google Artifact Registry** rather than Docker Hub. It integrates directly with GCP IAM and avoids putting Docker Hub credentials into the deployment pipeline.

So the eventual flow will be:

```text
GitHub
   ↓
GitHub Actions
   ↓
Docker Build
   ↓
Google Artifact Registry
   ↓
GKE
   ↓
Zepto Quick Commerce
```



