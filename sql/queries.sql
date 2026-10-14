CREATE TABLE IF NOT EXISTS master_customer_summary AS
WITH order_summary AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(net_sales) AS total_net_sales,
        SUM(profit) AS total_profit,
        MAX(order_date) AS last_order_date,
        ROUND(SUM(net_sales) * 1.0 / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS avg_basket_size
    FROM ecommerce_sales_customer_analytics_150k
    WHERE UPPER(TRIM(order_status)) = 'COMPLETED'
    GROUP BY customer_id),

customer_aggregated AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.customer_age,
    
        CASE 
            WHEN c.customer_age < 25 THEN 'Under 25'
            WHEN c.customer_age BETWEEN 25 AND 34 THEN '25-34'
            WHEN c.customer_age BETWEEN 35 AND 44 THEN '35-44'
            WHEN c.customer_age BETWEEN 45 AND 54 THEN '45-54'
            ELSE '55+'
        END AS age_group,
        
        c.gender,
        c.customer_segment,
        c.customer_city,
        c.customer_country,
        c.region,

        COALESCE(o.total_orders, 0) AS total_orders,
        COALESCE(o.total_net_sales, 0) AS total_net_sales,
        COALESCE(o.total_profit, 0) AS total_profit,
        COALESCE(o.avg_basket_size, 0) AS avg_basket_size,
        
        CASE 
            WHEN o.last_order_date IS NULL THEN NULL 
            ELSE CAST(JULIANDAY('2025-12-31') - JULIANDAY(o.last_order_date) AS INTEGER) 
        END AS recency_days,
        
        CASE 
            WHEN o.last_order_date IS NULL THEN 'No Purchase'
            WHEN (JULIANDAY('2025-12-31') - JULIANDAY(o.last_order_date)) > 90 THEN 'Churn Risk'
            ELSE 'Active'
        END AS churn_status
    FROM customer_master c
    LEFT JOIN order_summary o ON c.customer_id = o.customer_id)

SELECT *,
    SUM(total_profit) OVER (ORDER BY total_profit DESC, customer_id ASC) AS cumulative_profit,
    ROUND(SUM(total_profit) OVER (ORDER BY total_profit DESC, customer_id ASC) * 100.0 / NULLIF(SUM(total_profit) OVER (), 0), 2) AS cum_profit_pct
FROM customer_aggregated;
