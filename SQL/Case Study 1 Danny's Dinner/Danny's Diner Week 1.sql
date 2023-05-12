# Check sales table
select * from sales;

# Check menu table
select * from menu;

# Check members table
select * from members;

#1. What is the total amount each customer spent at the restaurant?
select s.customer_id, sum(price) as total_sales
from sales as s
inner join menu as m
on s.product_id = m.product_id
group by customer_id;

#2. How many days has each customer visited the restaurant?
select s.customer_id, count(distinct s.order_date) as days_of_visit
from sales as s
group by s.customer_id;

#3. What was the firt item from the menu purchased by each customer?
with order_info_cte as
  (select customer_id,
          order_date,
          product_name,
          dense_rank() over(partition by s.customer_id
                            order by s.order_date) as rank_num
   from sales as s
   inner join menu as m on s.product_id = m.product_id)
  select customer_id, order_date,
          group_concat(distinct product_name
                    order by product_name) as product_name
   from order_info_cte
   where rank_num = 1
   group by customer_id
;

# Try out sub_query in question 3
select customer_id,
          order_date,
          product_name,
          dense_rank() over(partition by s.customer_id
                            order by s.order_date) as rank_num
   from sales as s
   inner join menu as m on s.product_id = m.product_id;
   
#4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select s.product_id, m.product_name, count(s.product_id) as times_of_purchases
from sales as s
inner join menu as m on s.product_id = m.product_id
group by s.product_id, m.product_name
order by times_of_purchases desc limit 1;

#5. Which item was the most popular for each customer?
with customer_product_info as
(select s.customer_id, s.product_id, m.product_name, count(s.product_id) as order_count,
rank() over(partition by s.customer_id order by count(s.product_id) desc) as rank_num
from sales as s
inner join menu as m on s.product_id = m.product_id
group by s.customer_id, s.product_id, m.product_name)
select customer_id, product_name, order_count
from customer_product_info
where rank_num=1;

#6. Which item was purchased first by the customer after they became a member?
with item_timeline as
(select s.customer_id, s.product_id, m.product_name, s.order_date,
rank() over(partition by s.customer_id order by s.order_date asc) as rank_product
from sales as s
inner join members as mb on s.customer_id = mb.customer_id
inner join menu as m on s.product_id = m.product_id
where s.order_date >= mb.join_date
group by s.customer_id, s.product_id, m.product_name, s.order_date)
select customer_id, product_name, order_date
from item_timeline
where rank_product = 1;

#7. Which item was purchased just before the customer became a member?
with item_bf_member as
(select s.customer_id, s.product_id, m.product_name, s.order_date,
rank() over(partition by s.customer_id order by s.order_date desc) as rank_purchase
from sales as s
inner join members as mb on s.customer_id = mb.customer_id
inner join menu as m on s.product_id = m.product_id
where s.order_date < mb.join_date
group by s.customer_id, s.product_id, m.product_name, s.order_date)
select customer_id, product_id, product_name, order_date
from item_bf_member
where rank_purchase = 1;

#8. What is the total items and amount spent for each member before they became a member?
select s.customer_id, count(s.product_id) as total_items, sum(m.price) as total_bill
from sales as s
inner join members as mb on s.customer_id = mb.customer_id
inner join menu as m on s.product_id = m.product_id
where s.order_date < mb.join_date
group by s.customer_id;

#9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
with member_points as
(select *,
case when m.product_name = 'sushi' then m.price*20
when m.product_name != 'sushi' then m.price*10
end as points
from menu as m)
select s.customer_id, sum(mp.points) as total_points
from member_points as mp
inner join sales as s on s.product_id = mp.product_id
group by s.customer_id;

#10. In the first week after a customer joins the program (including their join date), they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

# Find out the join_date and program_last_day (6 days after the date joined) for each customer
select customer_id, join_date, date_add(join_date, interval 6 day) as program_last_date
from members;

# Combine with the previous code and Determine the points accumulated under different scenarios
with special_program_cte as 
(
select customer_id, join_date, date_add(join_date, interval 6 day) as program_last_date
from members)
select s.customer_id,
sum(
case
when order_date between join_date and program_last_date then price*10*2
when order_date not between join_date and program_last_date and product_name = 'sushi' then price*10*2
when order_date not between join_date and program_last_date and product_name != 'sushi' then price*10
end) as customer_loyalty_program
from menu as m
inner join sales as s on s.product_id = m.product_id
inner join special_program_cte as sp on sp.customer_id = s.customer_id
and order_date <= '2021-01-31'
and order_date >= join_date
group by s.customer_id
order by s.customer_id;

# Bonus question 1
select s.customer_id, s.order_date, m.product_name, m.price,
case
when s.order_date < mb.join_date then 'N'
when s.order_date >= mb.join_date then 'Y'
else 'N'
end
from sales as s
left join menu as m on s.product_id = m.product_id
left join members as mb on s.customer_id = mb.customer_id
; # Not using groupby in this case because customer A purchase 2 exact ramen with same product_id within 1 day > want to display all results

# Bonus question 2
with rank_table_cte as
(select s.customer_id, s.order_date, m.product_name, m.price,
case
when s.order_date < mb.join_date then 'N'
when s.order_date >= mb.join_date then 'Y'
else 'N'
end as members_info
from sales as s
inner join menu as m on s.product_id = m.product_id
left join members as mb on s.customer_id = mb.customer_id
)
select *,
case
when members_info = 'N' then null
else
rank() over(partition by customer_id, members_info order by order_date) end as ranking
from rank_table_cte;
