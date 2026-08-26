# Part 9: Deploy to GKE and Verify the Application

In this part, we will take the Docker image already stored in *Google
Artifact Registry (GAR)* and deploy it to the *GKE cluster*.

Your image:

``` text
asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:v1.3
```

### 9.1 Connect to the GKE Cluster

First, authenticate with GCP:

``` bash
gcloud auth login
```

Set the project:

``` bash
gcloud config set project zepto-ecommerce-class
```

Get GKE credentials:

``` bash
gcloud container clusters get-credentials <CLUSTER_NAME> \
  --region asia-south1 \
  --project zepto-ecommerce-class
```

Verify the connection:

``` bash
kubectl get nodes
```

You should see something similar to:

``` text
NAME                                       STATUS   ROLES    AGE
gke-zepto-cluster-default-pool-xxxx       Ready    <none>   10m
gke-zepto-cluster-default-pool-yyyy       Ready    <none>   10m
```

------------------------------------------------------------------------

## 9.2 Verify the Namespace

If you created a namespace:

``` bash
kubectl get namespaces
```

For example:

``` text
NAME              STATUS
default           Active
zepto             Active
kube-system       Active
```

If the zepto namespace doesn't exist:

``` bash
kubectl create namespace zepto
```

------------------------------------------------------------------------

## 9.3 Update the Kubernetes Deployment

Your deployment.yaml should point to the GAR image.

Example:

``` yaml
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
        - name: zepto-backend
          image: asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:v1.3
          ports:
            - containerPort: 3000

          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10

          livenessProbe:
            httpGet:
              path: /health
              port: 3000
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

> Replace 3000 and /health with the actual port and health endpoint used
> by your Node.js application.

------------------------------------------------------------------------

## 9.4 Deploy the Application

From the directory containing your Kubernetes YAML files:

``` bash
kubectl apply -f deployment.yaml
```

Expected:

``` text
deployment.apps/zepto-backend created
```

Check the deployment:

``` bash
kubectl get deployments -n zepto
```

Example:

``` text
NAME            READY   UP-TO-DATE   AVAILABLE
zepto-backend   2/2     2            2
```

------------------------------------------------------------------------

## 9.5 Check the Pods

``` bash
kubectl get pods -n zepto
```

Expected:

``` text
NAME                             READY   STATUS    RESTARTS
zepto-backend-7d8f9c6d8-x2abc   1/1     Running   0
zepto-backend-7d8f9c6d8-k9xyz   1/1     Running   0
```

The important values are:

``` text
READY     1/1
STATUS    Running
RESTARTS  0
```

------------------------------------------------------------------------

## 9.6 If Pods Are Not Running

Use:

``` bash
kubectl describe pod <POD_NAME> -n zepto
```

Check application logs:

``` bash
kubectl logs <POD_NAME> -n zepto
```

For a deployment:

``` bash
kubectl logs deployment/zepto-backend -n zepto
```

Follow logs continuously:

``` bash
kubectl logs -f deployment/zepto-backend -n zepto
```

Common problems:

``` text
ImagePullBackOff
CrashLoopBackOff
Readiness probe failed
OOMKilled
```

For ImagePullBackOff, verify the image:

``` bash
kubectl describe pod <POD_NAME> -n zepto
```

And verify that the image exists:

``` bash
gcloud artifacts docker images list \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo
```

------------------------------------------------------------------------

# 9.7 Create the Kubernetes Service

Create service.yaml:

``` yaml
apiVersion: v1
kind: Service
metadata:
  name: zepto-backend-service
  namespace: zepto
spec:
  selector:
    app: zepto-backend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: LoadBalancer
