-- 1. Общее количество пользователей
WITH sessions_by_date AS (
    SELECT
	source,
        DATE(visit_date) AS visit_date,
        COUNT(DISTINCT visitor_id) AS visitors_count
    FROM sessions
    GROUP BY 1, 2
)

SELECT 
    source
    visit_date,
    sessions_by_date.visitors_count
FROM sessions_by_date
ORDER BY visit_date;

-- 2. Каналы привлечения пользователей по дням
WITH sessions_by_source_date AS (
    SELECT
        source,
        DATE(visit_date) AS visit_date,
        COUNT(DISTINCT visitor_id) AS visitors_count
    FROM sessions
    GROUP BY source, DATE(visit_date)
)
SELECT
    visit_date,
    source,
    visitors_count
FROM sessions_by_source_date
WHERE source NOT LIKE 'organic'
GROUP BY visit_date, source, visitors_count
ORDER BY visit_date, source;

-- 3. Общее количество лидов
SELECT COUNT(DISTINCT lead_id) AS leads_count
FROM leads;

-- 4. Конверсия из клика в лид
WITH sessions_leads AS (
    SELECT
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        DATE(s.visit_date) AS visit_date,
        COUNT(DISTINCT s.visitor_id) AS visitors_count,
        COUNT(DISTINCT l.lead_id) AS leads_count
    FROM sessions AS s
    LEFT JOIN leads AS l
        ON s.visitor_id = l.visitor_id
    GROUP BY 1, 2, 3, 4
)

SELECT
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    visitors_count,
    leads_count,
    ROUND(CAST(leads_count AS DECIMAL) / visitors_count * 100, 2)
	AS click_to_lead_conversion
FROM sessions_leads
ORDER BY visit_date, utm_source, utm_medium, utm_campaign;

-- 5. Конверсия из лида в оплату
WITH leads_purchases AS (
    SELECT
        DATE(created_at) AS created_date,
        COUNT(DISTINCT lead_id) AS leads_count,
        COUNT(CASE WHEN status_id = 142 OR
	closing_reason = 'Успешно реализовано' THEN lead_id END)
	AS purchases_count
    FROM leads
    GROUP BY 1
)

SELECT
    created_date,
    leads_count,
    purchases_count,
    ROUND(CAST(purchases_count AS DECIMAL)/leads_count * 100, 2)
	AS lead_to_purchase_conversion
FROM leads_purchases
ORDER BY created_date;

-- 6. Затраты по каналам
WITH ads_by_source_date AS (
    SELECT
        DATE(campaign_date) AS campaign_date,
        utm_source,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY 1, 2
    UNION ALL
    SELECT
        DATE(campaign_date) AS campaign_date,
        utm_source,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY 1, 2
)

SELECT
    campaign_date,
    utm_source,
    total_cost
FROM ads_by_source_date
ORDER BY campaign_date, utm_source;

-- 7. Окупаемость каналов
WITH channel_metrics AS (
    SELECT
        DATE(s.visit_date) AS visit_date,
        s.source,
        COUNT(DISTINCT s.visitor_id) AS visitors_count,
        SUM(l.amount) AS revenue,
        SUM(a.daily_spent) AS total_cost,
        COUNT(DISTINCT l.lead_id) AS leads_count,
        COUNT(CASE WHEN l.status_id = 142 
        OR l.closing_reason = 'Успешно реализовано' 
	THEN l.lead_id END) 
	AS purchases_count
    FROM sessions AS s
    LEFT JOIN leads AS l
        ON s.visitor_id = l.visitor_id
    LEFT JOIN (
        SELECT
            DATE(campaign_date) AS campaign_date,
            utm_source,
            SUM(daily_spent) AS daily_spent
        FROM vk_ads
        GROUP BY 1, 2
        UNION ALL
        SELECT
            DATE(campaign_date) AS campaign_date,
            utm_source,
            SUM(daily_spent) AS daily_spent
        FROM ya_ads
        GROUP BY 1, 2
    ) AS a
        ON s.source = a.utm_source 
	AND DATE(s.visit_date) = a.campaign_date
    GROUP BY 1, 2
)

SELECT
    visit_date,
    source,
    visitors_count,
    revenue,
    total_cost,
    ROUND(total_cost / visitors_count, 2) AS cpu,
    CASE WHEN leads_count = 0 THEN NULL ELSE ROUND(total_cost/leads_count, 2) 
    END AS cpl,
    CASE WHEN purchases_count = 0 THEN NULL 
    ELSE ROUND(total_cost/purchases_count, 2) END AS cppu,
    CASE WHEN total_cost = 0 THEN NULL 
    ELSE ROUND((revenue - total_cost) / total_cost * 100, 2) END AS roi
FROM channel_metrics
ORDER BY visit_date, roi DESC NULLS LAST;

-- 8. Сводная таблица по source, medium, campaign
WITH channel_metrics AS (
    SELECT
        DATE(s.visit_date) AS visit_date,
        s.source,
        s.medium,
        s.campaign,
        COUNT(DISTINCT s.visitor_id) AS visitors_count,
        COUNT(DISTINCT l.lead_id) AS leads_count,
        SUM(l.amount) AS revenue,
        SUM(a.daily_spent) AS total_cost,
        COUNT(CASE WHEN l.status_id = 142 OR l.closing_reason = 'Успешно реализовано' 
	THEN l.lead_id END) AS purchases_count
    FROM sessions AS s
    LEFT JOIN leads AS l
        ON s.visitor_id = l.visitor_id
    LEFT JOIN (
        SELECT
            DATE(campaign_date) AS campaign_date,
            utm_source,
            utm_medium,
            utm_campaign,
            SUM(daily_spent) AS daily_spent
        FROM vk_ads
        GROUP BY 1, 2, 3, 4
        UNION ALL
        SELECT
            DATE(campaign_date) AS campaign_date,
            utm_source,
            utm_medium,
            utm_campaign,
            SUM(daily_spent) AS daily_spent
        FROM ya_ads
        GROUP BY 1, 2, 3, 4
    ) AS a
        ON s.source = a.utm_source AND s.medium = a.utm_medium
	AND s.campaign = a.utm_campaign
	AND DATE(s.visit_date) = a.campaign_date
    GROUP BY 1, 2, 3, 4
)

SELECT
    source,
    medium,
    campaign,
    SUM(visitors_count) AS total_visitors,
    SUM(revenue) AS total_revenue,
    SUM(total_cost) AS total_cost,
    ROUND(SUM(total_cost) / SUM(visitors_count), 2) AS cpu,
    CASE WHEN SUM(leads_count) = 0 THEN NULL ELSE
	ROUND(SUM(total_cost) / SUM(leads_count), 2) END AS cpl,
    CASE WHEN SUM(purchases_count) = 0 THEN NULL ELSE
	ROUND(SUM(total_cost) / SUM(purchases_count), 2) END AS cppu,
    CASE WHEN SUM(total_cost) = 0 THEN NULL ELSE
	ROUND((SUM(revenue) - SUM(total_cost)) / SUM(total_cost) * 100, 2) END AS roi
FROM channel_metrics
GROUP BY 1, 2, 3
ORDER BY total_revenue DESC NULLS LAST;
