--3.
WITH PaidClicks AS (
  SELECT 
    visitor_id,
    visit_date,
    "source",
    medium,
    campaign
  FROM sessions
  WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),
LastPaidClicks AS (
  SELECT 
    visitor_id,
    MAX(visit_date) AS last_paid_click_date,
    "source",
    medium,
    campaign
  FROM PaidClicks
  GROUP BY visitor_id, "source", medium, campaign
),
AttributedLeads AS (
  SELECT 
    l.visitor_id,
    l.visit_date,
    l."source",
    l.medium,
    l.campaign,
    lead.lead_id,
    lead.created_at,
    lead.amount,
    lead.closing_reason,
    lead.status_id
  FROM leads AS lead
  JOIN sessions AS l
    ON lead.visitor_id = l.visitor_id
  LEFT JOIN LastPaidClicks AS last_click
    ON l.visitor_id = last_click.visitor_id AND l.visit_date = last_click.last_paid_click_date
)
SELECT
  l.visit_date,
  l."source",
  l.medium,
  l.campaign,
  COUNT(DISTINCT l.visitor_id) AS visitors_count,
  COALESCE(SUM(ya.daily_spent), 0) + COALESCE(SUM(vk.daily_spent), 0) AS total_cost,
  COUNT(DISTINCT al.lead_id) AS leads_count,
  SUM(CASE WHEN al.closing_reason = 'Успешно реализовано' OR al.status_id = 142 THEN 1 ELSE 0 END) AS purchases_count,
  SUM(CASE WHEN al.closing_reason = 'Успешно реализовано' OR al.status_id = 142 THEN al.amount ELSE 0 END) AS revenue
FROM sessions AS l
LEFT JOIN ya_ads AS ya
  ON l."source" = ya.utm_source AND l.medium = ya.utm_medium AND l.campaign = ya.utm_campaign
LEFT JOIN vk_ads AS vk
  ON l."source" = vk.utm_source AND l.medium = vk.utm_medium AND l.campaign = vk.utm_campaign
LEFT JOIN AttributedLeads AS al
  ON l.visitor_id = al.visitor_id AND l.visit_date = al.visit_date
GROUP BY
  l.visit_date,
  l."source",
  l.medium,
  l.campaign
ORDER BY
  revenue DESC NULLS LAST,
  l.visit_date ASC,
  visitors_count DESC,
  l."source" ASC,
  l.medium ASC,
  l.campaign ASC
  LIMIT 15;