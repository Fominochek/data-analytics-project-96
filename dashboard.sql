-- 1. Общее количество пользователей
WITH sessions_by_date AS (
    SELECT
        source,
        DATE(visit_date) AS visit_date,
        COUNT(DISTINCT visitor_id) AS visitors_count
    FROM sessions
    GROUP BY source, DATE(visit_date)
)

SELECT
    sessions_by_date.source,
    sessions_by_date.visit_date,
    sessions_by_date.visitors_count
FROM sessions_by_date
ORDER BY sessions_by_date.visit_date;

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

-- 3. Конверсия из клика в лид
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
    GROUP BY visit_date, s.sorce, s.medium, s.campaign
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

-- 4. Конверсия из лида в оплату
WITH leads_purchases AS (
    SELECT
        DATE(leads.created_at) AS created_date,
        COUNT(DISTINCT leads.lead_id) AS leads_count,
        COUNT(CASE
            WHEN
                leads.status_id = 142
                OR leads.closing_reason = 'Успешно реализовано'
                THEN leads.visitor_id
        END) AS purchases_count
    FROM leads
    GROUP BY DATE(leads.created_at)
)

SELECT
    created_date,
    leads_count,
    purchases_count,
    ROUND(CAST(purchases_count AS DECIMAL) / leads_count * 100, 2)
    AS lead_to_purchase_conversion
FROM leads_purchases
ORDER BY created_date;

-- 5. Затраты по каналам
WITH ads_by_source_date AS (
    SELECT
        utm_source,
        DATE(campaign_date) AS campaign_date,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY utm_source, DATE(campaign_date)
    UNION ALL
    SELECT
        utm_source,
        DATE(campaign_date) AS campaign_date,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY utm_source, DATE(campaign_date)
)

SELECT
    campaign_date,
    utm_source,
    total_cost
FROM ads_by_source_date
ORDER BY campaign_date, utm_source;

-- 6. Для расчета основных метрик (расчет производила в таблицах)
WITH lv AS (
    SELECT
        visitor_id,
        MAX(visit_date) AS max_visit_date
    FROM sessions
    WHERE medium != 'organic'
    GROUP BY visitor_id
),

leads AS (
    SELECT
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        DATE(lv.max_visit_date) AS visit_date,
        COUNT(DISTINCT lv.visitor_id) AS visitors_count,
        COUNT(l.lead_id) AS leads_count,
        COUNT(CASE
            WHEN
                l.status_id = 142
                OR l.closing_reason = 'Успешно реализовано'
                THEN lv.visitor_id
        END) AS purchases_count,
        SUM(l.amount) AS revenue
    FROM lv
    INNER JOIN sessions AS s
        ON lv.visitor_id = s.visitor_id AND lv.max_visit_date = s.visit_date
    LEFT JOIN leads AS l
        ON s.visitor_id = l.visitor_id AND l.created_at >= lv.max_visit_date
    GROUP BY visit_date, utm_source, utm_medium, utm_campaign
),

ads AS (
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        DATE(campaign_date) AS campaign_date,
        SUM(daily_spent) AS total_cost
    FROM (
        SELECT *
        FROM vk_ads
        UNION ALL
        SELECT *
        FROM ya_ads
    ) AS ads
    GROUP BY campaign_date, utm_source, utm_medium, utm_campaign
)

SELECT
    l.visit_date,
    l.visitors_count,
    l.utm_source,
    l.utm_medium,
    l.utm_campaign,
    a.total_cost,
    l.leads_count,
    l.purchases_count,
    l.revenue
FROM leads AS l
LEFT JOIN ads AS a
    ON
        l.utm_source = a.utm_source AND l.utm_medium = a.utm_medium
        AND l.utm_campaign = a.utm_campaign AND l.visit_date = a.campaign_date
ORDER BY
    l.revenue DESC NULLS LAST, l.visit_date ASC,
    l.visitors_count DESC, l.utm_source ASC,
    l.utm_medium ASC, l.utm_campaign ASC;
