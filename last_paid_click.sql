--2.
with l_s as(
	select 
		s.visitor_id,
		MAX(s.visit_date) as visit_date,
		s.source as utm_source,
		s.medium as utm_medium,
		s.campaign as utm_campaign,
		l.lead_id,
		l.created_at,
		l.amount,
		l.closing_reason,
		l.status_id
	from leads l 
	left join sessions s
	on l.visitor_id = s.visitor_id
	group by 1, 3, 4, 5, 6, 7, 8, 9, 10
	order by visitor_id asc, visit_date desc
),
	l_s1 as (
    	select distinct on (visitor_id) *
    	from l_s
    	where utm_medium != 'organic'
)
select
	visitor_id,
	visit_date, 
	utm_source,
    utm_medium,
    utm_campaign,
    lead_id,
    created_at,
    amount,
    closing_reason,
    status_id
from l_s1
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
limit 10;