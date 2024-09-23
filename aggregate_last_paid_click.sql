--3.
WITH lv AS (
    SELECT
        MAX(visit_date) AS max_visit_date,
        visitor_id
    FROM sessions
    WHERE medium <> 'organic'
    GROUP BY visitor_id
),
leads AS (
    SELECT
        DATE(lv.max_visit_date) AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        COUNT(DISTINCT lv.visitor_id) AS visitors_count,
        COUNT(l.lead_id) AS leads_count,
        COUNT(CASE WHEN l.status_id = 142 OR l.closing_reason = 'Успешно реализовано' THEN lv.visitor_id END) AS purchases_count,
        SUM(amount) AS revenue
    FROM lv
    INNER JOIN sessions AS s
        ON lv.visitor_id = s.visitor_id AND lv.max_visit_date = s.visit_date
    LEFT JOIN leads AS l
        ON s.visitor_id = l.visitor_id
    GROUP BY 1, 2, 3, 4
),
ads AS (
    SELECT
        DATE(campaign_date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY 1, 2, 3, 4
    UNION ALL
    SELECT
        DATE(campaign_date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY 1, 2, 3, 4
)
SELECT
    l.visit_date,
    l.utm_source,
    l.utm_medium,
    l.utm_campaign,
    l.visitors_count,
    a.total_cost,
    l.leads_count,
    l.purchases_count,
    l.revenue
FROM leads AS l
LEFT JOIN ads AS a
    ON l.utm_source = a.utm_source
    AND l.utm_medium = a.utm_medium
    AND l.utm_campaign = a.utm_campaign
    AND l.visit_date = a.campaign_date
ORDER BY 9 DESC NULLS LAST, 1 ASC, 5 DESC, 2 ASC, 3 ASC, 4 ASC
LIMIT 15;