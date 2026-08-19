# Google Artifact Registry (GAR) Setup and Docker Image Push — Zepto Project

## Project Information

| Item | Value |
|---|---|
| Google Cloud Project Name | `zepto-ecommerce-class` |
| Google Cloud Project ID | `zepto-ecommerce-class-505916` |
| Artifact Registry Repository | `zepto-repo` |
| Repository Format | Docker |
| Region | `asia-south1` |
| GAR Host | `asia-south1-docker.pkg.dev` |

**Google Cloud Console:**  
https://console.cloud.google.com/artifacts/settings?project=zepto-ecommerce-class-505916

---

# 1. Set the Google Cloud Project

Open **Google Cloud Shell** and set the project:

```bash
gcloud config set project zepto-ecommerce-class-505916
```

Verify the active project:

```bash
gcloud config get-value project
```

Expected output:

```text
zepto-ecommerce-class-505916
```

You can also verify the project details:

```bash
gcloud projects describe zepto-ecommerce-class-505916
```

---

# 2. Enable Required APIs

Enable the Artifact Registry API:

```bash
gcloud services enable artifactregistry.googleapis.com
```

It is also recommended to enable the Container Registry API if your project or existing tooling requires it:

```bash
gcloud services enable containerregistry.googleapis.com
```

Verify that Artifact Registry is enabled:

```bash
gcloud services list --enabled --filter="name:artifactregistry.googleapis.com"
```

---

# 3. Create the Google Artifact Registry Repository

Create a Docker repository named `zepto-repo` in the `asia-south1` region:

```bash
gcloud artifacts repositories create zepto-repo \
  --repository-format=docker \
  --location=asia-south1 \
  --description="Zepto Docker Repository"
```

### Important

This command should be executed only once.

If the repository already exists, Google Cloud will return an error indicating that the repository already exists. In that case, do not create it again.

---

# 4. Verify the Artifact Registry Repository

List repositories in `asia-south1`:

```bash
gcloud artifacts repositories list \
  --location=asia-south1
```

You should see:

```text
zepto-repo
```

For detailed information:

```bash
gcloud artifacts repositories describe zepto-repo \
  --location=asia-south1
```

---

# 5. Configure Docker Authentication

Docker needs permission to communicate with Google Artifact Registry.

Run:

```bash
gcloud auth configure-docker asia-south1-docker.pkg.dev
```

You may see:

```text
Do you want to continue (Y/n)?
```

Enter:

```text
Y
```

This configures Docker to use Google Cloud credentials when communicating with:

```text
asia-south1-docker.pkg.dev
```

---

# 6. Verify Docker Authentication Configuration

You can check the Docker configuration with:

```bash
cat ~/.docker/config.json
```

The configuration should contain the Artifact Registry host:

```text
asia-south1-docker.pkg.dev
```

---

# 7. Artifact Registry Docker Image Naming Convention

The standard GAR Docker image format is:

```text
LOCATION-docker.pkg.dev/PROJECT-ID/REPOSITORY/IMAGE:TAG
```

For this Zepto project:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/IMAGE:TAG
```

For example:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend:v1
```

---

# 8. Check Existing Local Docker Images

Before tagging the images, check whether the required images exist locally:

```bash
docker images
```

The images required for this Zepto project are:

```text
zepto-frontend:v1
zepto-backend:v1.3
mysql:8.0
```

You can also check them individually:

```bash
docker image inspect zepto-frontend:v1
```

```bash
docker image inspect zepto-backend:v1.3
```

```bash
docker image inspect mysql:8.0
```

If an image does not exist locally, build or pull that image before continuing.

---

# 9. Tag the Zepto Frontend Image

Tag the local frontend image with the GAR repository path:

```bash
docker tag zepto-frontend:v1 \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend:v1
```

Verify:

```bash
docker images
```

You should see an image similar to:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend   v1
```

---

# 10. Tag the Zepto Backend Image

Tag the backend image:

```bash
docker tag zepto-backend:v1.3 \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend:v1.3
```

Verify:

```bash
docker images
```

You should see:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend   v1.3
```

