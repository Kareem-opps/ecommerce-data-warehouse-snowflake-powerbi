--Create Database and schema
CREATE DATABASE ecommerce_db;
CREATE SCHEMA raw;
CREATE SCHEMA staging;
CREATE SCHEMA analytics;

ALTER TABLE "raw.orders" RENAME TO orders;

--Create new clean table ECOMMERCE_DB.STAGING.ORDERS from ECOMMERCE_DB.RAW.ORDERS
--Use DATEDIFF to Know the number of days it took to delivered orders
CREATE OR REPLACE TABLE staging.orders AS
SELECT
    order_id,
    customer_id,
    order_status,

    order_purchase_timestamp AS purchase_ts,
    order_delivered_customer_date AS delivered_ts,

    CASE 
        WHEN order_delivered_customer_date IS NOT NULL THEN
            DATEDIFF(
                day,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        ELSE NULL
    END AS delivery_days

FROM raw.orders;

--Create new clean table ECOMMERCE_DB.STAGING.ORDER_ITEMS from ECOMMERCE_DB.RAW.ORDER_ITEMS
--Use COALESCE(PRICE, 0) to REPLACE NULLS = 0
CREATE OR REPLACE TABLE ECOMMERCE_DB.STAGING.ORDER_ITEMS AS
SELECT
    ORDER_ID,
    ORDER_ITEM_ID,
    PRODUCT_ID,
    SELLER_ID,
    SHIPPING_LIMIT_DATE,

    PRICE,
    FREIGHT_VALUE,

    COALESCE(PRICE, 0) + COALESCE(FREIGHT_VALUE, 0) AS total_price

FROM ECOMMERCE_DB.RAW.ORDER_ITEMS;

--Create new clean table ECOMMERCE_DB.STAGING.ORDER_PAYMENTS from ECOMMERCE_DB.RAW.ORDER_PAYMENTS
--Use CTE To avoid repetition
CREATE OR REPLACE TABLE ECOMMERCE_DB.STAGING.ORDER_PAYMENTS AS
WITH payments_clean AS (
    SELECT
        ORDER_ID,
        PAYMENT_SEQUENTIAL,
        PAYMENT_TYPE,
        PAYMENT_INSTALLMENTS,
        COALESCE(PAYMENT_VALUE, 0) AS payment_value
    FROM ECOMMERCE_DB.RAW.ORDER_PAYMENTS
)

SELECT
    *,
    CASE
        WHEN payment_value > 500 THEN 'High'
        WHEN payment_value BETWEEN 100 AND 500 THEN 'Medium'
        ELSE 'Low'
    END AS payment_category
FROM payments_clean;
    
--Create new clean table ECOMMERCE_DB.STAGING.CUSTOMERS from ECOMMERCE_DB.RAW.CUSTOMERS
CREATE OR REPLACE TABLE ECOMMERCE_DB.STAGING.CUSTOMERS AS
SELECT 
    CUSTOMER_ID,
    CUSTOMER_UNIQUE_ID,
    TRIM(LOWER(CUSTOMER_CITY)) AS customer_city,
    COALESCE(CUSTOMER_STATE, 'unknown') AS customer_state
FROM ECOMMERCE_DB.RAW.CUSTOMERS;
--Create new clean table ECOMMERCE_DB.STAGING.PRODUCTS from ECOMMERCE_DB.RAW.PRODUCTS
CREATE OR REPLACE TABLE ECOMMERCE_DB.STAGING.PRODUCTS AS 
SELECT 
    PRODUCT_ID,
    COALESCE(PRODUCT_CATEGORY_NAME, 'unknown') AS product_category_name,
    
    COALESCE(PRODUCT_WEIGHT_G, 0) AS product_weight_g,
    COALESCE(PRODUCT_LENGTH_CM, 0) AS product_length_cm,
    COALESCE(PRODUCT_HEIGHT_CM, 0) AS product_height_cm,
    COALESCE(PRODUCT_WIDTH_CM, 0) AS product_width_cm,

    COALESCE(PRODUCT_LENGTH_CM, 0) 
    * COALESCE(PRODUCT_HEIGHT_CM, 0) 
    * COALESCE(PRODUCT_WIDTH_CM, 0) AS product_volume

FROM ECOMMERCE_DB.RAW.PRODUCTS;
