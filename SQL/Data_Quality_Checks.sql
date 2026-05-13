-- Checking missing data 

SELECT COUNT(*) 
FROM ECOMMERCE_DB.STAGING.ORDERS
WHERE order_id IS NULL;

-- Checking Duplicates 

SELECT order_id, COUNT(*)
FROM ECOMMERCE_DB.STAGING.ORDERS
GROUP BY order_id
HAVING COUNT(*) > 1;

--Range Checks

SELECT *
FROM staging.order_items
WHERE price < 0;

-- are there any orders without customers 

SELECT *
FROM staging.orders o
LEFT JOIN staging.customers c
ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
--==================== ALL CHECKS ARE DONE WITH GOOD RESULT ====================--