---

# 11. Tag the MySQL Image

Tag the MySQL image:

```bash
docker tag mysql:8.0 \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/mysql:8.0
```

Verify:

```bash
docker images
```

You should see:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/mysql   8.0
```

---

# 12. Verify All GAR-Tagged Images

Run:

```bash
docker images | grep "asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo"
```

Expected images:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend   v1
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend    v1.3
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/mysql             8.0
```

---

# 13. Push the Zepto Frontend Image

Push the frontend image to Artifact Registry:

```bash
docker push \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend:v1
```

Docker will upload the image layers to:

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo
```

---

# 14. Push the Zepto Backend Image

Push the backend image:

```bash
docker push \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend:v1.3
```

---

# 15. Push the MySQL Image

Push the MySQL image:

```bash
docker push \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/mysql:8.0
```

---

# 16. Verify Images in Artifact Registry

List the Docker images in the repository:

```bash
gcloud artifacts docker images list \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo
```

You should see:

```text
zepto-frontend
zepto-backend
mysql
```

---

# 17. View Image Versions

To view versions/digests of the frontend image:

```bash
gcloud artifacts docker images list \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend \
  --include-tags
```

For the backend:

```bash
gcloud artifacts docker images list \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend \
  --include-tags
```

For MySQL:

```bash
gcloud artifacts docker images list \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/mysql \
  --include-tags
```

---

# 18. Final Image Paths

After successful pushes, the images will be available at:

### Frontend

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend:v1
```

### Backend

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend:v1.3
```

### MySQL

```text
asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/mysql:8.0
```

---

# 19. Complete Command Sequence

If the project and images are already available, the complete process from project selection through image push is:

```bash
gcloud config set project zepto-ecommerce-class-505916

gcloud services enable artifactregistry.googleapis.com

gcloud artifacts repositories create zepto-repo \
  --repository-format=docker \
  --location=asia-south1 \
  --description="Zepto Docker Repository"

gcloud auth configure-docker asia-south1-docker.pkg.dev

docker tag zepto-frontend:v1 \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend:v1

docker tag zepto-backend:v1.3 \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend:v1.3

docker tag mysql:8.0 \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/mysql:8.0

docker push \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-frontend:v1

docker push \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/zepto-backend:v1.3

docker push \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo/mysql:8.0

gcloud artifacts docker images list \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo
```

---

# 20. Expected Final Structure

The Google Artifact Registry setup should look like:

```text
Google Cloud Project
└── zepto-ecommerce-class-505916
    └── Artifact Registry
        └── asia-south1
            └── zepto-repo
                ├── zepto-frontend:v1
                ├── zepto-backend:v1.3
                └── mysql:8.0
```

---

# 21. Troubleshooting

## Error: Repository already exists

If you receive an error saying the repository already exists, verify it:

```bash
gcloud artifacts repositories describe zepto-repo \
  --location=asia-south1
```

Do not run the repository creation command again.

---

## Error: Permission denied

Check the currently authenticated account:

```bash
gcloud auth list
```

Check the active project:

```bash
gcloud config get-value project
```

Make sure the active account has permission to write to Artifact Registry.

---

## Error: Docker authentication required

Run:

```bash
gcloud auth configure-docker asia-south1-docker.pkg.dev
```

Then retry the `docker push` command.

---

## Error: Image does not exist

Check local images:

```bash
docker images
```

Make sure these images exist:

```text
zepto-frontend:v1
zepto-backend:v1.3
mysql:8.0
```

---

# 22. Final Verification

Run:

```bash
gcloud artifacts repositories describe zepto-repo \
  --location=asia-south1
```

Then:

```bash
gcloud artifacts docker images list \
  asia-south1-docker.pkg.dev/zepto-ecommerce-class-505916/zepto-repo \
  --include-tags
```

The repository and all three images should be visible.

**Result:** Google Artifact Registry is created in `asia-south1`, Docker authentication is configured, and the Zepto frontend, backend, and MySQL images are pushed to the `zepto-repo` repository.
