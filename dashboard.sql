--основные метрики
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
  l."source",
  COUNT(DISTINCT l.visitor_id) AS visitors_count,
  COALESCE(SUM(ya.daily_spent), 0) + COALESCE(SUM(vk.daily_spent), 0) AS total_cost,
  COUNT(DISTINCT al.lead_id) AS leads_count,
  SUM(CASE WHEN al.closing_reason = 'Успешно реализовано' OR al.status_id = 142 THEN 1 ELSE 0 END) AS purchases_count,
  SUM(CASE WHEN al.closing_reason = 'Успешно реализовано' OR al.status_id = 142 THEN al.amount ELSE 0 END) AS revenue,
  -- Расчет метрик с проверкой на ноль
  CASE WHEN COUNT(DISTINCT l.visitor_id) > 0 THEN 
       (COALESCE(SUM(ya.daily_spent), 0) + COALESCE(SUM(vk.daily_spent), 0)) / COUNT(DISTINCT l.visitor_id) 
   ELSE 
       0 
   END AS cpu,
  CASE WHEN COUNT(DISTINCT al.lead_id) > 0 THEN 
       (COALESCE(SUM(ya.daily_spent), 0) + COALESCE(SUM(vk.daily_spent), 0)) / COUNT(DISTINCT al.lead_id) 
   ELSE 
       0 
   END AS cpl,
  CASE WHEN SUM(CASE WHEN al.closing_reason = 'Успешно реализовано' OR al.status_id = 142 THEN 1 ELSE 0 END) > 0 THEN 
       (COALESCE(SUM(ya.daily_spent), 0) + COALESCE(SUM(vk.daily_spent), 0)) / SUM(CASE WHEN al.closing_reason = 'Успешно реализовано' OR al.status_id = 142 THEN 1 ELSE 0 END) 
   ELSE 
       0 
   END AS cppu,
  CASE WHEN (COALESCE(SUM(ya.daily_spent), 0) + COALESCE(SUM(vk.daily_spent), 0)) > 0 THEN
       (SUM(CASE WHEN al.closing_reason = 'Успешно реализовано' OR al.status_id = 142 THEN al.amount ELSE 0 END) - (COALESCE(SUM(ya.daily_spent), 0) + COALESCE(SUM(vk.daily_spent), 0))) 
       / (COALESCE(SUM(ya.daily_spent), 0) + COALESCE(SUM(vk.daily_spent), 0)) * 100 
   ELSE 
       0 
   END AS roi
FROM sessions AS l
LEFT JOIN ya_ads AS ya
  ON l."source" = ya.utm_source AND l.medium = ya.utm_medium AND l.campaign = ya.utm_campaign
LEFT JOIN vk_ads AS vk
  ON l."source" = vk.utm_source AND l.medium = vk.utm_medium AND l.campaign = vk.utm_campaign
LEFT JOIN AttributedLeads AS al
  ON l.visitor_id = al.visitor_id AND l.visit_date = al.visit_date
GROUP BY
  l."source"
ORDER BY
  revenue DESC NULLS LAST,
  visitors_count DESC,
  l."source" ASC;

--закрытие 90% лидов
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
    lead.status_id,
    DATE_PART('day', lead.created_at - l.visit_date) AS days_to_close
  FROM leads AS lead
  JOIN sessions AS l
    ON lead.visitor_id = l.visitor_id
  LEFT JOIN LastPaidClicks AS last_click
    ON l.visitor_id = last_click.visitor_id AND l.visit_date = last_click.last_paid_click_date
  WHERE lead.closing_reason = 'Успешно реализовано' OR lead.status_id = 142
)
SELECT 
  "source",
  PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY days_to_close) AS days_to_close_90
FROM AttributedLeads
GROUP BY "source";

--количество пользователей в разбивке по дням/неделям/месяцу
WITH DailyData AS (
  SELECT
    visit_date,
    "source",
    COUNT(DISTINCT visitor_id) AS visitors_count
  FROM sessions
  GROUP BY visit_date, "source"
),
WeeklyData AS (
  SELECT
    DATE_TRUNC('week', visit_date) AS week,
    "source",
    COUNT(DISTINCT visitor_id) AS visitors_count
  FROM sessions
  GROUP BY DATE_TRUNC('week', visit_date), "source"
),
MonthlyData AS (
  SELECT
    DATE_TRUNC('month', visit_date) AS month,
    "source",
    COUNT(DISTINCT visitor_id) AS visitors_count
  FROM sessions
  GROUP BY DATE_TRUNC('month', visit_date), "source"
)
SELECT
  'Daily' AS aggregation_level,
  dd.visit_date,
  dd."source",
  dd.visitors_count
FROM DailyData dd
UNION ALL
SELECT
  'Weekly' AS aggregation_level,
  wd.week,
  wd."source",
  wd.visitors_count
FROM WeeklyData wd
UNION ALL
SELECT
  'Monthly' AS aggregation_level,
  md.month,
  md."source",
  md.visitors_count
FROM MonthlyData md
ORDER BY
  aggregation_level,
  visit_date,
  "source";

--конверсия лидов
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
  "source",
  COUNT(DISTINCT visitor_id) AS clicks,
  COUNT(DISTINCT lead_id) AS leads,
  SUM(CASE WHEN closing_reason = 'Успешно реализовано' OR status_id = 142 THEN 1 ELSE 0 END) AS purchases,
  -- Конверсия из клика в лид
  ROUND(CAST(COUNT(DISTINCT lead_id) AS DECIMAL) * 100 / COUNT(DISTINCT visitor_id), 2) AS click_to_lead_conversion,
  -- Конверсия из лида в оплату
  ROUND(CAST(SUM(CASE WHEN closing_reason = 'Успешно реализовано' OR status_id = 142 THEN 1 ELSE 0 END) AS DECIMAL) * 100 / COUNT(DISTINCT lead_id), 2) AS lead_to_purchase_conversion
FROM AttributedLeads
GROUP BY "source"
ORDER BY "source";

--затраты на каналы по дням
SELECT
  DATE(visit_date) AS date,
  "source",
  COALESCE(SUM(ya.daily_spent), 0) + COALESCE(SUM(vk.daily_spent), 0) AS total_cost
FROM sessions AS s
LEFT JOIN ya_ads AS ya
  ON s."source" = ya.utm_source AND s.medium = ya.utm_medium AND s.campaign = ya.utm_campaign
LEFT JOIN vk_ads AS vk
  ON s."source" = vk.utm_source AND s.medium = vk.utm_medium AND s.campaign = vk.utm_campaign
GROUP BY DATE(visit_date), "source"
ORDER BY DATE(visit_date), "source";