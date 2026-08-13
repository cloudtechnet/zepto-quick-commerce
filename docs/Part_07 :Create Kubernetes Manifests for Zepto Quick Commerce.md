# Part 7 — Create Kubernetes Manifests for Zepto Quick Commerce

Now we will deploy the **Zepto Quick Commerce 3-tier application** into the GKE cluster created in Part 6.

We will create Kubernetes manifests for:

1. Namespace
2. Secret
3. MySQL PersistentVolumeClaim
4. MySQL Deployment
5. MySQL Service
6. Backend Deployment
7. Backend Service
8. Frontend Deployment
9. Frontend Service
10. Ingress

The final architecture will be:

```text
                         INTERNET
                            │
                            ▼
                  GKE External Load Balancer
                            │
                         Ingress
                            │
                            ▼
                  Frontend Service
                            │
                            ▼
                    React Pods
                            │
                     API Requests
                            │
                            ▼
                  Backend Service
                            │
                            ▼
                   Node.js Pods
                            │
                       MySQL Service
                            │
                            ▼
                    MySQL Pod
                            │
                            ▼
                  PersistentVolume
                            │
                            ▼
                 GCP Persistent Disk
```

GKE Ingress creates and manages a Google Cloud HTTP(S) load balancer for external traffic. For this project we'll use the GKE `gce` Ingress class. ([Google Cloud Documentation][1])

---

# 1. Important Change Before We Start

In Part 5, we built images such as:

```text
zepto-frontend:v1
zepto-backend:v1
```

Those images were local.

GKE cannot use images that exist only on your laptop.

So eventually we need:

```text
Docker Build
      ↓
Container Registry
      ↓
GKE
```

For this project, I recommend **Google Artifact Registry**:

```text
Artifact Registry

asia-south1-docker.pkg.dev

        ↓

zepto-frontend

zepto-backend
```

We will configure Artifact Registry properly in the GitHub Actions section.

For now, the Kubernetes YAML will use placeholders:

```text
YOUR_GCP_PROJECT_ID
```

---

# 2. Kubernetes Folder Structure

Your repository should now look like:

```text
zepto-quick-commerce/
│
├── frontend/
│
├── backend/
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
│   │
│   ├── mysql/
│   │   ├── pvc.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   │
│   ├── backend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   │
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   │
│   └── ingress/
│       └── ingress.yaml
│
└── .github/
    └── workflows/
```

---

# 3. Create the Namespace

Create:

```text
kubernetes/namespace.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: zepto
```

This gives us an isolated namespace:

```text
GKE Cluster
     │
     ├── kube-system
     │
     ├── default
     │
     └── zepto
           │
           ├── MySQL
           ├── Backend
           └── Frontend
```

---

# 4. Create Kubernetes Secret
Yes. I checked your folder structure in the screenshot. **Your current structure is correct**, and you should create `secret.yaml` directly inside the **`kubernetes`** folder.

## 4.1. Your Current Structure

From your screenshot, you have:

```text
zepto-quick-commerce/
│
├── architecture/
├── backend/
├── database/
├── docs/
├── frontend/
│
├── kubernetes/
│   │
│   ├── backend/
│   ├── frontend/
│   ├── hpa/
│   ├── ingress/
│   ├── mysql/
│   │
│   └── namespace.yaml    ← Already here
│
├── scripts/
├── .gitignore
├── LICENSE
└── README.md
```

### Create `secret.yaml` here:

```text
kubernetes/
│
├── namespace.yaml
├── secret.yaml          ← CREATE HERE
│
├── backend/
├── frontend/
├── hpa/
├── ingress/
└── mysql/
```

**Do NOT create it inside `mysql/`, `backend/`, or `frontend/`.**

---

# 4.2. Create `secret.yaml` in VS Code

In VS Code Explorer:

### Step 1

Expand:

```text
kubernetes
```

You already have:

```text
namespace.yaml
```

### Step 2

Right-click on:

