# Part 4: Design the MySQL Database Schema and Seed Data

## Project

**Zepto Quick Commerce**

---

# Module Objective

In this module, you will design and build the **MySQL database** for the Zepto Quick Commerce application.

By the end of this module, students will learn how to:

* Design a normalized relational database
* Create tables with primary and foreign keys
* Define one-to-many relationships
* Seed sample data
* Connect the database to the Node.js backend
* Verify data using SQL queries

---

# Database Architecture

```text
             React Frontend
                    │
             REST API Requests
                    │
                    ▼
           Node.js Express API
                    │
             MySQL Connection
                    │
                    ▼
             MySQL Database
```

---

# Database Name

```sql
zepto_db
```

---

# Entity Relationship Diagram (ERD)

```text
                    USERS
                      │
                      │
               One User
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
      CART                      ORDERS
        │                           │
        │                           │
        └─────────────┐             │
                      ▼             ▼
                 ORDER_ITEMS
                      │
                      │
                      ▼
                  PRODUCTS
                      ▲
                      │
                 CATEGORIES
```

---

# Tables

| Table       | Description                 |
| ----------- | --------------------------- |
| users       | Stores customer information |
| categories  | Product categories          |
| products    | Product catalog             |
| cart        | Shopping cart               |
| orders      | Customer orders             |
| order_items | Products in each order      |

---

# Step 1: Install MySQL

Verify MySQL is installed:

```bash
mysql --version
```

Example output:

```text
mysql  Ver 8.x.x
```

---

# Step 2: Login to MySQL

```bash
mysql -u root -p
```

Enter your password.

---

# Step 3: Create Database

```sql
CREATE DATABASE zepto_db;
```

Verify:

```sql
SHOW DATABASES;
```

Use the database:

```sql
USE zepto_db;
```

---

# Step 4: Create Users Table

```sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    email VARCHAR(150) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    role ENUM('CUSTOMER','ADMIN') DEFAULT 'CUSTOMER',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

# Step 5: Create Categories Table

```sql
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    image_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

# Step 6: Create Products Table

```sql
CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,

    category_id INT NOT NULL,

    product_name VARCHAR(200) NOT NULL,

    description TEXT,

    price DECIMAL(10,2) NOT NULL,

    stock INT DEFAULT 0,

    image_url VARCHAR(255),

    FOREIGN KEY (category_id)
        REFERENCES categories(id)
);
```

---

# Step 7: Create Cart Table

```sql
CREATE TABLE cart (
    id INT AUTO_INCREMENT PRIMARY KEY,

    user_id INT NOT NULL,

    product_id INT NOT NULL,

    quantity INT DEFAULT 1,

    FOREIGN KEY(user_id)
        REFERENCES users(id),

    FOREIGN KEY(product_id)
        REFERENCES products(id)
);
```

---

# Step 8: Create Orders Table

```sql
CREATE TABLE orders (

    id INT AUTO_INCREMENT PRIMARY KEY,

    user_id INT NOT NULL,

    total_amount DECIMAL(10,2),

    order_status VARCHAR(30),

    payment_status VARCHAR(30),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY(user_id)
        REFERENCES users(id)
);
```

---

# Step 9: Create Order Items Table

```sql
CREATE TABLE order_items (

    id INT AUTO_INCREMENT PRIMARY KEY,

    order_id INT NOT NULL,

    product_id INT NOT NULL,

    quantity INT,

    price DECIMAL(10,2),

    FOREIGN KEY(order_id)
        REFERENCES orders(id),

    FOREIGN KEY(product_id)
        REFERENCES products(id)
);
```

---

# Database Relationships

```text
users
   │
   ├────< cart
   │
   └────< orders
                 │
                 └────< order_items
                               │
                               ▼
                           products
                               ▲
                               │
                        categories
```

---

# Step 10: Insert Categories

```sql
INSERT INTO categories(name,image_url)
VALUES

('Fruits','fruits.jpg'),

('Vegetables','vegetables.jpg'),

('Dairy','dairy.jpg'),

('Beverages','beverages.jpg'),

('Snacks','snacks.jpg');
```

