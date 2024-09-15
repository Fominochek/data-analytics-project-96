--2.
WITH PaidClicks AS (
  SELECT 
    visitor_id,
    visit_date,
    "source",
    medium,
    campaign
  FROM sessions
  where medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
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
)
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
ORDER BY
  lead.amount DESC NULLS LAST,
  l.visit_date ASC,
  l."source" ASC,
  l.medium ASC,
  l.campaign ASC
  limit 10;