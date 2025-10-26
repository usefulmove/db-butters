/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
-- 2. How many days has each customer visited the restaurant?
-- 3. What was the first item from the menu purchased by each customer?
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- 5. Which item was the most popular for each customer?
-- 6. Which item was purchased first by the customer after they became a member?
-- 7. Which item was purchased just before the customer became a member?
-- 8. What is the total items and amount spent for each member before they became a member?
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?


-- 1. total spent per customer
select s.customer_id,
       sum(m.price) as total_spent
from sales s
     left join menu m on s.product_id = m.product_id
group by 1
order by 2 desc;


-- 2. customer days at restaurant
select customer_id,
       count(distinct order_date) as days
from sales
group by 1
order by 1;


-- 3. first item purchased by each customer
select distinct
    s.customer_id,
    first_value(m.product_id) over(partition by s.customer_id order by order_date)
        as product_id,
    first_value(m.product_name) over(partition by s.customer_id order by order_date)
        as product_name
from sales s
     left join menu m on s.product_id = m.product_id
order by 1;


-- 4. most purchased item and number of purchases by each customer
with most_purchased as (
    select product_id,
           count(*) as n_sold
    from sales
    group by 1
    order by 2 desc
    limit 1
)

select distinct
    s.customer_id,
    (select m.product_id from most_purchased m) as product_id,
    p.n_purchased
from sales s
     left join (select s.customer_id,
                       count(*) as n_purchased
                from sales s
                where s.product_id = (select m.product_id from most_purchased m)
                group by 1) p
        on s.customer_id = p.customer_id
order by 1;


-- 5. most popular item for each customer
with popular_ranks as (
    select customer_id,
           product_id,
           count(*) as count,
           rank() over(partition by customer_id order by count(*) desc) as pop_rank
    from sales
    group by 1, 2
)

select customer_id,
       string_agg(product_id) as most_popular_items
from popular_ranks
where pop_rank = 1
group by 1
order by 1;


-- 6. first item purchase for new members
with product_order as (
    select s.customer_id,
           s.product_id,
           rank() over(partition by s.customer_id order by order_date) as order_of_purchase
    from sales s
         left join members m on s.customer_id = m.customer_id
    where s.customer_id in (select customer_id from members)
          and s.order_date >= m.join_date
)

select customer_id,
       product_id
from product_order
where order_of_purchase = 1
order by 1;


-- 7.