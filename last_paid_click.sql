--2.
with last_visit as (
    select
        s.visitor_id,
        max(s.visit_date) as max_visit_date
    from sessions as s
    where s.medium not like 'organic'
    group by 1
)

select
    lv.visitor_id,
    lv.max_visit_date as visit_date,
    s.source as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
from last_visit as lv
left join sessions as s
    on lv.visitor_id = s.visitor_id and lv.max_visit_date = s.visit_date
left join leads as l
    on lv.visitor_id = l.visitor_id
where s.medium not like 'organic'
order by 
    l.amount desc nulls last,
    lv.visit_date asc, s.source asc,
    s.medium asc, s.campaign asc
limit 10;
