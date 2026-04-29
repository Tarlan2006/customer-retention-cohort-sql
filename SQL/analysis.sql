-- ============================================================
-- Customer Retention & Cohort Analysis
-- Author  : Baimyrza Tarlan
-- Dataset : Olist Brazilian E-commerce
-- Tools   : PostgreSQL, DBeaver
-- ============================================================
-- Description:
--   This analysis answers the question:
--   "Do customers come back, and how often?"
--
--   We use cohort analysis to track groups of customers
--   from their first purchase and measure retention over time.
-- ============================================================


-- ============================================================
-- QUERY 1 — Main Retention Table
-- ============================================================
-- Steps:
--   1. customer_orders : find first purchase date per customer
--   2. all_orders      : attach cohort_month and order_month
--   3. cohort_data     : calculate months since first purchase
--   4. retention       : count unique users per cohort per month
--   5. final SELECT    : add total cohort size and retention %
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp::timestamp) AS first_purchase_date
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o USING (customer_id)
    GROUP BY c.customer_unique_id
),
all_orders AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', co.first_purchase_date)                AS cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp::timestamp)  AS order_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o USING (customer_id)
    JOIN customer_orders co ON c.customer_unique_id = co.customer_unique_id
),
cohort_data AS (
    SELECT
        customer_unique_id,
        cohort_month,
        order_month,
        (
            EXTRACT(YEAR  FROM AGE(order_month, cohort_month)) * 12 +
            EXTRACT(MONTH FROM AGE(order_month, cohort_month))
        ) AS diff_month
    FROM all_orders
),
retention AS (
    SELECT
        cohort_month,
        diff_month,
        COUNT(DISTINCT customer_unique_id) AS users
    FROM cohort_data
    GROUP BY cohort_month, diff_month
)
SELECT
    cohort_month,
    diff_month,
    users,
    SUM(users) OVER (PARTITION BY cohort_month)                           AS total_cohort_size,
    ROUND(users * 100.0 / SUM(users) OVER (PARTITION BY cohort_month), 1) AS retention_pct
FROM retention
ORDER BY cohort_month, diff_month;


-- ============================================================
-- QUERY 2 — Top Returning Customers
-- ============================================================
-- Which customers came back the most months?
-- These are the most loyal users in the dataset.
-- Uses: CTE, COUNT DISTINCT, WHERE, GROUP BY, ORDER BY
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp::timestamp) AS first_purchase_date
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o USING (customer_id)
    GROUP BY c.customer_unique_id
),
all_orders AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', co.first_purchase_date)                AS cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp::timestamp)  AS order_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o USING (customer_id)
    JOIN customer_orders co ON c.customer_unique_id = co.customer_unique_id
),
cohort_data AS (
    SELECT
        customer_unique_id,
        cohort_month,
        order_month,
        (
            EXTRACT(YEAR  FROM AGE(order_month, cohort_month)) * 12 +
            EXTRACT(MONTH FROM AGE(order_month, cohort_month))
        ) AS diff_month
    FROM all_orders
)
SELECT
    customer_unique_id,
    COUNT(DISTINCT order_month) AS active_months
FROM cohort_data
WHERE diff_month > 0
GROUP BY customer_unique_id
ORDER BY active_months DESC
LIMIT 10;


-- ============================================================
-- QUERY 3 — Large Cohorts Only (HAVING)
-- ============================================================
-- Filter cohorts with more than 100 customers.
-- Small cohorts (2-4 people) skew retention percentages
-- and are not statistically meaningful.
-- Uses: CTE, HAVING, COUNT DISTINCT, GROUP BY
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp::timestamp) AS first_purchase_date
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o USING (customer_id)
    GROUP BY c.customer_unique_id
),
all_orders AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', co.first_purchase_date)                AS cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp::timestamp)  AS order_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o USING (customer_id)
    JOIN customer_orders co ON c.customer_unique_id = co.customer_unique_id
),
cohort_data AS (
    SELECT
        customer_unique_id,
        cohort_month,
        order_month,
        (
            EXTRACT(YEAR  FROM AGE(order_month, cohort_month)) * 12 +
            EXTRACT(MONTH FROM AGE(order_month, cohort_month))
        ) AS diff_month
    FROM all_orders
)
SELECT
    cohort_month,
    COUNT(DISTINCT customer_unique_id) AS cohort_size
FROM cohort_data
WHERE diff_month = 0
GROUP BY cohort_month
HAVING COUNT(DISTINCT customer_unique_id) > 100
ORDER BY cohort_size DESC;


-- ============================================================
-- QUERY 4 — Average Return Month
-- ============================================================
-- On average, how many months after first purchase
-- do customers come back?
-- Low number  = customers return quickly
-- High number = customers take a long time to return
-- Uses: CTE, AVG, ROUND, WHERE
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp::timestamp) AS first_purchase_date
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o USING (customer_id)
    GROUP BY c.customer_unique_id
),
all_orders AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', co.first_purchase_date)                AS cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp::timestamp)  AS order_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o USING (customer_id)
    JOIN customer_orders co ON c.customer_unique_id = co.customer_unique_id
),
cohort_data AS (
    SELECT
        customer_unique_id,
        cohort_month,
        order_month,
        (
            EXTRACT(YEAR  FROM AGE(order_month, cohort_month)) * 12 +
            EXTRACT(MONTH FROM AGE(order_month, cohort_month))
        ) AS diff_month
    FROM all_orders
)
SELECT
    ROUND(AVG(diff_month), 1) AS avg_return_month
FROM cohort_data
WHERE diff_month > 0;