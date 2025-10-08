-- sql/analyses.sql
-- SQL Sales Analytics - Analyses and business insights
-- Dialect: MySQL 8+ (window functions / CTEs used)
-- Author: Nyasha Mangwanda
-- Date: 2025-09

/************************************************************
  NOTE:
  - This file is intended to be human-readable: each query
    is preceded by comments that explain what it does and
    what business insight to draw from the result.
  - Use these queries interactively in your SQL client or
    export results to CSV for Tableau.
************************************************************/

-- ===========================
-- Query 01 — Monthly revenue and running total
-- What it does:
--  - Aggregates net revenue by month and computes a cumulative (running) revenue.
-- Business insight:
--  - Shows seasonality and growth; good for an executive trend tile.
WITH monthly AS (
  SELECT
    DATE_FORMAT(order_date, '%Y-%m-01') AS month_start,
    SUM(net_revenue) AS revenue
  FROM v_sales_fact
  GROUP BY month_start
)
SELECT
  month_start,
  revenue,
  SUM(revenue) OVER (ORDER BY month_start ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue
FROM monthly
ORDER BY month_start;


-- ===========================
-- Query 02 — Top products by profit (with margin)
-- What it does:
--  - Ranks products by total profit and computes margin (profit / revenue).
-- Business insight:
--  - Identifies products that contribute most to the bottom line (prioritize inventory & marketing).
SELECT
  product_id,
  product_name,
  category_name,
  SUM(net_revenue) AS revenue,
  SUM(profit)      AS profit,
  CASE WHEN SUM(net_revenue) = 0 THEN NULL
       ELSE ROUND(100 * SUM(profit) / SUM(net_revenue), 2) END AS margin_pct
FROM v_sales_fact
GROUP BY product_id, product_name, category_name
ORDER BY profit DESC
LIMIT 10;


-- ===========================
-- Query 03 — Category profitability summary
-- What it does:
--  - Sums revenue, cost and profit by category.
-- Business insight:
--  - Reveals which categories are most profitable and which may need pricing or cost review.
SELECT
  category_name,
  SUM(net_revenue) AS revenue,
  SUM(total_cost)  AS cost,
  SUM(profit)      AS profit
FROM v_sales_fact
GROUP BY category_name
ORDER BY profit DESC;


-- ===========================
-- Query 04 — Average Order Value (AOV) and items per order
-- What it does:
--  - Computes average order value and average items per order across all orders.
-- Business insight:
--  - AOV and basket size are levers for revenue growth (bundling / upsell opportunity).
WITH order_fin AS (
  SELECT
    order_id,
    SUM(net_revenue) AS order_revenue,
    SUM(quantity)    AS items
  FROM v_sales_fact
  GROUP BY order_id
)
SELECT
  ROUND(AVG(order_revenue),2) AS avg_order_value,
  ROUND(AVG(items),2)         AS avg_items_per_order,
  COUNT(*)                   AS orders_count
FROM order_fin;


-- ===========================
-- Query 05 — RFM basics: recency, frequency, monetary + simple segmentation
-- What it does:
--  - Computes Recency (days since last order), Frequency (#orders), Monetary (total spend)
--  - Scores them using NTILE (1..5) and assigns a simple segment label
-- Business insight:
--  - Use segments for targeted marketing: Champions, Loyal, At Risk, Potential
WITH base AS (
  SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    MAX(o.order_date)                      AS last_order_date,
    COUNT(DISTINCT o.order_id)             AS frequency,
    SUM(v.net_revenue)                     AS monetary
  FROM customers c
  JOIN orders o ON o.customer_id = c.customer_id
  JOIN v_sales_fact v ON v.order_id = o.order_id
  GROUP BY c.customer_id, customer_name
),
scores AS (
  SELECT
    *,
    DATEDIFF(CURRENT_DATE, last_order_date) AS recency_days
  FROM base
),
ranked AS (
  SELECT
    *,
    NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
    NTILE(5) OVER (ORDER BY frequency)          AS f_score,
    NTILE(5) OVER (ORDER BY monetary)           AS m_score
  FROM scores
)
SELECT
  customer_id,
  customer_name,
  recency_days,
  frequency,
  ROUND(monetary,2) AS monetary,
  r_score, f_score, m_score,
  CASE
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
    WHEN r_score >= 4 AND f_score >= 3 THEN 'Loyal'
    WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'At Risk'
    ELSE 'Potential'
  END AS rfm_segment
FROM ranked
ORDER BY monetary DESC, frequency DESC;


-- ===========================
-- Query 06 — Cohort retention by first purchase quarter
-- What it does:
--  - Builds cohorts by quarter of first purchase and computes retention (active customers / cohort size) per active quarter.
-- Business insight:
--  - Use cohort heatmap to monitor retention, onboarding effectiveness and long-term value.
WITH first_order AS (
  SELECT customer_id,
         DATE_FORMAT(MIN(order_date), '%Y-Q%q') AS cohort_q
  FROM orders
  GROUP BY customer_id
),
activity AS (
  SELECT o.customer_id,
         DATE_FORMAT(o.order_date, '%Y-Q%q') AS active_q
  FROM orders o
),
matrix AS (
  SELECT f.cohort_q,
         a.active_q,
         COUNT(DISTINCT a.customer_id) AS active_customers
  FROM first_order f
  JOIN activity a USING (customer_id)
  GROUP BY f.cohort_q, a.active_q
),
cohort_sizes AS (
  SELECT cohort_q, COUNT(DISTINCT customer_id) AS cohort_size
  FROM first_order
  GROUP BY cohort_q
)
SELECT
  m.cohort_q,
  m.active_q,
  m.active_customers,
  c.cohort_size,
  ROUND(100.0 * m.active_customers / c.cohort_size, 1) AS retention_pct
FROM matrix m
JOIN cohort_sizes c USING (cohort_q)
ORDER BY cohort_q, active_q;


-- ===========================
-- Query 07 — Revenue by segment & region with YoY growth
-- What it does:
--  - Aggregates revenue by year, customer segment and region; computes year-over-year growth.
-- Business insight:
--  - Identifies which segments and regions are accelerating or declining (investment decisions).
WITH agg AS (
  SELECT
    YEAR(order_date) AS yr,
    segment,
    region,
    SUM(net_revenue) AS revenue
  FROM v_sales_fact
  GROUP BY yr, segment, region
)
SELECT
  yr,
  segment,
  region,
  revenue,
  ROUND(100 * (revenue - LAG(revenue) OVER (PARTITION BY segment, region ORDER BY yr)) /
        NULLIF(LAG(revenue) OVER (PARTITION BY segment, region ORDER BY yr), 0), 2) AS yoy_growth_pct
FROM agg
ORDER BY segment, region, yr;


-- ===========================
-- Query 08 — Product affinity (frequent product pairs)
-- What it does:
--  - Finds product pairs that appear in the same orders and counts occurrences.
-- Business insight:
--  - Use results to create bundles and cross-sell recommendations.
SELECT
  LEAST(p1.product_name, p2.product_name) AS product_a,
  GREATEST(p1.product_name, p2.product_name) AS product_b,
  COUNT(*) AS together_orders
FROM order_items oi1
JOIN order_items oi2
  ON oi1.order_id = oi2.order_id
 AND oi1.product_id < oi2.product_id
JOIN products p1 ON p1.product_id = oi1.product_id
JOIN products p2 ON p2.product_id = oi2.product_id
GROUP BY product_a, product_b
ORDER BY together_orders DESC
LIMIT 20;


-- ===========================
-- Query 09 — High-value customers at risk (no orders in last 90 days)
-- What it does:
--  - Finds customers whose lifetime spend is high but whose last order was more than 90 days ago.
-- Business insight:
--  - Target these customers with win-back campaigns to recover revenue.
WITH spend AS (
  SELECT customer_id, SUM(net_revenue) AS lifetime_value, MAX(order_date) AS last_order
  FROM v_sales_fact
  GROUP BY customer_id
)
SELECT s.customer_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       ROUND(s.lifetime_value,2) AS lifetime_value,
       s.last_order
FROM spend s
JOIN customers c ON c.customer_id = s.customer_id
WHERE s.lifetime_value >= 1000
  AND s.last_order < (CURRENT_DATE - INTERVAL 90 DAY)
ORDER BY lifetime_value DESC;


-- ===========================
-- Query 10 — Product profitability buckets (CASE)
-- What it does:
--  - Aggregates product profit and assigns margin bands (Low/Mid/High).
-- Business insight:
--  - Quickly segment SKUs for pricing, promotion, or renegotiation.
SELECT
  product_id,
  product_name,
  SUM(net_revenue) AS revenue,
  SUM(profit)      AS profit,
  CASE
    WHEN SUM(net_revenue)=0 THEN 'No Sales'
    WHEN SUM(profit)/SUM(net_revenue) < 0.10 THEN 'Low Margin'
    WHEN SUM(profit)/SUM(net_revenue) < 0.30 THEN 'Mid Margin'
    ELSE 'High Margin'
  END AS margin_band
FROM v_sales_fact
GROUP BY product_id, product_name
ORDER BY profit DESC;


-- ===========================
-- Query 11 — Discount leakage by month
-- What it does:
--  - Calculates gross vs net amounts to quantify dollars lost to discounts per month.
-- Business insight:
--  - Monitor discounting to protect margins; identify months with heavy discounting.
WITH lines AS (
  SELECT
    order_date,
    (unit_price * quantity) AS gross_amount,
    (unit_price * quantity) * (1 - discount_rate) AS net_amount
  FROM v_sales_fact
)
SELECT
  DATE_FORMAT(order_date, '%Y-%m-01') AS month_start,
  ROUND(SUM(gross_amount - net_amount),2) AS discount_dollars,
  ROUND(SUM(net_amount),2) AS realized_revenue,
  ROUND(100.0 * SUM(gross_amount - net_amount) /
        NULLIF(SUM(gross_amount),0), 2) AS discount_rate_pct_of_gross
FROM lines
GROUP BY month_start
ORDER BY month_start;


-- ===========================
-- Query 12 — Sales rep leaderboard with profit & revenue rank
-- What it does:
--  - Aggregates revenue and profit per sales rep and ranks them.
-- Business insight:
--  - Identifies top-performing reps and those who might be discounting too much (high revenue but low profit).
SELECT
  employee_id,
  sales_rep,
  ROUND(SUM(net_revenue),2) AS total_revenue,
  ROUND(SUM(profit),2)      AS total_profit,
  RANK() OVER (ORDER BY SUM(net_revenue) DESC) AS rev_rank,
  RANK() OVER (ORDER BY SUM(profit) DESC)      AS profit_rank
FROM v_sales_fact
GROUP BY employee_id, sales_rep
ORDER BY rev_rank;


-- ===========================
-- End of analyses.sql
-- Save, commit and push this file to your repo under: sql/analyses.sql
-- Suggested commit message: "feat(sql): add analysis queries with explanations"
