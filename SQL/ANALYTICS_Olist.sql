--DIM TABLE: DIM_CUSTOMERS

CREATE OR REPLACE TABLE ANALYTICS.DIM_CUSTOMERS AS
SELECT DISTINCT
    CUSTOMER_ID,
    CUSTOMER_UNIQUE_ID,
    CUSTOMER_CITY,
    CUSTOMER_STATE
FROM ECOMMERCE_DB.STAGING.CUSTOMERS;

-- DIM TABLE: DIM_PRODUCTS

CREATE OR REPLACE TABLE ANALYTICS.DIM_PRODUCTS AS
SELECT DISTINCT
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    product_volume
FROM ECOMMERCE_DB.STAGING.PRODUCTS;

-- =========================================
-- FACT TABLE: fact_order_items
-- Grain: one row per order item
-- Purpose: store transactional + measurable data
-- =========================================

-- =========================================
-- FACT TABLE: fact_order_items
-- Grain: one row per order item
-- Purpose: transactional table for sales analysis
-- =========================================

CREATE OR REPLACE TABLE ECOMMERCE_DB.ANALYTICS.FACT_ORDER_ITEMS AS

WITH payments_agg AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM ECOMMERCE_DB.STAGING.ORDER_PAYMENTS
    GROUP BY order_id
)

SELECT
    ROW_NUMBER() OVER (ORDER BY oi.order_id, oi.product_id) AS fact_id,

    -- Business keys
    oi.order_id,
    oi.product_id,
    oi.seller_id,
    o.customer_id,

    -- Metrics
    oi.price,
    oi.freight_value,
    oi.total_price,

    -- Business metric for BI
    oi.price + oi.freight_value AS total_revenue,

    pay.payment_value,

    -- Order status
    o.order_status,

    -- Dates
    o.purchase_ts,
    CAST(o.purchase_ts AS DATE) AS purchase_date,
    o.delivered_ts,
    o.delivery_days

FROM ECOMMERCE_DB.STAGING.ORDER_ITEMS oi

JOIN ECOMMERCE_DB.STAGING.ORDERS o
    ON oi.order_id = o.order_id

LEFT JOIN payments_agg pay
    ON oi.order_id = pay.order_id;

-- =========================================
-- DIMENSION TABLE: dim_date
-- Purpose: enable time-based analytics
-- =========================================

CREATE OR REPLACE TABLE ECOMMERCE_DB.ANALYTICS.DIM_DATE AS

SELECT DISTINCT

    -- Remove time and keep only date
    CAST(purchase_ts AS DATE) AS full_date,

    -- Extract year
    YEAR(purchase_ts) AS year,

    -- Extract month
    MONTH(purchase_ts) AS month,

    -- Extract day
    DAY(purchase_ts) AS day,

    -- Extract weekday number
    DAYOFWEEK(purchase_ts) AS day_of_week

FROM ECOMMERCE_DB.STAGING.ORDERS;

-- =========================================
-- =========================================
-- KPI 1: Monthly Revenue Trend
-- Purpose: Analyze revenue growth over time
-- =========================================

SELECT
    dd.year,
    dd.month,
    -- Total revenue per month
    SUM(fo.total_price) AS total_revenue

FROM ECOMMERCE_DB.ANALYTICS.FACT_ORDER_ITEMS fo
JOIN ECOMMERCE_DB.ANALYTICS.DIM_DATE dd
    ON CAST(fo.purchase_ts AS DATE) = dd.full_date

GROUP BY dd.year, dd.month
ORDER BY dd.year, dd.month;

-- =========================================
-- KPI 2: Top Customers by Revenue
-- Purpose: Identify highest spending customers
-- =========================================

SELECT
    c.customer_id,
    c.customer_state,
    -- Total spending per customer
    SUM(fo.total_price) AS total_revenue

FROM ECOMMERCE_DB.ANALYTICS.FACT_ORDER_ITEMS fo

JOIN ECOMMERCE_DB.ANALYTICS.DIM_CUSTOMERS c
    ON fo.customer_id = c.customer_id

GROUP BY
    c.customer_id,
    c.customer_state

ORDER BY total_revenue DESC;

-- =========================================
-- KPI 3: Average Order Value (AOV)
-- Purpose: Measure average revenue per order
-- =========================================

SELECT

    -- Number of unique orders
    COUNT(DISTINCT order_id) AS no_orders,

    -- Total business revenue
    SUM(total_price) AS total_revenue,

    -- Average payment amount
    AVG(payment_value) AS avg_payment,

    -- Average Order Value (AOV)
    SUM(total_price) / COUNT(DISTINCT order_id) AS avg_order_value

FROM ECOMMERCE_DB.ANALYTICS.FACT_ORDER_ITEMS;

--KPI 4 — Cancellation Analysis

SELECT

    COUNT(DISTINCT f.order_id) AS canceled_orders,

    SUM(f.total_price) AS lost_revenue

FROM ECOMMERCE_DB.ANALYTICS.FACT_ORDER_ITEMS f

JOIN ECOMMERCE_DB.STAGING.ORDERS o
    ON f.order_id = o.order_id

WHERE o.order_status = 'canceled';

--KPI 5: Top Product Categories by Revenue

SELECT

    p.product_category_name,
    SUM(f.total_price) AS total_revenue,
    COUNT(DISTINCT f.order_id) AS total_orders

FROM ECOMMERCE_DB.ANALYTICS.FACT_ORDER_ITEMS f

JOIN ECOMMERCE_DB.ANALYTICS.DIM_PRODUCTS p
    ON f.product_id = p.product_id

GROUP BY p.product_category_name
ORDER BY total_revenue DESC;

--KPI 6 — Sales by State

SELECT

    c.customer_state,
    SUM(f.total_price) AS total_revenue,
    COUNT(DISTINCT f.order_id) AS total_orders

FROM ECOMMERCE_DB.ANALYTICS.FACT_ORDER_ITEMS f

JOIN ECOMMERCE_DB.ANALYTICS.DIM_CUSTOMERS c
    ON f.customer_id = c.customer_id

GROUP BY c.customer_state
ORDER BY total_revenue DESC;

--KPI 7 — Delivery Performance

SELECT

    AVG(delivery_days) AS avg_delivery_days,
    MAX(delivery_days) AS max_delivery_days,
    MIN(delivery_days) AS min_delivery_days

FROM ECOMMERCE_DB.ANALYTICS.FACT_ORDER_ITEMS;

--KPI 8 — Payment Type Analysis

SELECT

    payment_type,
    COUNT(*) AS total_transactions,
    SUM(payment_value) AS total_payment_value

FROM ECOMMERCE_DB.STAGING.ORDER_PAYMENTS

GROUP BY payment_type
ORDER BY total_payment_value DESC;


