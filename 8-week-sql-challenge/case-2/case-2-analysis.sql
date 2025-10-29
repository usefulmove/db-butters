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

-- 1. pizzas ordered
select count(pizza_id) as pizzas_ordered
from clean_customer_orders;


-- 2. unique customer orders
select count(distinct order_id) as customer_orders
from clean_customer_orders;


-- 3. successful order deliveries by each runner
select runner_id,
       count(*) as orders_delivered
from clean_runner_orders
where cancellation is null
group by 1
order by 1;


-- 4. deliveries by pizza type
select c.pizza_id,
       count(*) as delivered
from clean_runner_orders r
     left join clean_customer_orders c on r.order_id = c.order_id
where r.cancellation is null
group by 1;


-- 5. pizzas ordered by each customer by type
select customer_id,
       pizza_name,
       count(*) as pizzas_ordered
from clean_customer_orders c
     left join pizza_names p on c.pizza_id = p.pizza_id
group by 1, 2
order by 1, 2;


-- 6. most pizzas delivered on a single order
select c.order_id,
       count(*) as delivered
from clean_runner_orders r
     left join clean_customer_orders c on r.order_id = c.order_id
where cancellation is null
group by 1
order by 2 desc
limit 1;


-- 7. changed vs unchanged pizzas delivered per customer
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


-- 8. delivered with both exclusions and extras
select count(*) as pizzas_w_exclusions_and_extras
from clean_customer_orders c
         left join clean_runner_orders r on c.order_id = r.order_id
where cancellation is null
      and exclusions is not null
      and extras is not null;
