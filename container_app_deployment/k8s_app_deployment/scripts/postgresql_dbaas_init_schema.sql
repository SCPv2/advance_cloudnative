--
-- Creative Energy Database Initialization Schema - External DB
-- Compatible with PostgreSQL 16.8
-- Target: db.your_private_domain_name.net:2866 (기본값), Database: cedb, User: cedbadmin
-- Optimized for app.your_private_domain_name.net app-server connection
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET statement_timeout = 0;
SET client_min_messages = warning;

-- External Database Connection Info:
-- Host: db.your_private_domain_name.net
-- Port: 2866 (기본값)
-- Database: cedb
-- User: cedbadmin (admin/app user)
-- Password: cedbadmin123!
-- This schema will be applied to the existing cedb database

-- =====================================
-- 1. DATABASE CONNECTION TEST
-- =====================================
SELECT 'DB 연결 성공!' as connection_status, NOW() as current_time;

-- Database information check
SELECT 
    current_database() as database_name,
    current_user as current_user,
    version() as postgresql_version;

-- =====================================
-- 2. SEQUENCES
-- =====================================

CREATE SEQUENCE IF NOT EXISTS products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE SEQUENCE IF NOT EXISTS inventory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE SEQUENCE IF NOT EXISTS orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- =====================================
-- 3. TABLES
-- =====================================

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id integer NOT NULL DEFAULT nextval('products_id_seq'::regclass),
    title character varying(255) NOT NULL,
    subtitle character varying(255),
    price character varying(20) NOT NULL,
    price_numeric integer NOT NULL,
    image character varying(255),
    category character varying(50),
    type character varying(50),
    badge character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

-- Inventory table
CREATE TABLE IF NOT EXISTS inventory (
    id integer NOT NULL DEFAULT nextval('inventory_id_seq'::regclass),
    product_id integer NOT NULL,
    stock_quantity integer DEFAULT 100 NOT NULL,
    reserved_quantity integer DEFAULT 0 NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id integer NOT NULL DEFAULT nextval('orders_id_seq'::regclass),
    customer_name character varying(100) NOT NULL,
    product_id integer NOT NULL,
    quantity integer NOT NULL,
    unit_price integer NOT NULL,
    total_price integer NOT NULL,
    order_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    status character varying(20) DEFAULT 'completed'::character varying
);

-- =====================================
-- 4. FUNCTIONS
-- =====================================

-- Function to process order inventory
CREATE OR REPLACE FUNCTION process_order_inventory(p_product_id integer, p_quantity integer) 
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    current_stock INTEGER;
BEGIN
    -- Get current stock with lock
    SELECT stock_quantity INTO current_stock 
    FROM inventory 
    WHERE product_id = p_product_id
    FOR UPDATE;
    
    -- Check if stock is sufficient
    IF current_stock IS NULL OR current_stock < p_quantity THEN
        RETURN FALSE;
    END IF;
    
    -- Reduce stock
    UPDATE inventory 
    SET stock_quantity = stock_quantity - p_quantity,
        updated_at = CURRENT_TIMESTAMP
    WHERE product_id = p_product_id;
    
    RETURN TRUE;
END;
$$;

-- Function to reset daily inventory
CREATE OR REPLACE FUNCTION reset_daily_inventory() 
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE inventory 
    SET stock_quantity = 100, 
        reserved_quantity = 0,
        updated_at = CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Daily inventory reset completed at %', CURRENT_TIMESTAMP;
END;
$$;

-- Function to update inventory timestamp
CREATE OR REPLACE FUNCTION update_inventory_timestamp() 
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- Function to update products timestamp
CREATE OR REPLACE FUNCTION update_products_timestamp() 
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =====================================
-- 5. PRIMARY KEY CONSTRAINTS
-- =====================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'products_pkey' AND contype = 'p'
    ) THEN
        ALTER TABLE ONLY products ADD CONSTRAINT products_pkey PRIMARY KEY (id);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'inventory_pkey' AND contype = 'p'
    ) THEN
        ALTER TABLE ONLY inventory ADD CONSTRAINT inventory_pkey PRIMARY KEY (id);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'orders_pkey' AND contype = 'p'
    ) THEN
        ALTER TABLE ONLY orders ADD CONSTRAINT orders_pkey PRIMARY KEY (id);
    END IF;