```text
kubernetes
```

Select:

```text
New File
```

### Step 3

Enter:

```text
secret.yaml
```

You should now see:

```text
kubernetes/
├── namespace.yaml
└── secret.yaml
```

---

# 4.3. Add the Secret YAML

Open:

```text
kubernetes/secret.yaml
```

Add:

```yaml
apiVersion: v1
kind: Secret

metadata:
  name: zepto-db-secret
  namespace: zepto

type: Opaque

stringData:

  DB_HOST: zepto-mysql

  DB_PORT: "3306"

  DB_USER: root

  DB_PASSWORD: "Root@123"

  DB_NAME: zepto_db

  MYSQL_ROOT_PASSWORD: "Root@123"

  JWT_SECRET: "mySuperSecretKey"
```

---

# 4.4. Your Kubernetes Folder Should Now Look Like This

```text
kubernetes/
│
├── namespace.yaml
│
├── secret.yaml                 ← NEW
│
├── backend/
│   ├── deployment.yaml
│   └── service.yaml
│
├── frontend/
│   ├── deployment.yaml
│   └── service.yaml
│
├── hpa/
│
├── ingress/
│   └── ingress.yaml
│
└── mysql/
    ├── deployment.yaml
    ├── service.yaml
    └── pvc.yaml
```

This is the structure I recommend for your project.

---

# 4.5. Why Is `secret.yaml` Outside `mysql/`?

Because this Secret will be used by **multiple applications**.

For example:

```text
                   zepto-db-secret
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
         MySQL Pod             Backend Pod
              │                     │
       MYSQL_ROOT_PASSWORD      DB_PASSWORD
       MYSQL_DATABASE            DB_HOST
                                DB_USER
                                DB_NAME
                                JWT_SECRET
```

Therefore, keeping it at:

```text
kubernetes/secret.yaml
```

is cleaner than putting it inside:

```text
kubernetes/mysql/
```

---

# 4.6. Apply Namespace First

Before applying the Secret, make sure the `zepto` namespace exists.

From the **project root**:

```powershell
kubectl apply -f kubernetes/namespace.yaml
```

Expected:

```text
namespace/zepto created
```

If it already exists:

```text
namespace/zepto unchanged
```

---

# 4.7. Apply the Secret

Now run:

```powershell
kubectl apply -f kubernetes/secret.yaml
```

Expected:

```text
secret/zepto-db-secret created
```

---

# 4.8. Verify the Secret

Run:

```powershell
kubectl get secrets -n zepto
```

Expected:

```text
NAME               TYPE     DATA   AGE
zepto-db-secret    Opaque   7      10s
```

The `DATA` value should be **7**, because we created seven keys:

```text
DB_HOST
DB_PORT
DB_USER
DB_PASSWORD
DB_NAME
MYSQL_ROOT_PASSWORD
JWT_SECRET
```

---

# 4.9. Check Secret Details

You can run:

```powershell
kubectl describe secret zepto-db-secret -n zepto
```

You will see the key names:

```text
Name:         zepto-db-secret
Namespace:    zepto

Type:         Opaque

Data
====
DB_HOST:               ...
DB_PORT:               ...
DB_USER:               ...
DB_PASSWORD:           ...
DB_NAME:               ...
MYSQL_ROOT_PASSWORD:   ...
JWT_SECRET:            ...
```

Kubernetes will not display the actual secret values with `describe`.

---

# 4.10. Very Important — Don't Push This Secret to GitHub

Because your file contains:

```yaml
DB_PASSWORD: "Root@123"
```

and:

```yaml
JWT_SECRET: "mySuperSecretKey"
```

**Do not commit this actual `secret.yaml` to GitHub.**

Your repository should instead contain something like:

```text
kubernetes/
├── namespace.yaml
├── secret.yaml.example
├── backend/
├── frontend/
├── hpa/
├── ingress/
└── mysql/
```

For example:

### `secret.yaml.example`

