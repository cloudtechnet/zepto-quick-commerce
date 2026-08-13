# Part 5: Dockerize All Components

## Project Name

**Zepto Quick Commerce**

---

# Module Objective

In this module, you will Dockerize the entire **3-Tier Zepto Quick Commerce Application**.

By the end of this module, students will be able to:

* Understand Docker architecture
* Create Dockerfiles for React and Node.js
* Create a `.dockerignore` file
* Build Docker images
* Run Docker containers
* Connect containers using Docker Network
* Push Docker images to Docker Hub
* Prepare the application for deployment to GKE

---

# Current Project Structure

```text
zepto-quick-commerce/
│
├── frontend/
│   ├── src/
│   ├── public/
│   ├── package.json
│   ├── Dockerfile
│   ├── .dockerignore
│   └── nginx.conf
│
├── backend/
│   ├── config/
│   ├── controllers/
│   ├── routes/
│   ├── models/
│   ├── app.js
│   ├── server.js
│   ├── package.json
│   ├── Dockerfile
│   └── .dockerignore
│
├── database/
│   ├── init.sql
│   ├── seed.sql
│   └── README.md
│
├── kubernetes/
│
└── .github/
```

---

# Application Architecture After Docker

```text
                     User
                       │
                       ▼
               React Container
                       │
                 REST API Calls
                       │
                       ▼
              Node.js Container
                       │
                 MySQL Connection
                       │
                       ▼
               MySQL Container
```

---

# Docker Images

| Component | Image                                     |
| --------- | ----------------------------------------- |
| Frontend  | `yourdockerhubusername/zepto-frontend:v1` |
| Backend   | `yourdockerhubusername/zepto-backend:v1`  |
| Database  | `mysql:8.0`                               |

---

# Docker Network

All containers should communicate over the same Docker bridge network.

```text
docker network

↓

zepto-network

↓

Frontend

↓

Backend

↓

MySQL
```

---

# Step 1: Verify Docker Installation

```bash
docker --version
```

Example:

```text
Docker version 28.x.x
```

Verify Docker Engine is running:

```bash
docker info
```

---

# Step 2: Create Backend Dockerfile

Location:

```text
backend/Dockerfile
```

```dockerfile
# Base Image
FROM node:22-alpine

# Working Directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application code
COPY . .

# Expose application port
EXPOSE 5000

# Start application
CMD ["npm", "start"]
```

---

# Step 3: Create Backend .dockerignore

Location:

```text
backend/.dockerignore
```

```text
node_modules
npm-debug.log
.git
.gitignore
.env
```

---

# Step 4: Build Backend Image

Move to the backend folder:

```bash
cd backend
```

Build the image:

```bash
docker build -t zepto-backend:v1 .
```

Verify:

```bash
docker images
```

Expected:

```text
REPOSITORY          TAG

zepto-backend       v1
```

---

# Step 5: Test Backend Container

```bash
docker run -d \
--name zepto-backend \
-p 5000:5000 \
--env-file .env \
zepto-backend:v1
```

Check:

```bash
docker ps
```

View logs:

```bash
docker logs zepto-backend
```

---

# Step 6: Create Frontend Dockerfile

Location:

```text
frontend/Dockerfile
```

We'll use a **multi-stage build** for a smaller production image.