```

Apply it:

``` bash
kubectl apply -f service.yaml
```

Check:

``` bash
kubectl get svc -n zepto
```

Initially you may see:

``` text
NAME                    TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
zepto-backend-service   LoadBalancer   10.20.5.10     <pending>     80:xxxxx/TCP
```

Wait a few minutes.

Then:

``` bash
kubectl get svc -n zepto
```

You should eventually get:

``` text
NAME                    TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
zepto-backend-service   LoadBalancer   10.20.5.10     34.xx.xx.xx      80:xxxxx/TCP
```

------------------------------------------------------------------------

# 9.8 Test the Application

Get the external IP:

``` bash
kubectl get svc zepto-backend-service -n zepto
```

Suppose the IP is:

``` text
34.93.120.50
```

Test the API:

``` bash
curl http://34.93.120.50
```

Or test the health endpoint:

``` bash
curl http://34.93.120.50/health
```

Expected example:

``` json
{
  "status": "healthy"
}
```

You can also open:

``` text
http://34.93.120.50
```

in your browser.

------------------------------------------------------------------------

# 9.9 Verify Service → Pod Connectivity

Check the service endpoints:

``` bash
kubectl get endpoints zepto-backend-service -n zepto
```

You should see pod IPs:

``` text
NAME                    ENDPOINTS
zepto-backend-service   10.10.1.5:3000,10.10.2.7:3000
```

This confirms:

``` text
Internet
   |
   v
LoadBalancer
   |
   v
Kubernetes Service
   |
   +--------+
   |        |
   v        v
Pod 1      Pod 2
   |        |
   +---+----+
       |
       v
 Node.js Backend
```

------------------------------------------------------------------------

# 9.10 Verify the Deployment Details

Run:

``` bash
kubectl get all -n zepto
```

You should see:

``` text
NAME                                  READY
pod/zepto-backend-xxxx                1/1
pod/zepto-backend-yyyy                1/1

NAME                         TYPE           EXTERNAL-IP
service/zepto-backend-service LoadBalancer  34.xx.xx.xx

NAME                            READY
deployment.apps/zepto-backend   2/2

NAME                                       DESIRED
replicaset.apps/zepto-backend-xxxx         2
```

------------------------------------------------------------------------

# 9.11 Verify the Exact Docker Image

This is especially important for your project.

Run:

``` bash
kubectl get deployment zepto-backend \
  -n zepto \
  -o=jsonpath='{.spec.template.spec.containers[0].image}'
```

Expected:

``` text
asia-south1-docker.pkg.dev/zepto-ecommerce-class/zepto-repo/zepto-backend:v1.3
```

This confirms that GKE is using the image from your GAR repository.

------------------------------------------------------------------------

# 9.12 Test Pod Directly

For troubleshooting, you can temporarily port-forward the service:

``` bash
kubectl port-forward svc/zepto-backend-service 8080:80 -n zepto
```

Then test:

``` bash
curl http://localhost:8080
```

Or:

``` bash
curl http://localhost:8080/health
```

This is useful because it allows you to test the application without
involving the external LoadBalancer.

------------------------------------------------------------------------

# 9.13 Final Verification Checklist

Run these commands one by one:

``` bash
kubectl get nodes
```

``` bash
kubectl get pods -n zepto
```

``` bash
kubectl get deployment -n zepto
```

``` bash
kubectl get svc -n zepto
```

``` bash
kubectl get endpoints -n zepto
```

``` bash
kubectl logs deployment/zepto-backend -n zepto
```

``` bash
kubectl get all -n zepto
```

Finally:

``` bash
curl http://<EXTERNAL-IP>/health
```

### Expected architecture after Part 9

``` text
                 GitHub
                    |
                    | CI/CD
                    v
             GitHub Actions
                    |
                    v
             Docker Build
                    |
                    v
        Google Artifact Registry
                    |
                    | v1.3
                    v
                  GKE
          +-------------------+
          |                   |
          |  LoadBalancer     |
          |        |          |
          |        v          |
          |   K8s Service     |
          |        |          |
          |    +---+---+      |
          |    |       |      |
          |    v       v      |
          |   Pod     Pod     |
          |    |       |      |
          |    +---+---+      |
          |        |          |
          |    Node.js API    |
          +-------------------+
                    |
                    v
                 Database
```

*Part 9 outcome:* Your zepto-backend:v1.3 image is running inside GKE,
exposed through a Kubernetes Service, and verified using pods, logs,
endpoints, and the application health/API endpoint.