```yaml
apiVersion: v1
kind: Secret

metadata:
  name: zepto-db-secret
  namespace: zepto

type: Opaque

stringData:

  DB_HOST: zepto-mysql

  DB_PORT: "3306"

  DB_USER: root

  DB_PASSWORD: CHANGE_ME

  DB_NAME: zepto_db

  MYSQL_ROOT_PASSWORD: CHANGE_ME

  JWT_SECRET: CHANGE_ME
```

Then add the real file to `.gitignore`:

```gitignore
kubernetes/secret.yaml
```

This is especially important because you're going to push this project to GitHub and later use **GitHub Actions**.

---

# 4.11. For Your Current Training Lab

For now, your local structure can be:

```text
kubernetes/
│
├── namespace.yaml
├── secret.yaml                 ← LOCAL ONLY
│
├── backend/
│   ├── deployment.yaml
│   └── service.yaml
│
├── frontend/
│   ├── deployment.yaml
│   └── service.yaml
│
├── hpa/
│
├── ingress/
│   └── ingress.yaml
│
└── mysql/
    ├── deployment.yaml
    ├── service.yaml
    └── pvc.yaml
```

And Kubernetes gets the Secret with:

```powershell
kubectl apply -f kubernetes/secret.yaml
```

---

## One More Important Point

The `secret.yaml` we created contains the **database password used by your current MySQL setup**:

```text
DB_HOST = zepto-mysql
DB_PORT = 3306
DB_USER = root
DB_PASSWORD = Root@123
DB_NAME = zepto_db
```

Notice that `DB_HOST` is:

```text
zepto-mysql
```

and **not**:

```text
localhost
```

because inside Kubernetes the Node.js backend reaches MySQL through the Kubernetes Service:

```text
Node.js Pod
    │
    ▼
zepto-mysql:3306
    │
    ▼
MySQL Pod
```

So your `secret.yaml` location and content should be exactly at:

```text
D:\Github\github-actions\Module-10 Kubernetes Integration\
zepto-quick-commerce\
kubernetes\
secret.yaml
```

based on the project structure shown in your screenshot.

# 5. MySQL PersistentVolumeClaim

MySQL needs persistent storage.

If the MySQL Pod is deleted, we don't want the database to disappear.

Create:

```text
kubernetes/mysql/pvc.yaml
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: zepto
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard-rwo
  resources:
    requests:
      storage: 10Gi
```

GKE's Persistent Disk CSI driver provides the `standard-rwo` StorageClass using balanced persistent disks. On a Standard GKE cluster, verify that the Compute Engine Persistent Disk CSI driver is enabled before using this StorageClass. ([Google Cloud Documentation][2])

Check your cluster:

```bash
kubectl get storageclass
```

You should see something similar to:

```text
NAME                 PROVISIONER
standard             kubernetes.io/gce-pd
standard-rwo         pd.csi.storage.gke.io
premium-rwo          pd.csi.storage.gke.io
```

If `standard-rwo` doesn't exist, enable the CSI driver:

```bash
gcloud container clusters update zepto-gke-cluster \
  --region asia-south1 \
  --update-addons=GcePersistentDiskCsiDriver=ENABLED
```

Then:

```bash
kubectl get storageclass
```

---

# 6. MySQL Deployment

Create:

```text
kubernetes/mysql/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zepto-mysql
  namespace: zepto
spec:
  replicas: 1

  selector:
    matchLabels:
      app: zepto-mysql

  template:
    metadata:
      labels:
        app: zepto-mysql

    spec:
      containers:

        - name: mysql

          image: mysql:8.0

          ports:
            - containerPort: 3306

          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: zepto-db-secret
                  key: MYSQL_ROOT_PASSWORD

            - name: MYSQL_DATABASE
              value: zepto_db

          volumeMounts:
            - name: mysql-storage
              mountPath: /var/lib/mysql

      volumes:

        - name: mysql-storage

          persistentVolumeClaim:
            claimName: mysql-pvc
```