END;
$$;

-- =====================================
-- 6. INDEXES
-- =====================================

CREATE INDEX IF NOT EXISTS idx_products_category ON products USING btree (category);
CREATE INDEX IF NOT EXISTS idx_products_type ON products USING btree (type);
CREATE INDEX IF NOT EXISTS idx_inventory_product_id ON inventory USING btree (product_id);
CREATE INDEX IF NOT EXISTS idx_orders_product_id ON orders USING btree (product_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON orders USING btree (order_date);
CREATE INDEX IF NOT EXISTS idx_orders_customer_name ON orders USING btree (customer_name);

-- =====================================
-- 7. FOREIGN KEY CONSTRAINTS
-- =====================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'inventory_product_id_fkey'
    ) THEN
        ALTER TABLE inventory
            ADD CONSTRAINT inventory_product_id_fkey 
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'orders_product_id_fkey'
    ) THEN
        ALTER TABLE orders
            ADD CONSTRAINT orders_product_id_fkey 
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;
    END IF;
END;
$$;

-- =====================================
-- 8. TRIGGERS
-- =====================================

DO $$
BEGIN
    -- Drop trigger if exists and recreate
    DROP TRIGGER IF EXISTS trigger_update_inventory_timestamp ON inventory;
    CREATE TRIGGER trigger_update_inventory_timestamp 
        BEFORE UPDATE ON inventory 
        FOR EACH ROW EXECUTE FUNCTION update_inventory_timestamp();
    
    DROP TRIGGER IF EXISTS trigger_update_products_timestamp ON products;
    CREATE TRIGGER trigger_update_products_timestamp 
        BEFORE UPDATE ON products 
        FOR EACH ROW EXECUTE FUNCTION update_products_timestamp();
END;
$$;

-- =====================================
-- 9. VIEWS
-- =====================================

CREATE OR REPLACE VIEW product_inventory_view AS
SELECT 
    p.id,
    p.title,
    p.subtitle,
    p.price,
    p.price_numeric,
    p.image,
    p.category,
    p.type,
    p.badge,
    COALESCE(i.stock_quantity, 0) AS stock_quantity,
    COALESCE(i.reserved_quantity, 0) AS reserved_quantity,
    CASE 
        WHEN COALESCE(i.stock_quantity, 0) = 0 THEN '매진'
        ELSE COALESCE(i.stock_quantity, 0)::text
    END AS stock_display
FROM products p
LEFT JOIN inventory i ON p.id = i.product_id;

-- =====================================
-- 10. INITIAL DATA
-- =====================================

