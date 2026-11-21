-- =====================================================================
-- A/B Test: One-Page Checkout  |  SQL analysis
-- Table: ab_test_data(user_id, timestamp, "group", landing_page, device,
--                     user_type, converted, revenue)
-- Written for SQLite, and works in MySQL/PostgreSQL with minor changes
-- ("group" is a reserved word, so it's quoted; in MySQL use `group`).
-- =====================================================================


-- 1. DATA QUALITY CHECKS ------------------------------------------------

-- 1a. Exact duplicate rows
SELECT COUNT(*) - COUNT(DISTINCT user_id || '|' || timestamp || '|' || "group") AS duplicate_rows
FROM ab_test_data;

-- 1b. Rows where the assigned group and the page shown don't match
SELECT "group", landing_page, COUNT(*) AS rows_
FROM ab_test_data
GROUP BY "group", landing_page
ORDER BY "group", landing_page;

-- 1c. Users exposed to BOTH versions (contaminated -> must be excluded)
SELECT COUNT(*) AS users_in_both_groups
FROM (
    SELECT user_id
    FROM ab_test_data
    GROUP BY user_id
    HAVING COUNT(DISTINCT "group") > 1
) t;


-- 2. CLEAN VIEW ---------------------------------------------------------
-- Keep matched rows, drop contaminated users, one row per user.
DROP VIEW IF EXISTS ab_clean;
CREATE VIEW ab_clean AS
WITH matched AS (
    SELECT DISTINCT *
    FROM ab_test_data
    WHERE ("group" = 'control'   AND landing_page = 'old_checkout')
       OR ("group" = 'treatment' AND landing_page = 'new_checkout')
),
contaminated AS (
    SELECT user_id
    FROM ab_test_data
    GROUP BY user_id
    HAVING COUNT(DISTINCT "group") > 1
),
ranked AS (
    SELECT m.*,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY timestamp) AS rn
    FROM matched m
    WHERE user_id NOT IN (SELECT user_id FROM contaminated)
)
SELECT user_id, timestamp, "group", landing_page, device, user_type, converted, revenue
FROM ranked
WHERE rn = 1;


-- 3. SAMPLE RATIO MISMATCH (SRM) CHECK ---------------------------------
-- Expect ~50/50. A big skew means the randomisation is broken.
SELECT "group",
       COUNT(*) AS users,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_users
FROM ab_clean
GROUP BY "group";


-- 4. PRIMARY METRIC: CONVERSION RATE -----------------------------------
SELECT "group",
       COUNT(*)                         AS users,
       SUM(converted)                   AS conversions,
       ROUND(AVG(converted) * 100, 2)   AS conversion_rate_pct
FROM ab_clean
GROUP BY "group";


-- 5. SECONDARY METRICS: REVENUE ----------------------------------------
SELECT "group",
       ROUND(SUM(revenue), 0)                                    AS total_revenue,
       ROUND(AVG(revenue), 2)                                    AS revenue_per_user,
       ROUND(SUM(revenue) * 1.0 / NULLIF(SUM(converted), 0), 2)  AS avg_order_value
FROM ab_clean
GROUP BY "group";


-- 6. SEGMENT BREAKDOWN: DEVICE x GROUP ---------------------------------
SELECT device,
       "group",
       COUNT(*)                        AS users,
       ROUND(AVG(converted) * 100, 2)  AS conversion_rate_pct
FROM ab_clean
GROUP BY device, "group"
ORDER BY device, "group";

-- 6b. Lift by segment in one row each (pivot with CASE)
SELECT device,
       ROUND(AVG(CASE WHEN "group" = 'control'   THEN converted END) * 100, 2) AS control_cr,
       ROUND(AVG(CASE WHEN "group" = 'treatment' THEN converted END) * 100, 2) AS treatment_cr,
       ROUND((AVG(CASE WHEN "group" = 'treatment' THEN converted END)
            - AVG(CASE WHEN "group" = 'control'   THEN converted END)) * 100, 2) AS abs_lift_pp
FROM ab_clean
GROUP BY device;

-- 6c. Same for new vs returning users
SELECT user_type,
       ROUND(AVG(CASE WHEN "group" = 'control'   THEN converted END) * 100, 2) AS control_cr,
       ROUND(AVG(CASE WHEN "group" = 'treatment' THEN converted END) * 100, 2) AS treatment_cr,
       ROUND((AVG(CASE WHEN "group" = 'treatment' THEN converted END)
            - AVG(CASE WHEN "group" = 'control'   THEN converted END)) * 100, 2) AS abs_lift_pp
FROM ab_clean
GROUP BY user_type;


-- 7. DAILY TREND (novelty-effect check) --------------------------------
SELECT DATE(timestamp) AS day,
       ROUND(AVG(CASE WHEN "group" = 'control'   THEN converted END) * 100, 2) AS control_cr,
       ROUND(AVG(CASE WHEN "group" = 'treatment' THEN converted END) * 100, 2) AS treatment_cr
FROM ab_clean
GROUP BY DATE(timestamp)
ORDER BY day;

-- 7b. Week 1 vs later weeks
SELECT CASE WHEN DATE(timestamp) < '2026-09-08' THEN 'week_1' ELSE 'weeks_2_3' END AS period,
       "group",
       COUNT(*) AS users,
       ROUND(AVG(converted) * 100, 2) AS conversion_rate_pct
FROM ab_clean
GROUP BY period, "group"
ORDER BY period, "group";