---

# 7. MySQL Service

Create:

```text
kubernetes/mysql/service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zepto-mysql
  namespace: zepto
spec:
  type: ClusterIP

  selector:
    app: zepto-mysql

  ports:
    - port: 3306
      targetPort: 3306
```

Now the backend can connect to:

```text
zepto-mysql:3306
```

This is very important.

Inside Kubernetes:

```text
DB_HOST=zepto-mysql
```

NOT:

```text
DB_HOST=localhost
```

---

# 8. MySQL Architecture

```text
                 Backend Pod
                     │
                     │
                     ▼
             zepto-mysql:3306
                     │
                     ▼
              MySQL Service
                     │
                     ▼
                MySQL Pod
                     │
                     ▼
                 mysql-pvc
                     │
                     ▼
             GCP Persistent Disk
```

---

# 9. Backend Deployment

Now deploy our Node.js application.

Create:

```text
kubernetes/backend/deployment.yaml
```

Use your actual Artifact Registry image later.

For now:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zepto-backend
  namespace: zepto

spec:
  replicas: 2

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

          image: YOUR_REGION-docker.pkg.dev/YOUR_GCP_PROJECT_ID/zepto-repo/zepto-backend:v1

          ports:
            - containerPort: 5000

          env:

            - name: PORT
              value: "5000"

            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: zepto-db-secret
                  key: DB_HOST

            - name: DB_PORT
              valueFrom:
                secretKeyRef:
                  name: zepto-db-secret
                  key: DB_PORT

            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: zepto-db-secret
                  key: DB_USER

            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: zepto-db-secret
                  key: DB_PASSWORD

            - name: DB_NAME
              valueFrom:
                secretKeyRef:
                  name: zepto-db-secret
                  key: DB_NAME

            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: zepto-db-secret
                  key: JWT_SECRET

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

          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"

            limits:
              cpu: "500m"
              memory: "512Mi"
```

---

# 10. Why Two Backend Replicas?

We configured:

```yaml
replicas: 2
```

Therefore:

```text
Backend Deployment
       │
       ├── Backend Pod 1
       │
       └── Backend Pod 2
```

If one Pod fails:

```text
Backend Pod 1 ❌

Backend Pod 2 ✅
```

Kubernetes keeps the application available.

---

# 11. Backend Service

Create:

```text
kubernetes/backend/service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zepto-backend
  namespace: zepto
spec:
  type: ClusterIP

  selector:
    app: zepto-backend

  ports:
    - port: 5000
      targetPort: 5000
```

Now:

```text
Frontend
   │
   ▼
zepto-backend:5000
   │
   ▼
Backend Pods
```

---

# 12. Why ClusterIP?

The backend should **not** be directly exposed to the Internet.

Therefore:

```yaml
type: ClusterIP
```

The backend is accessible only inside the Kubernetes cluster.

```text
Internet
   │
   X
   │
Backend ❌
```

Instead:

```text
Internet
   │
   ▼
Ingress
   │
   ▼
Frontend
   │
   ▼
Backend
```

---

# 13. Frontend Deployment

Create:

```text
kubernetes/frontend/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zepto-frontend
  namespace: zepto

spec:
  replicas: 2

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

          image: YOUR_REGION-docker.pkg.dev/YOUR_GCP_PROJECT_ID/zepto-repo/zepto-frontend:v1

          ports:
            - containerPort: 80

          readinessProbe:
            httpGet:
              path: /
              port: 80

            initialDelaySeconds: 10
            periodSeconds: 10

          livenessProbe:
            httpGet:
              path: /
              port: 80

            initialDelaySeconds: 30
            periodSeconds: 20

          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"

            limits:
              cpu: "250m"
              memory: "256Mi"
```

---

# 14. Frontend Service

Create:

```text
kubernetes/frontend/service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zepto-frontend
  namespace: zepto