INSERT INTO products (id, title, subtitle, price, price_numeric, image, category, type, badge, created_at, updated_at) VALUES
(1, 'BigBoys 1st Full Album [SimplyFit] Standard Edition', 'Standard Edition', '18,500원', 18500, '../media/img/bb_prod1.png', 'bigboys', 'album', 'NEW', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, 'BigBoys 1st Full Album [SimplyFit] Limited Edition', 'with Photo Book & Photo Cards', '35,000원', 35000, '../media/img/bb_prod2.png', 'bigboys', 'LIMITED', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(3, 'BigBoys Official Light Stick', 'Ver. 1.0', '42,000원', 42000, '../media/img/bb_prod3.png', 'bigboys', 'goods', 'LIMITED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(4, 'BigBoys Official T-Shirt', 'Black / White Available', '28,000원', 28000, '../media/img/bb_prod4.png', 'bigboys', 'goods', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(5, 'Cloudy 2nd Official Album [JUMP]', 'Purple Ver.', '16,800원', 16800, 'https://object-store.kr-west1.e.samsungsdscloud.com/thisneedstobereplaced1234:ceweb/media/img/cloudy_prod1.png', 'cloudy', 'album', 'NEW', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(6, 'Cloudy 1st Official Album [In the Sky]', 'Sky Blue Ver.', '16,800원', 16800, 'https://object-store.kr-west1.e.samsungsdscloud.com/thisneedstobereplaced1234:ceweb/media/img/cloudy_prod2.png', 'cloudy', 'album', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(7, 'Cloudy Official Merchandise', 'Eco Bag', '40,000원', 40000, '../media/img/cloudy_prod3.png', 'cloudy', 'goods', 'LIMITED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(8, 'Cloudy Official Light Stick', 'Ver. 2.0', '42,000원', 42000, '../media/img/cloudy_prod4.png', 'cloudy', 'goods', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;

INSERT INTO inventory (id, product_id, stock_quantity, reserved_quantity, updated_at) VALUES
(1, 1, 100, 0, CURRENT_TIMESTAMP),
(2, 2, 100, 0, CURRENT_TIMESTAMP),
(3, 3, 100, 0, CURRENT_TIMESTAMP),
(4, 4, 100, 0, CURRENT_TIMESTAMP),
(5, 5, 100, 0, CURRENT_TIMESTAMP),
(6, 6, 100, 0, CURRENT_TIMESTAMP),
(7, 7, 100, 0, CURRENT_TIMESTAMP),
(8, 8, 100, 0, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;

-- =====================================
-- 11. SEQUENCE ADJUSTMENTS
-- =====================================

ALTER SEQUENCE products_id_seq OWNED BY products.id;
ALTER SEQUENCE inventory_id_seq OWNED BY inventory.id;
ALTER SEQUENCE orders_id_seq OWNED BY orders.id;

SELECT setval('products_id_seq', 8, true);
SELECT setval('inventory_id_seq', 8, true);
SELECT setval('orders_id_seq', 1, false);

-- =====================================
-- 12. VERIFICATION AND MONITORING
-- =====================================

-- Table creation verification
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('products', 'inventory', 'orders')
ORDER BY table_name;

-- Function verification
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name LIKE '%inventory%'
ORDER BY routine_name;

-- View verification
SELECT 
    table_name
FROM information_schema.views 
WHERE table_schema = 'public'
ORDER BY table_name;

-- Initial data verification
SELECT 
    '상품 테이블' as table_info,
    COUNT(*) as record_count 
FROM products
UNION ALL
SELECT 
    '재고 테이블' as table_info,
    COUNT(*) as record_count 
FROM inventory
UNION ALL
SELECT 
    '주문 테이블' as table_info,
    COUNT(*) as record_count 
FROM orders;

-- Sample data display
SELECT 
    id,
    title,
    category,
    stock_quantity,
    stock_display
FROM product_inventory_view 
ORDER BY id 
LIMIT 5;

-- =====================================
-- 13. CONNECTION TEST QUERIES FOR APP SERVER
-- =====================================

-- Test queries that app-server will use
SELECT 'App-server connection test successful!' as test_result;

-- Products API endpoint test
SELECT 
    id, 
    title, 
    subtitle,
    price, 
    price_numeric,
    image,
    category, 
    type,
    badge
FROM products 
ORDER BY id;

-- Inventory API endpoint test
SELECT 
    p.id,
    p.title,
    p.subtitle,
    p.price,
    p.price_numeric,
    p.image,
    p.category,
    p.type,
    p.badge,
    COALESCE(i.stock_quantity, 0) as stock_quantity,
    CASE 
        WHEN COALESCE(i.stock_quantity, 0) = 0 THEN '매진'
        ELSE COALESCE(i.stock_quantity, 0)::text
    END as stock_display
FROM products p
LEFT JOIN inventory i ON p.id = i.product_id
ORDER BY p.id;

-- =====================================
-- 14. COMPLETION STATUS
-- =====================================

SELECT 
    'Creative Energy External Database Setup Complete!' as setup_status,
    'db.your_private_domain_name.net:2866 (기본값)' as database_server,
    'cedb' as database_name,
    'cedbadmin' as database_user,
    current_timestamp as completion_time;