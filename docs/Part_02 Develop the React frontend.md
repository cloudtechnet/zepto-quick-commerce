# Part 2: Develop the React Frontend

## Project Name

**Zepto Quick Commerce**

---

# Objective

In this part, we will build the **React Frontend** for our 3-tier Quick Commerce application.

By the end of this module, students will:

* Install React
* Understand the React project structure
* Create reusable components
* Build a responsive UI
* Connect the frontend to the backend (later)
* Prepare the application for Docker and Kubernetes deployment

---

# Project Architecture

```text
                     User
                      │
                      ▼
             React Frontend
                      │
             REST API Calls
                      │
                      ▼
             Node.js Backend
                      │
                      ▼
                  MySQL
```

---

# Tech Stack

| Technology               | Purpose               |
| ------------------------ | --------------------- |
| React 19                 | Frontend Framework    |
| React Router             | Routing               |
| Axios                    | API Calls             |
| Bootstrap / Tailwind CSS | UI Styling            |
| React Icons              | Icons                 |
| Context API              | State Management      |
| Nginx                    | Production Web Server |

---

# Application Features

The frontend will include:

### Authentication

* Login
* Register
* Logout

### Home

* Hero Banner
* Categories
* Featured Products

### Products

* Product Listing
* Search
* Filters
* Product Details

### Cart

* Add Product
* Remove Product
* Update Quantity

### Checkout

* Delivery Address
* Payment Summary
* Place Order

### Orders

* Order History
* Order Details

### Profile

* User Profile
* Change Password

---

# UI Pages

```text
Home

Login

Register

Products

Product Details

Cart

Checkout

Orders

Profile

404 Page
```

---

# Frontend Folder Structure

```text
frontend/
│
├── public/
│   ├── favicon.ico
│   ├── logo.png
│   └── index.html
│
├── src/
│   ├── assets/
│   │   ├── images/
│   │   ├── icons/
│   │   └── styles/
│   │
│   ├── components/
│   │   ├── Navbar/
│   │   ├── Footer/
│   │   ├── ProductCard/
│   │   ├── SearchBar/
│   │   ├── Loader/
│   │   └── ProtectedRoute/
│   │
│   ├── pages/
│   │   ├── Home/
│   │   ├── Login/
│   │   ├── Register/
│   │   ├── Products/
│   │   ├── ProductDetails/
│   │   ├── Cart/
│   │   ├── Checkout/
│   │   ├── Orders/
│   │   ├── Profile/
│   │   └── NotFound/
│   │
│   ├── services/
│   │   └── api.js
│   │
│   ├── context/
│   │   ├── AuthContext.jsx
│   │   └── CartContext.jsx
│   │
│   ├── hooks/
│   │
│   ├── utils/
│   │
│   ├── App.jsx
│   ├── main.jsx
│   └── routes.jsx
│
├── package.json
├── Dockerfile
├── nginx.conf
└── .env.example
```

---

# UI Flow

```text
Home

↓

Products

↓

Product Details

↓

Add to Cart

↓

Checkout

↓

Payment

↓

Order Success
```

---

# Create React Project

## Step 1: Navigate to the project

```bash
cd zepto-quick-commerce
```

---

## Step 2: Create React App with Vite

```bash
npm create vite@latest frontend -- --template react
```

---

## Step 3: Move into the project

```bash
cd frontend
```

---

## Step 4: Install dependencies

```bash
npm install
```

---

## Step 5: Install additional packages

```bash
npm install react-router-dom axios bootstrap react-icons
```

---

# Verify Installation

Run:

```bash
npm run dev
```

Expected output:

```text
Local:

http://localhost:5173
```

Open the browser and confirm the Vite React welcome page appears.

---

# Create the Application Structure

Inside `src`, create the following folders:

```bash
mkdir assets
mkdir components
mkdir pages
mkdir services
mkdir context
mkdir hooks
mkdir utils
```

Then create subfolders:

```bash
mkdir components/Navbar
mkdir components/Footer
mkdir components/ProductCard
mkdir components/SearchBar
mkdir components/Loader
mkdir components/ProtectedRoute

mkdir pages/Home
mkdir pages/Login
mkdir pages/Register
mkdir pages/Products
mkdir pages/ProductDetails
mkdir pages/Cart
mkdir pages/Checkout
mkdir pages/Orders
mkdir pages/Profile
mkdir pages/NotFound
```

---

# Install Bootstrap

In `src/main.jsx`:

```javascript
import 'bootstrap/dist/css/bootstrap.min.css';
```

---

# Configure React Router

Routes:

```text
/

/login

/register

/products

/products/:id

/cart

/checkout

/orders

/profile
```

---

# Application Layout

```text
+----------------------------------------------+

Navbar

-----------------------------------------------

Page Content

-----------------------------------------------

Footer

+----------------------------------------------+
```

---

# Navbar Menu

```text
Logo

Home

Products

Cart

Orders

Profile

Login

Register
```

---

# Home Page Layout

```text
Navbar

↓

Hero Banner

↓

Categories

↓

Featured Products

↓

Offers

↓

Footer
```

---

# Product Card

Each product card contains:

```text
Image

Product Name

Price

Discount

Rating

Add to Cart Button
```

---

# Cart Page

```text
Product

Quantity

Price

Remove

Grand Total

Checkout Button
```

---

# Checkout Page

```text
Delivery Address

Order Summary

Payment

Place Order
```

---

# Context API

Create:

```text
AuthContext

CartContext
```

Responsibilities:

### AuthContext

* Login state
* Logout
* JWT token
* Current user

### CartContext

* Cart items
* Add item
* Remove item
* Update quantity
* Total amount

---

# API Layer

Create:

```text
services/api.js
```

Responsibilities:

* Axios instance
* Base URL configuration
* Authorization header
* Error handling

Example base URL:

```text
http://localhost:5000/api
```

> This will later be changed to the backend Kubernetes service URL during deployment.

---

# Environment Variables

Create `.env.example`:

```text
VITE_API_URL=http://localhost:5000/api
```

---

# Assets Folder

```text
assets/

images/

icons/

styles/
```

---

# Responsive Design

Target devices:

* Mobile
* Tablet
* Laptop
* Desktop

---

# Frontend Development Workflow

```text
Create Component

↓

Develop UI

↓

Add Routing

↓

Connect Context

↓

Connect API

↓

Test UI

↓

Build

↓

Dockerize
```

---

# Local Testing

Run the application:

```bash
npm run dev
```

Build the production bundle:

```bash
npm run build
```

Preview the production build:

```bash
npm run preview
```

---

# Git Workflow

Create a feature branch:

```bash
git checkout -b feature/frontend
```

Commit your work:

```bash
git add .

git commit -m "Develop React frontend for Zepto Quick Commerce"

git push origin feature/frontend
```

Open a Pull Request and merge it into the `development` branch after review.

---

# Best Practices

* Use functional components and React Hooks.
* Keep components small and reusable.
* Store API calls in the `services` folder.
* Keep business logic out of UI components.
* Use environment variables instead of hardcoded URLs.
* Follow consistent naming conventions for files and components.

---

# Learning Outcomes

After completing **Part 2**, students will be able to:

* Create a React application using Vite.
* Organize a scalable frontend project structure.
* Build a responsive e-commerce user interface.
* Configure routing with React Router.
* Manage authentication and cart state using the Context API.
* Prepare the frontend for integration with the Node.js backend, Docker, GitHub Actions, and deployment to GKE.