spec:
  type: ClusterIP

  selector:
    app: zepto-frontend

  ports:
    - port: 80
      targetPort: 80
```

Notice something important:

We are using:

```text
ClusterIP
```

not:

```text
LoadBalancer
```

Why?

Because we'll expose the frontend through **GKE Ingress**.

GKE Ingress backends use Services, and GKE's external Application Load Balancer routes traffic to those backend Pods. ([Google Cloud Documentation][1])

---

# 15. Final Service Architecture

```text
                    Internet
                       │
                       ▼
                   Ingress
                       │
                       ▼
              zepto-frontend
                 ClusterIP
                       │
                 ┌─────┴─────┐
                 ▼           ▼
             Frontend 1   Frontend 2
                 │
                 │ API
                 ▼
              Backend
              Service
                 │
            ┌────┴────┐
            ▼         ▼
        Backend 1  Backend 2
            │
            ▼
        MySQL Service
            │
            ▼
         MySQL Pod
```

---

# 16. Create Ingress

Create:

```text
kubernetes/ingress/ingress.yaml
```

```yaml
apiVersion: networking.k8s.io/v1

kind: Ingress

metadata:

  name: zepto-ingress

  namespace: zepto

  annotations:
    kubernetes.io/ingress.class: "gce"

spec:

  rules:

    - http:

        paths:

          - path: /*
            pathType: ImplementationSpecific

            backend:

              service:
                name: zepto-frontend
                port:
                  number: 80
```

This tells GKE:

```text
Internet
   │
   ▼
Google External Application Load Balancer
   │
   ▼
zepto-frontend Service
   │
   ▼
React Pods
```

The `gce` annotation tells GKE to process this as an external GKE Ingress. Current GKE documentation specifically notes that GKE Ingress uses the `kubernetes.io/ingress.class` annotation and that `gce` creates an external Application Load Balancer. ([Google Cloud Documentation][1])

---

# 17. Important Frontend → Backend Point

There is an important issue with our current architecture.

Our React application runs in the **user's browser**.

Therefore this will NOT work:

```text
VITE_API_URL=http://zepto-backend:5000
```

Why?

Because:

```text
Browser
   │
   X
   │
zepto-backend
```

`zepto-backend` is a Kubernetes internal DNS name. The user's browser cannot resolve it.

Instead, we should expose the backend through the same external domain using a path such as:

```text
/api/*
```

Then:

```text
Browser
   │
   ▼
https://YOUR-DOMAIN/
        │
        ▼
      Ingress
       │
       ├── /* ───────► Frontend
       │
       └── /api/* ──► Backend
```

This is the architecture I recommend for our Zepto project.

---

# 18. Updated Ingress — Frontend + Backend

Therefore, replace the previous Ingress with:

```yaml
apiVersion: networking.k8s.io/v1

kind: Ingress

metadata:

  name: zepto-ingress

  namespace: zepto

  annotations:
    kubernetes.io/ingress.class: "gce"

spec:

  rules:

    - http:

        paths:

          - path: /api/*
            pathType: ImplementationSpecific

            backend:

              service:
                name: zepto-backend
                port:
                  number: 5000

          - path: /*
            pathType: ImplementationSpecific

            backend:

              service:
                name: zepto-frontend
                port:
                  number: 80
```

Now:

```text
https://YOUR-IP/
       ↓
React

https://YOUR-IP/api/products
       ↓
Node.js
```

---

# 19. Backend API URL

Your React `.env` should eventually use:

```env
VITE_API_URL=/api
```

Instead of:

```env
VITE_API_URL=http://localhost:5000/api
```

This gives us:

```text
Development:

http://localhost:5000/api


Production:

https://YOUR-ZEPTO-DOMAIN/api
```

---

# 20. One Backend Code Change We Need

Our current backend has:

```javascript
app.get("/health", ...)
```

For the Ingress path:

```text
/api/*
```

we have two choices.

For simplicity, keep the backend routes as:

```text
/health
/products
/orders
```

and use an Ingress design where `/api` is rewritten/handled appropriately, **or** change the backend API routes to include `/api`.

For our training project, I recommend the second approach:

```text
/api/health

/api/products

/api/orders

/api/cart

/api/auth/login
```

Then React uses:

```text
/api/products
```

This is cleaner for a real application.

We'll make this change when we build the complete backend API in the next stage.

---

# 21. Deploy Namespace

Before deploying anything, make sure you're connected to GKE:

```bash
kubectl config current-context
```

Then:

```bash
kubectl apply -f kubernetes/namespace.yaml
```

Verify:

```bash
kubectl get namespaces
```

---

# 22. Deploy Secret

```bash
kubectl apply -f kubernetes/secret.yaml
```

Verify:

```bash
kubectl get secrets -n zepto
```

Expected:

```text
NAME               TYPE
zepto-db-secret    Opaque
```

---

# 23. Deploy MySQL PVC

```bash
kubectl apply -f kubernetes/mysql/pvc.yaml
```

Check:

```bash
kubectl get pvc -n zepto
```

Initially you may see:

```text
STATUS: Pending
```

That's not necessarily an error when using delayed volume binding.

Once the MySQL Pod consumes the PVC, GKE can provision the disk.

Then check again:

```bash
kubectl get pvc -n zepto
```

Expected:

```text
NAME        STATUS   VOLUME
mysql-pvc   Bound    pvc-xxxxx
```

GKE supports dynamic PersistentVolume provisioning through StorageClasses. ([Google Cloud Documentation][2])

---

# 24. Deploy MySQL

```bash
kubectl apply -f kubernetes/mysql/deployment.yaml
```

Then:

```bash
kubectl get pods -n zepto
```

Expected:

```text
zepto-mysql-xxxxxxxx   1/1   Running
```

---

# 25. Deploy MySQL Service

```bash
kubectl apply -f kubernetes/mysql/service.yaml
```

Check:

```bash
kubectl get svc -n zepto
```

Expected:

```text
NAME          TYPE        CLUSTER-IP
zepto-mysql   ClusterIP   10.x.x.x
```

---

# 26. Deploy Backend

Before this step, make sure your backend image exists in Artifact Registry.

Then:

```bash
kubectl apply -f kubernetes/backend/deployment.yaml
```

Check:

```bash
kubectl get pods -n zepto
```

Expected:

```text
zepto-backend-xxxxx   1/1   Running
zepto-backend-yyyyy   1/1   Running
```

---

# 27. Check Backend Logs

```bash
kubectl logs deployment/zepto-backend -n zepto
```

You should see:

```text
MySQL Connected Successfully

Server Running on Port 5000
```

---

# 28. Deploy Backend Service

```bash
kubectl apply -f kubernetes/backend/service.yaml
```

Check:

```bash
kubectl get svc -n zepto
```

---

# 29. Deploy Frontend

```bash
kubectl apply -f kubernetes/frontend/deployment.yaml
```

Check:

```bash
kubectl get pods -n zepto
```

Expected:

```text
zepto-frontend-xxxxx   1/1   Running
zepto-frontend-yyyyy   1/1   Running
```

---

# 30. Deploy Frontend Service

```bash
kubectl apply -f kubernetes/frontend/service.yaml
```

Check:

```bash
kubectl get svc -n zepto
```

You should have:

```text
zepto-backend
zepto-frontend
zepto-mysql
```

---

# 31. Deploy Ingress

```bash
kubectl apply -f kubernetes/ingress/ingress.yaml
```

Check:

```bash
kubectl get ingress -n zepto
```

Initially:

```text
NAME             CLASS    HOSTS   ADDRESS   PORTS
zepto-ingress    <none>   *       pending   80
```

Wait several minutes.

Then:

```bash
kubectl get ingress -n zepto
```

You should eventually get:

```text
NAME             CLASS    HOSTS   ADDRESS        PORTS
zepto-ingress    <none>   *       34.x.x.x       80
```

GKE may take several minutes to provision the forwarding rule, health checks, URL map, backend services, and related resources. ([Google Cloud Documentation][3])

---

# 32. Access the Application

Get the external IP:

```bash
kubectl get ingress -n zepto
```

Suppose:

```text
ADDRESS

34.123.45.67
```

Open:

```text
http://34.123.45.67
```

You should see:

```text
Zepto Quick Commerce
```

---

# 33. Test Backend

Open:

```text
http://34.123.45.67/api/health
```

Expected:

```json
{
  "status": "SUCCESS",
  "database": "Connected"
}
```

---

# 34. Complete Kubernetes Architecture

```text
                         INTERNET
                            │
                            ▼
                  Google Cloud Load Balancer
                            │
                         Ingress
                            │
             ┌──────────────┴──────────────┐
             │                             │
             │ /                           │ /api/*
             ▼                             ▼
     Frontend Service                Backend Service
        ClusterIP                       ClusterIP
             │                             │
       ┌─────┴─────┐                 ┌─────┴─────┐
       ▼           ▼                 ▼           ▼
    React-1     React-2           Node-1       Node-2
                                        │
                                        │
                                        ▼
                                  MySQL Service
                                    ClusterIP
                                        │
                                        ▼
                                   MySQL Pod
                                        │
                                        ▼
                                   mysql-pvc
                                        │
                                        ▼
                                GCP Persistent Disk
```

---

# 35. Final Kubernetes Folder

```text
kubernetes/
│
├── namespace.yaml
│
├── secret.yaml
│
├── mysql/
│   ├── pvc.yaml
│   ├── deployment.yaml
│   └── service.yaml
│
├── backend/
│   ├── deployment.yaml
│   └── service.yaml
│
├── frontend/
│   ├── deployment.yaml
│   └── service.yaml
│
└── ingress/
    └── ingress.yaml
```

---

# 36. Verify Everything

Run:

```bash
kubectl get all -n zepto
```

Then:

```bash
kubectl get pvc -n zepto
```

Then:

```bash
kubectl get secrets -n zepto
```

Then:

```bash
kubectl get ingress -n zepto
```

And:

```bash
kubectl get events -n zepto --sort-by=.lastTimestamp
```

---

# 37. Expected Final Result

```text
NAMESPACE
└── zepto

DEPLOYMENTS
├── zepto-mysql
├── zepto-backend
└── zepto-frontend

PODS
├── MySQL Pod
├── Backend Pod 1
├── Backend Pod 2
├── Frontend Pod 1
└── Frontend Pod 2

SERVICES
├── zepto-mysql
├── zepto-backend
└── zepto-frontend

STORAGE
└── mysql-pvc

INGRESS
└── zepto-ingress

LOAD BALANCER
└── External IP
```

---

# 38. Git Commit

Create a branch:

```bash
git checkout -b feature/kubernetes-manifests
```

Then:

```bash
git add kubernetes/
```

Commit:

```bash
git commit -m "Add Kubernetes manifests for Zepto application"
```

Push:

```bash
git push origin feature/kubernetes-manifests
```

Then create a Pull Request:

```text
feature/kubernetes-manifests
             ↓
         development
```

---

## One Important Architecture Decision

For **this training project**, running MySQL inside GKE is useful because students can learn:

```text
Deployment
Service
PVC
Persistent Disk
Secrets
```

But for a real production Zepto-like application, I would **not normally run the primary MySQL database as a simple Deployment inside GKE**. I would use **Cloud SQL for MySQL** and let GKE run the stateless frontend/backend workloads. This gives you managed backups, maintenance, high availability options, and easier database operations.

So the learning architecture is:

```text
GKE
├── React
├── Node.js
└── MySQL + PVC
```

while the production architecture should become:

```text
GKE
├── React
└── Node.js
      │
      ▼
Google Cloud SQL
└── MySQL
```

