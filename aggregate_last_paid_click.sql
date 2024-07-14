--3.
with l_s as(
	select 
		s.visitor_id,
		s.visit_date,
		s.source as utm_source,
		s.medium as utm_medium,
		s.campaign as utm_campaign,
		l.lead_id,
		l.created_at,
		l.amount,
		l.closing_reason,
		l.status_id,
		row_number() 
			over (partition by s.visitor_id order by s.visit_date desc)
        as sale_count
	from leads l 
	left join sessions s
	on l.visitor_id = s.visitor_id
	where s.medium != 'organic' and s.visit_date <= l.created_at
	group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
),
	vk_ya as(
	select 
		campaign_date,
		utm_source,
		utm_medium,
		utm_campaign,
		sum(daily_spent) as daily_spent
		from vk_ads
    group by 1, 2, 3, 4
    union all
    select
    	campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as daily_spent
    from ya_ads 
    group by 1, 2, 3, 4
)
select
    visit_date,
    l_s.utm_source,
    l_s.utm_medium,
    l_s.utm_campaign,
    daily_spent as total_cost,
    count(visitor_id) as visitors_count,
    count(lead_id) as leads_count,
    (select 
    	count(lead_id) as purchases_count
    	from leads l 
        where closing_reason = 'Успешно реализовано' or status_id = 142
    ),
    sum(amount) as revenue
from l_s
left join vk_ya
on l_s.utm_source = vk_ya.utm_source
   and l_s.utm_medium = vk_ya.utm_medium
   and l_s.utm_campaign = vk_ya.utm_campaign
   and l_s.visit_date = vk_ya.campaign_date
where l_s.sale_count = 1
group by visit_date, l_s.utm_source, 
	l_s.utm_medium, l_s.utm_campaign, daily_spent
order by
    revenue desc nulls last, 
    visit_date asc, 
    visitors_count desc, 
    utm_source asc, 
    utm_medium asc, 
    utm_campaign asc
limit 15; 