USE zepto_db;

-- ==========================================
-- USERS
-- ==========================================

INSERT INTO users
(first_name,last_name,email,password,phone,role)

VALUES

('Rajesh','Naidu','rajesh@gmail.com','Password123','9876543210','ADMIN'),

('Rahul','Sharma','rahul@gmail.com','Password123','9876543211','CUSTOMER'),

('Priya','Reddy','priya@gmail.com','Password123','9876543212','CUSTOMER'),

('Sneha','Patel','sneha@gmail.com','Password123','9876543213','CUSTOMER');

-- ==========================================
-- CATEGORIES
-- ==========================================

INSERT INTO categories
(category_name,image_url)

VALUES

('Fruits','fruits.jpg'),

('Vegetables','vegetables.jpg'),

('Dairy','dairy.jpg'),

('Beverages','beverages.jpg'),

('Snacks','snacks.jpg');

-- ==========================================
-- PRODUCTS
-- ==========================================

INSERT INTO products
(category_id,product_name,description,price,stock,image_url)

VALUES

(1,'Apple','Fresh Red Apple',120,150,'apple.jpg'),

(1,'Banana','Organic Banana',60,250,'banana.jpg'),

(1,'Orange','Nagpur Orange',90,200,'orange.jpg'),

(2,'Tomato','Fresh Tomato',40,300,'tomato.jpg'),

(2,'Potato','Fresh Potato',35,500,'potato.jpg'),

(2,'Onion','Fresh Onion',45,400,'onion.jpg'),

(3,'Milk','Full Cream Milk',55,150,'milk.jpg'),

(3,'Curd','Fresh Curd',40,120,'curd.jpg'),

(3,'Butter','Amul Butter',58,100,'butter.jpg'),

(4,'Coca Cola','Soft Drink',40,200,'coke.jpg'),

(4,'Pepsi','Cold Drink',40,200,'pepsi.jpg'),

(4,'Sprite','Lemon Drink',42,180,'sprite.jpg'),

(5,'Lays Chips','Magic Masala',20,500,'lays.jpg'),

(5,'Kurkure','Masala Munch',20,450,'kurkure.jpg'),

(5,'Bingo Chips','Original',25,300,'bingo.jpg');

-- ==========================================
-- CART
-- ==========================================

INSERT INTO cart
(user_id,product_id,quantity)

VALUES

(2,1,2),

(2,4,3),

(3,8,1);

-- ==========================================
-- ORDERS
-- ==========================================

INSERT INTO orders
(user_id,total_amount,order_status,payment_status)

VALUES

(2,360,'DELIVERED','SUCCESS'),

(3,135,'CONFIRMED','SUCCESS');

-- ==========================================
-- ORDER ITEMS
-- ==========================================

INSERT INTO order_items
(order_id,product_id,quantity,price)

VALUES

(1,1,2,120),

(1,4,3,40),

(2,8,1,40),

(2,10,2,40),

(2,15,1,25);
