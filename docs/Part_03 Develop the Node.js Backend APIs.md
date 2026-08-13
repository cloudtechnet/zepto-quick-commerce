# Part 3: Develop the Node.js Backend APIs

## Project

**Zepto Quick Commerce**

---

# Module Objective

In this module, we will develop the complete **Node.js Backend API** for our Quick Commerce application.

By the end of this module, students will learn how to:

* Create a Node.js project
* Build REST APIs using Express.js
* Connect to MySQL
* Implement JWT Authentication
* Create CRUD APIs
* Test APIs using Postman
* Prepare the backend for Docker and Kubernetes deployment

---

# Overall Architecture

```text
                    React Frontend
                           │
                     HTTP/HTTPS
                           │
                           ▼
                 Node.js Express API
                           │
                     MySQL Driver
                           │
                           ▼
                     MySQL Database
```

---

# Backend Technologies

| Technology        | Purpose               |
| ----------------- | --------------------- |
| Node.js           | Runtime Environment   |
| Express.js        | Web Framework         |
| MySQL2            | Database Connectivity |
| JWT               | Authentication        |
| bcrypt            | Password Hashing      |
| dotenv            | Environment Variables |
| cors              | Cross-Origin Requests |
| helmet            | Security Headers      |
| morgan            | HTTP Logging          |
| express-validator | Input Validation      |
| multer            | File Upload (Future)  |

---

# Backend Folder Structure

```text
backend/
│
├── config/
│   ├── db.js
│   └── jwt.js
│
├── controllers/
│   ├── authController.js
│   ├── productController.js
│   ├── cartController.js
│   ├── orderController.js
│   └── userController.js
│
├── middleware/
│   ├── authMiddleware.js
│   ├── errorMiddleware.js
│   └── validateMiddleware.js
│
├── models/
│   ├── User.js
│   ├── Product.js
│   ├── Cart.js
│   └── Order.js
│
├── routes/
│   ├── authRoutes.js
│   ├── productRoutes.js
│   ├── cartRoutes.js
│   ├── orderRoutes.js
│   └── userRoutes.js
│
├── utils/
│   ├── response.js
│   └── logger.js
│
├── app.js
├── server.js
├── package.json
├── .env.example
├── Dockerfile
└── .gitignore
```

---

# Backend API Architecture

```text
Client

↓

Routes

↓

Controller

↓

Model

↓

Database

↓

JSON Response
```

---

# API Modules

## Authentication

```text
POST

/register

/login

/logout
```

---

## Users

```text
GET

/profile

PUT

/profile
```

---

## Products

```text
GET

/products

GET

/products/:id

POST

/products

PUT

/products/:id

DELETE

/products/:id
```

---

## Cart

```text
GET

/cart

POST

/cart

DELETE

/cart/:id
```

---

## Orders

```text
POST

/orders

GET

/orders

GET

/orders/:id
```

---

# Step 1: Create Backend Folder

From the project root:

```bash
mkdir backend

cd backend
```

---

# Step 2: Initialize Node Project

```bash
npm init -y
```

A `package.json` file is created.

---

# Step 3: Install Required Packages

### Runtime Dependencies

```bash
npm install express mysql2 dotenv cors helmet morgan bcrypt jsonwebtoken express-validator
```

### Development Dependency

```bash
npm install --save-dev nodemon
```

---

# Step 4: Update `package.json`

Replace the `scripts` section with:

```json
"scripts": {
  "start": "node server.js",
  "dev": "nodemon server.js"
}
```

---

# Step 5: Create Folder Structure

```bash
mkdir config controllers middleware models routes utils
```

Create the entry files:

```bash
touch app.js server.js
```

> **Windows (PowerShell):**
>
> ```powershell
> New-Item app.js -ItemType File
> New-Item server.js -ItemType File
> ```

---

# Step 6: Configure Express (`app.js`)

```javascript
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");

const app = express();

app.use(cors());
app.use(helmet());
app.use(morgan("dev"));
app.use(express.json());

app.get("/", (req, res) => {
    res.json({
        message: "Zepto Quick Commerce API Running"
    });
});

module.exports = app;
```

---

# Step 7: Create `server.js`

```javascript
require("dotenv").config();

const app = require("./app");

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
```

---

# Step 8: Create Environment File

Create `.env.example`:

```text
PORT=5000

DB_HOST=localhost

DB_PORT=3306

DB_USER=root

DB_PASSWORD=password

DB_NAME=zepto

JWT_SECRET=mysecretkey
```

When running locally, copy it to `.env` and update the values:

```bash
cp .env.example .env
```

> **Windows (PowerShell):**
>
> ```powershell
> Copy-Item .env.example .env
> ```

---

# Step 9: Database Connection

Create:

```text
config/db.js
```

Responsibilities:

* Connect to MySQL
* Export a reusable connection pool
* Handle connection errors

---

# Step 10: Authentication Flow

```text
User Login

↓

Email & Password

↓

Database Verification

↓

Generate JWT

↓

Return Token

↓

Frontend Stores Token

↓

Future Requests Include Token
```

---

# JWT Protected APIs

```text
Profile

Cart

Checkout

Orders

Admin
```

These routes will use an authentication middleware to verify the JWT before allowing access.

---

# Product API Flow

```text
React

↓

GET /products

↓

Product Controller

↓

MySQL

↓

JSON Response

↓

React UI
```

---

# Backend Request Flow

```text
Browser

↓

Express Route

↓

Controller

↓

Model

↓

MySQL

↓

JSON Response
```

---

# Standard API Response Format

### Success

```json
{
  "success": true,
  "message": "Products retrieved successfully",
  "data": []
}
```

### Error

```json
{
  "success": false,
  "message": "Product not found"
}
```

Using a consistent response format makes it easier for the frontend to handle success and error scenarios.

---

# Testing APIs

Use **Postman** to test:

* Register
* Login
* Products
* Cart
* Orders
* Profile

Verify:

* Correct status codes (200, 201, 400, 401, 404, etc.)
* JSON response format
* JWT authentication for protected endpoints

---

# Local Run

Start the server:

```bash
npm run dev
```

Expected output:

```text
Server running on port 5000
```

Test in the browser:

```text
http://localhost:5000/
```

Expected response:

```json
{
  "message": "Zepto Quick Commerce API Running"
}
```

---

# Git Workflow

Create a backend feature branch:

```bash
git checkout -b feature/backend
```

Commit your work:

```bash
git add .

git commit -m "Develop Node.js backend APIs"

git push origin feature/backend
```

Open a Pull Request and merge into the `development` branch after review.

---

# Best Practices

* Keep business logic inside controllers.
* Use middleware for authentication, validation, and error handling.
* Store secrets in environment variables, not in source code.
* Return consistent JSON responses.
* Validate user input before processing requests.
* Hash passwords using `bcrypt` before storing them.
* Use a connection pool for MySQL instead of creating a new connection for each request.

---

# Learning Outcomes

After completing **Part 3**, students will be able to:

* Build a RESTful backend using Node.js and Express.
* Organize a scalable backend project structure.
* Configure middleware for security, logging, and CORS.
* Connect the backend to MySQL.
* Implement JWT-based authentication.
* Expose APIs that the React frontend can consume.
* Prepare the backend for Dockerization and deployment to GKE.


