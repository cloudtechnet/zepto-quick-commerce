# Part 1: Design the Application Architecture & Create the GitHub Repository

This is **Part 1** of the **GitHub Actions Real-Time Project**.

**Project Name:** **Zepto Quick Commerce**

> **Objective:** Design a production-ready 3-tier e-commerce application architecture and create a well-structured GitHub repository that will be used throughout the course.

---

# Project Overview

## Application Name

**Zepto Quick Commerce**

A cloud-native 3-tier e-commerce web application deployed on **Google Kubernetes Engine (GKE)** using **GitHub Actions CI/CD**.

---

# Technologies Used

| Layer              | Technology                       |
| ------------------ | -------------------------------- |
| Frontend           | React.js                         |
| Backend            | Node.js + Express.js             |
| Database           | MySQL 8                          |
| Version Control    | Git & GitHub                     |
| CI/CD              | GitHub Actions                   |
| Containerization   | Docker                           |
| Container Registry | Docker Hub                       |
| Orchestration      | Kubernetes (GKE)                 |
| Cloud Provider     | Google Cloud Platform            |
| Monitoring         | Prometheus & Grafana (Later)     |
| Logging            | Loki / GCP Cloud Logging (Later) |

---

# Application Architecture

```text
                     Internet
                         │
                         │
                  Load Balancer
                         │
                         ▼
              React Frontend (Pods)
                         │
              REST API Calls (HTTPS)
                         │
                         ▼
            Node.js Backend (Pods)
                         │
               MySQL Connection
                         │
                         ▼
                MySQL Database Pod
                         │
                  Persistent Volume
```

---

# Complete Architecture Diagram

```text
                    +----------------------+
                    |      End Users       |
                    +----------+-----------+
                               |
                               |
                               ▼
                    +----------------------+
                    | Google LoadBalancer  |
                    +----------+-----------+
                               |
                               |
                 -----------------------------
                 |                           |
                 ▼                           ▼
        +----------------+          +----------------+
        | React Pod-1    |          | React Pod-2    |
        +----------------+          +----------------+
                 |
                 |
                 ▼
      +---------------------------+
      | Kubernetes Service        |
      +-------------+-------------+
                    |
                    ▼
       +--------------------------+
       | Node.js API Pod-1        |
       +--------------------------+
                    |
       +--------------------------+
       | Node.js API Pod-2        |
       +--------------------------+
                    |
                    ▼
        +-------------------------+
        | Kubernetes Service      |
        +------------+------------+
                     |
                     ▼
             +----------------+
             | MySQL Pod      |
             +----------------+
                     |
                     ▼
         Persistent Volume Claim
                     |
                     ▼
           Persistent Disk (GCP)
```

---

# Application Workflow

```text
User Opens Website

↓

React UI Loads

↓

User Clicks Product

↓

React Calls Backend API

↓

Backend Reads Database

↓

Database Returns Data

↓

Backend Sends JSON

↓

React Displays Products
```

---

# Features of Zepto Quick Commerce

## User Module

* User Registration
* Login
* JWT Authentication
* User Profile

---

## Product Module

* Product Listing
* Categories
* Search Products
* Product Details

---

## Cart Module

* Add to Cart
* Remove Cart
* Update Quantity

---

## Order Module

* Checkout
* Order History
* Order Tracking

---

## Admin Module

* Add Products
* Update Products
* Delete Products
* View Orders

---

# Project Folder Structure

```text
zepto-quick-commerce/
│
├── frontend/
│
├── backend/
│
├── database/
│
├── kubernetes/
│
├── architecture/
│
├── docs/
│
├── scripts/
│
├── .github/
│     └── workflows/
│
├── README.md
│
├── .gitignore
│
└── LICENSE
```

---

# Detailed Folder Structure

