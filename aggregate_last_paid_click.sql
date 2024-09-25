--3.
WITH lv AS (
   select
      MAX(visit_date) AS max_visit_date,
      visitor_id
   from sessions
   where medium != 'organic'
   group by visitor_id
),

leads AS (
   select
      DATE(lv.max_visit_date) AS visit_date,
      s.source AS utm_source,
      s.medium AS utm_medium,
      s.campaign AS utm_campaign,
      COUNT(DISTINCT lv.visitor_id) AS visitors_count,
      COUNT(l.lead_id) AS leads_count,
      COUNT(case
                when l.status_id = 142 OR l.closing_reason = 'Успешно реализовано' 
                then lv.visitor_id 
                end) AS purchases_count,
      SUM(l.amount) AS revenue
   from lv
   inner join sessions AS s
      on lv.visitor_id = s.visitor_id AND lv.max_visit_date = s.visit_date
   left join leads AS l
      on s.visitor_id = l.visitor_id AND l.created_at >= lv.max_visit_date
   group by visit_date, utm_source, utm_medium, utm_campaign
),

ads AS (
   select
      DATE(campaign_date) AS campaign_date,
      utm_source,
      utm_medium,
      utm_campaign,
      SUM(daily_spent) AS total_cost
   from (
      select * 
      from vk_ads
      UNION ALL
      select * 
      from ya_ads
    ) AS ads
   group by campaign_date, utm_source, utm_medium, utm_campaign
)

select
   l.visit_date,
   l.visitors_count,
   l.utm_source,
   l.utm_medium,
   l.utm_campaign,
   a.total_cost,
   l.leads_count,
   l.purchases_count,
   l.revenue
from leads AS l
left join ads as a
   on l.utm_source = a.utm_source
   and l.utm_medium = a.utm_medium
   and l.utm_campaign = a.utm_campaign
   and l.visit_date = a.campaign_date
order by l.revenue DESC NULLS LAST, l.visit_date ASC, l.visitors_count DESC, l.utm_source ASC, l.utm_medium ASC, l.utm_campaign ASC
LIMIT 15;