```dockerfile
# ---------- Build Stage ----------
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

# ---------- Runtime Stage ----------
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

---

# Step 7: Create Frontend .dockerignore

Location:

```text
frontend/.dockerignore
```

```text
node_modules
dist
.git
.gitignore
```

---

# Step 8: Create nginx.conf

Location:

```text
frontend/nginx.conf
```

```nginx
server {
    listen 80;

    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri /index.html;
    }
}
```

This configuration supports React Router by serving `index.html` for unknown routes.

---

# Step 9: Build Frontend Image

Move to the frontend folder:

```bash
cd ../frontend
```

Build:

```bash
docker build -t zepto-frontend:v1 .
```

Verify:

```bash
docker images
```

---

# Step 10: Run Frontend Container

```bash
docker run -d \
--name zepto-frontend \
-p 3000:80 \
zepto-frontend:v1
```

Open:

```text
http://localhost:3000
```

You should see the React application.

---

# Step 11: Create Docker Network

```bash
docker network create zepto-network
```

Verify:

```bash
docker network ls
```

---

# Step 12: Run MySQL Container

```bash
docker run -d \
--name zepto-mysql \
--network zepto-network \
-e MYSQL_ROOT_PASSWORD=Root@123 \
-e MYSQL_DATABASE=zepto_db \
-p 3306:3306 \
mysql:8.0
```

---

# Step 13: Import Database Schema

Copy SQL files into the MySQL container:

```bash
docker cp database/init.sql zepto-mysql:/init.sql
docker cp database/seed.sql zepto-mysql:/seed.sql
```

Run:

```bash
docker exec -it zepto-mysql mysql -uroot -pRoot@123 zepto_db < /init.sql
```

Then:

```bash
docker exec -it zepto-mysql mysql -uroot -pRoot@123 zepto_db < /seed.sql
```

---

# Step 14: Run Backend on Docker Network

> **Important:** When the backend runs in Docker, `localhost` no longer points to the MySQL container. Containers must use the **container name** (or a Docker DNS name) to communicate.

Create a new environment file for Docker if desired (for example, `.env.docker`):

```env
PORT=5000
DB_HOST=zepto-mysql
DB_PORT=3306
DB_USER=root
DB_PASSWORD=Root@123
DB_NAME=zepto_db
JWT_SECRET=mySuperSecretKey
```

Run the backend:

```bash
docker run -d \
--name zepto-backend \
--network zepto-network \
-p 5000:5000 \
--env-file .env.docker \
zepto-backend:v1
```

---

# Step 15: Run Frontend on Docker Network

Run:

```bash
docker run -d \
--name zepto-frontend \
--network zepto-network \
-p 3000:80 \
zepto-frontend:v1
```

---

# Step 16: Verify Running Containers

```bash
docker ps
```

Expected:

| Container      | Status  |
| -------------- | ------- |
| zepto-frontend | Running |
| zepto-backend  | Running |
| zepto-mysql    | Running |

---

# Step 17: Test the Application

Frontend:

```text
http://localhost:3000
```

Backend Health API:

```text
http://localhost:5000/health
```

Expected response:

```json
{
  "status": "SUCCESS",
  "message": "Database Connected Successfully",
  "database": "Connected"
}
```

---

# Step 18: Tag Images for Docker Hub

```bash
docker tag zepto-frontend:v1 yourdockerhubusername/zepto-frontend:v1

docker tag zepto-backend:v1 yourdockerhubusername/zepto-backend:v1
```

---

# Step 19: Push Images to Docker Hub

Login:

```bash
docker login
```

Push:

```bash
docker push yourdockerhubusername/zepto-frontend:v1

docker push yourdockerhubusername/zepto-backend:v1
```

---

# Docker Workflow

```text
Developer

↓

Git Clone

↓

Docker Build

↓

Docker Image

↓

Docker Container

↓

Docker Hub

↓

GitHub Actions

↓

GKE Deployment
```

---

# Git Workflow

Create a feature branch:

```bash
git checkout -b feature/docker
```

Commit:

```bash
git add .

git commit -m "Dockerize frontend and backend applications"

git push origin feature/docker
```

---

# Best Practices

* Use multi-stage builds for frontend production images.
* Never copy `.env` files into Docker images.
* Use `.dockerignore` to reduce image size.
* Use container names (or service names) instead of `localhost` for inter-container communication.
* Pin base image versions (for example, `node:22-alpine`, `mysql:8.0`) instead of using `latest`.
* Keep one process per container.

---

# Learning Outcomes

After completing **Part 5**, students will be able to:

* Create Dockerfiles for React and Node.js applications.
* Build and run Docker images locally.
* Configure containers to communicate over a Docker network.
* Run a complete three-tier application with Docker.
* Push application images to Docker Hub.
* Prepare the application for CI/CD and deployment to Google Kubernetes Engine (GKE).

---

# Project Structure After Part 5

```text
zepto-quick-commerce/
│
├── frontend/
│   ├── Dockerfile
│   ├── .dockerignore
│   └── nginx.conf
│
├── backend/
│   ├── Dockerfile
│   ├── .dockerignore
│   └── .env.example
│
├── database/
│   ├── init.sql
│   ├── seed.sql
│   └── README.md
│
├── kubernetes/
├── .github/
└── README.md
```