```text
zepto-quick-commerce

│
├── frontend
│      │
│      ├── public
│      ├── src
│      ├── package.json
│      ├── Dockerfile
│      └── nginx.conf
│
├── backend
│      │
│      ├── controllers
│      ├── routes
│      ├── middleware
│      ├── models
│      ├── config
│      ├── utils
│      ├── package.json
│      ├── app.js
│      ├── Dockerfile
│      └── .env.example
│
├── database
│      │
│      ├── init.sql
│      └── sample-data.sql
│
├── kubernetes
│      │
│      ├── namespace.yaml
│      ├── mysql
│      ├── backend
│      ├── frontend
│      ├── ingress
│      └── hpa
│
├── architecture
│      │
│      └── architecture.png
│
├── docs
│      │
│      ├── setup.md
│      ├── deployment.md
│      └── troubleshooting.md
│
├── scripts
│      │
│      ├── build.sh
│      ├── deploy.sh
│      └── cleanup.sh
│
├── .github
│      │
│      └── workflows
│              └── deploy.yml
│
├── README.md
│
└── LICENSE
```

---

# Git Branch Strategy

```text
main

development

feature/frontend

feature/backend

feature/database

feature/docker

feature/kubernetes

feature/github-actions

release/v1.0
```

---

# Repository Naming Convention

```text
Repository Name

zepto-quick-commerce
```

---

# GitHub Repository Description

```text
Production Ready 3-Tier Quick Commerce Application deployed on Google Kubernetes Engine using GitHub Actions CI/CD.
```

---

# GitHub Labels

```text
bug

enhancement

documentation

frontend

backend

database

docker

kubernetes

github-actions

good-first-issue
```

---

# Milestones

```text
Milestone 1

Repository Setup

---------------------

Milestone 2

Frontend Development

---------------------

Milestone 3

Backend Development

---------------------

Milestone 4

Database

---------------------

Milestone 5

Docker

---------------------

Milestone 6

GitHub Actions

---------------------

Milestone 7

Kubernetes Deployment

---------------------

Milestone 8

Production Release
```

---

# GitHub Project Board

```text
Backlog

↓

To Do

↓

In Progress

↓

Code Review

↓

Testing

↓

Done
```

---

# Create the GitHub Repository

## Step 1: Sign in to GitHub

Open **[https://github.com](https://github.com)** and log in to your GitHub account.

---

## Step 2: Create a New Repository

Click the **+** icon in the top-right corner and select **New repository**.

---

## Step 3: Enter Repository Details

* **Repository Name:** `zepto-quick-commerce`
* **Description:** `Production Ready 3-Tier Quick Commerce Application deployed on GKE using GitHub Actions CI/CD`
* **Visibility:** Public (recommended for learning) or Private
* **Initialize with:** Add a `README.md`, `.gitignore` (Node), and an MIT `LICENSE`.

---

## Step 4: Clone the Repository

```bash
git clone https://github.com/<your-username>/zepto-quick-commerce.git

cd zepto-quick-commerce
```

---

## Step 5: Create the Initial Folder Structure

```bash
mkdir frontend
mkdir backend
mkdir database
mkdir kubernetes
mkdir architecture
mkdir docs
mkdir scripts

mkdir -p .github/workflows
```

---

## Step 6: Verify the Structure

```bash
tree
```

Expected output:

```text
zepto-quick-commerce
├── architecture
├── backend
├── database
├── docs
├── frontend
├── kubernetes
├── scripts
└── .github
    └── workflows
```

---

## Step 7: Commit the Initial Project

```bash
git add .

git commit -m "Initial project structure for Zepto Quick Commerce"

git push origin main
```

---

# Repository Layout After Part 1

```text
zepto-quick-commerce
│
├── .github
│   └── workflows
│
├── frontend
│
├── backend
│
├── database
│
├── kubernetes
│
├── architecture
│
├── docs
│
├── scripts
│
├── README.md
│
├── LICENSE
│
└── .gitignore
```

---

# Learning Outcomes

By the end of **Part 1**, students will be able to:

* Understand the architecture of a production-ready 3-tier application.
* Explain the roles of React, Node.js, MySQL, Docker, GitHub Actions, and GKE.
* Design a scalable project directory structure.
* Create and initialize a professional GitHub repository.
* Organize the repository using feature branches and project management practices.

