/* data cleaning */

begin;


-- clean customer_orders table
create or replace view clean_customer_orders as
    select
        order_id,
        customer_id,
        pizza_id,
        if(trim(exclusions) in ('', 'null'), null, trim(exclusions))
            as exclusions,
        if(trim(extras) in ('', 'null'), null, trim(extras))
            as extras,
        order_time
    from customer_orders;


-- clean runner_orders table
create or replace view clean_runner_orders as
select order_id,
       runner_id,
       cast(if(trim(pickup_time) in ('', 'null'),
               null,
               trim(pickup_time)
            ) as timestamp) as pickup_time,
       cast(if(trim(distance) in ('', 'null'),
               null,
               trim(regexp_replace(distance, '[^0-9\.]', '', 'g'))
            ) as decimal) as distance_kms,
       cast(if(trim(duration) in ('', 'null'),
               null,
               regexp_replace(duration, '[^0-9]', '', 'g')
            ) as integer) as duration_mins,
       if(trim(cancellation) in ('', 'null'), null, trim(cancellation))
                            as cancellation
from runner_orders;




/* data analysis */

-- A.1. pizzas ordered
select count(pizza_id) as pizzas_ordered
from clean_customer_orders;


-- A.2. number of unique customer orders
select count(distinct order_id) as customer_orders
from clean_customer_orders;


-- A.3. number of successful order deliveries by each runner
select runner_id,
       count(*) as orders_delivered
from clean_runner_orders
where cancellation is null
group by 1
order by 1;


-- A.4. deliveries by pizza type
select c.pizza_id,
       count(*) as delivered
from clean_runner_orders r
     left join clean_customer_orders c on r.order_id = c.order_id
where r.cancellation is null
group by 1;


-- A.5. pizza types ordered by each customer
select customer_id,
       pizza_name,
       count(*) as pizzas_ordered
from clean_customer_orders c
     left join pizza_names p on c.pizza_id = p.pizza_id
group by 1, 2
order by 1, 2;


-- A.6. most pizzas delivered on a single order
select c.order_id,
       count(*) as delivered
from clean_runner_orders r
     left join clean_customer_orders c on r.order_id = c.order_id
where cancellation is null
group by 1
order by 2 desc
limit 1;


-- A.7. changed vs unchanged pizzas delivered per customer
select customer_id,
       sum(if(exclusions is null and extras is null, 0, 1))
           as changed,
       sum(if(exclusions is null and extras is null, 1, 0))
           as unchanged
from clean_customer_orders c
     left join clean_runner_orders r on c.order_id = r.order_id
where cancellation is null
group by 1
order by 1;


-- A.8. delivered with both exclusions and extras
select count(*) as pizzas_w_exclusions_and_extras
from clean_customer_orders c
         left join clean_runner_orders r on c.order_id = r.order_id
where cancellation is null
      and exclusions is not null
      and extras is not null;


-- A.9. pizzas orders by hour of the day
with orders_by_hour as (
        select extract(hour from order_time) as hour_of_day,
               count(*) as pizzas_ordered
        from clean_customer_orders
        group by 1
),

     all_hours as (select * as hour_of_day from range(0, 24))

select h.hour_of_day,
       coalesce(pizzas_ordered, 0) as pizzas_ordered
from all_hours h
     left join orders_by_hour o on h.hour_of_day = o.hour_of_day
where h.hour_of_day >= 8
order by 1;


-- A.10. orders by day of the week
select case
           when d.day_of_week = 0 then 'Sun'
           when d.day_of_week = 1 then 'Mon'
           when d.day_of_week = 2 then 'Tue'
           when d.day_of_week = 3 then 'Wed'
           when d.day_of_week = 4 then 'Thu'
           when d.day_of_week = 5 then 'Fri'
           when d.day_of_week = 6 then 'Sat'
           else ''
       end as day_name,
       coalesce(pizzas_ordered, 0) as pizzas_ordered
from (select * as day_of_week from range(0, 7)) d
     left join (select dayofweek(order_time) as day_of_week,
                       -- dayname(order_time) as day_name,
                       -- strftime('%a', order_time) as day_name,
                       count(*) as pizzas_ordered
                from clean_customer_orders
                group by 1) agg on d.day_of_week = agg.day_of_week
order by d.day_of_week;


-- B.1. runners signed up for each one week period
select (registration_date - cast('2021-01-01' as date)) // 7 as week,
       count(*) as runners_registered
from runners
group by 1
order by 1;


-- B.2. average pickup time (minutes) per runner
select runner_id,
       round(extract(epoch from avg(pickup_time - order_time)) / 60.0, 2)
           as avg_pickup_time
from clean_customer_orders
     left join clean_runner_orders using (order_id)
where pickup_time is not null
group by 1
order by 1;