---

# Step 11: Insert Products

```sql
INSERT INTO products
(category_id,product_name,description,price,stock,image_url)

VALUES

(1,'Apple','Fresh Red Apples',120.00,100,'apple.jpg'),

(1,'Banana','Organic Bananas',60.00,200,'banana.jpg'),

(2,'Tomato','Fresh Tomatoes',45.00,300,'tomato.jpg'),

(3,'Milk','Full Cream Milk',55.00,100,'milk.jpg'),

(4,'Coca Cola','Soft Drink',40.00,250,'coke.jpg'),

(5,'Potato Chips','Masala Chips',25.00,500,'chips.jpg');
```

---

# Step 12: Insert Sample User

> **Note:** In production, passwords must be stored as **bcrypt hashes**. The plain text below is for initial database learning only.

```sql
INSERT INTO users

(first_name,last_name,email,password,phone)

VALUES

('Rajesh',

'Naidu',

'rajesh@gmail.com',

'Password123',

'9876543210');
```

---

# Step 13: Verify Tables

```sql
SHOW TABLES;
```

Expected:

```text
categories

products

users

cart

orders

order_items
```

---

# Verify Data

```sql
SELECT * FROM users;

SELECT * FROM categories;

SELECT * FROM products;
```

---

# Sample Product Query

```sql
SELECT
product_name,
price,
stock
FROM products;
```

---

# Products with Category

```sql
SELECT

p.product_name,

c.name AS category,

p.price

FROM products p

JOIN categories c

ON p.category_id=c.id;
```

Example output:

| Product | Category |  Price |
| ------- | -------- | -----: |
| Apple   | Fruits   | 120.00 |
| Banana  | Fruits   |  60.00 |
| Milk    | Dairy    |  55.00 |

---

# Customer Orders

```sql
SELECT

u.first_name,

o.id,

o.total_amount

FROM users u

JOIN orders o

ON u.id=o.user_id;
```

---

# Order Details

```sql
SELECT

o.id,

p.product_name,

oi.quantity,

oi.price

FROM order_items oi

JOIN products p

ON oi.product_id=p.id

JOIN orders o

ON oi.order_id=o.id;
```

---

# Backend Connection

The Node.js backend will connect using:

```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=yourpassword
DB_NAME=zepto_db
```

---

# Folder Structure

```text
database/

init.sql

seed.sql

README.md
```

**init.sql**

Contains:

* Database creation
* Table creation
* Constraints

**seed.sql**

Contains:

* Categories
* Products
* Sample Users
* Sample Orders

---

# Local Testing

Run:

```sql
SHOW TABLES;

SELECT * FROM products;

SELECT * FROM users;

SELECT * FROM categories;
```

If all tables and sample data appear correctly, the database setup is successful.

---

# Git Workflow

```bash
git checkout -b feature/database

git add .

git commit -m "Design MySQL schema and seed sample data"

git push origin feature/database
```

---

# Best Practices

* Use `AUTO_INCREMENT` for primary keys.
* Define foreign keys to maintain referential integrity.
* Store passwords as `bcrypt` hashes (never plain text) in production.
* Use `DECIMAL` for prices instead of floating-point types.
* Normalize the schema to reduce redundancy.
* Keep schema creation (`init.sql`) and sample data (`seed.sql`) in separate files.

---

# Learning Outcomes

After completing **Part 4**, students will be able to:

* Design a relational database for an e-commerce application.
* Create tables with primary and foreign key relationships.
* Seed realistic sample data.
* Write SQL queries to retrieve business information.
* Connect the MySQL database to the Node.js backend.

---

# Project Structure After Part 4

```text
zepto-quick-commerce/
│
├── frontend/
├── backend/
├── database/
│   ├── init.sql
│   ├── seed.sql
│   └── README.md
├── kubernetes/
├── .github/
│   └── workflows/
├── docs/
└── README.md
```

