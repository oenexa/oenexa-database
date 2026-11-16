-- ==============================================================================
-- OENGO Quick-Commerce Domain Schema (oengo_commerce_db)
-- Merchants, Stores, Menus, Orders, Drivers, Delivery Missions & Escrow
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums
CREATE TYPE order_status_enum AS ENUM (
    'CREATED', 'CONFIRMED', 'PREPARING', 'READY_FOR_PICKUP', 
    'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'CANCELED', 'REFUNDED'
);
CREATE TYPE driver_status_enum AS ENUM ('OFFLINE', 'ONLINE_AVAILABLE', 'BUSY_MISSION', 'SUSPENDED');
CREATE TYPE mission_status_enum AS ENUM ('ASSIGNED', 'ARRIVED_MERCHANT', 'PICKED_UP', 'ARRIVED_CUSTOMER', 'COMPLETED', 'CANCELED');

-- 1. Merchants & Stores
CREATE TABLE IF NOT EXISTS merchants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- Identity reference
    business_name VARCHAR(150) NOT NULL,
    category VARCHAR(64) NOT NULL, -- RESTAURANT, GROCERY, PHARMACY
    phone VARCHAR(32) NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    store_name VARCHAR(150) NOT NULL,
    address TEXT NOT NULL,
    latitude NUMERIC(10, 7) NOT NULL,
    longitude NUMERIC(10, 7) NOT NULL,
    delivery_radius_km NUMERIC(5, 2) NOT NULL DEFAULT 10.0,
    is_accepting_orders BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Menus & Items
CREATE TABLE IF NOT EXISTS menu_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS menu_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID NOT NULL REFERENCES menu_categories(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
    image_url TEXT,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Customers & Orders
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS customer_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    label VARCHAR(64) NOT NULL DEFAULT 'Home',
    street_address TEXT NOT NULL,
    latitude NUMERIC(10, 7) NOT NULL,
    longitude NUMERIC(10, 7) NOT NULL,
    delivery_instructions TEXT
);

CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_code VARCHAR(32) UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES customers(id),
    store_id UUID NOT NULL REFERENCES stores(id),
    delivery_address_id UUID NOT NULL REFERENCES customer_addresses(id),
    status order_status_enum NOT NULL DEFAULT 'CREATED',
    subtotal NUMERIC(12, 2) NOT NULL,
    delivery_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    platform_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount > 0),
    payment_intent_id UUID, -- Pay service reference
    escrow_locked BOOLEAN NOT NULL DEFAULT FALSE,
    special_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL,
    total_price NUMERIC(12, 2) NOT NULL
);

-- 4. Drivers & Delivery Missions
CREATE TABLE IF NOT EXISTS drivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    vehicle_type VARCHAR(32) NOT NULL, -- BICYCLE, MOTORCYCLE, CAR
    status driver_status_enum NOT NULL DEFAULT 'OFFLINE',
    current_latitude NUMERIC(10, 7),
    current_longitude NUMERIC(10, 7),
    last_location_update TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS delivery_missions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID UNIQUE NOT NULL REFERENCES orders(id),
    driver_id UUID REFERENCES drivers(id),
    status mission_status_enum NOT NULL DEFAULT 'ASSIGNED',
    pickup_deadline TIMESTAMPTZ,
    delivery_deadline TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_store ON orders(store_id, status);
CREATE INDEX IF NOT EXISTS idx_drivers_status ON drivers(status);
CREATE INDEX IF NOT EXISTS idx_missions_driver ON delivery_missions(driver_id, status);
