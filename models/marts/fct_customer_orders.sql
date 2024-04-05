-- with statement
WITH 
-- import CTEs
customers as (
    select * from {{source("jaffle_shop", "customers")}}
),


orders as (
    select * from {{source("jaffle_shop", "orders")}}
),

payments as (
    select * from {{source("stripe", "payment")}}
),
-- logical CTEs
p as (
    select
        ORDERID as order_id,
        max(CREATED) as payment_finalized_date, 
        sum(AMOUNT) / 100.0 as total_amount_paid

    from payments
    where STATUS <> 'fail'
    group by 1
),


paid_orders as (
    select 
        orders.ID as order_id,
        orders.USER_ID    as customer_id,
        orders.ORDER_DATE AS order_placed_at,
        orders.STATUS AS order_status,
        p.total_amount_paid,
        p.payment_finalized_date,
        customers.FIRST_NAME    as customer_first_name,
        customers.LAST_NAME as customer_last_name

    FROM orders
    left join  p ON orders.ID = p.order_id
left join customers on orders.USER_ID = customers.ID ),

x as (
        select
            p.order_id,
            sum(t2.total_amount_paid) as clv_bad

        from paid_orders p
        left join paid_orders t2 on p.customer_id = t2.customer_id and p.order_id >= t2.order_id
        group by 1
        order by p.order_id
),

customer_orders 
    as (select customers.ID as customer_id
        , min(orders.ORDER_DATE) as first_order_date
        , max(orders.ORDER_DATE) as most_recent_order_date
        , count(orders.ID) AS number_of_orders
    from customers
    left join orders
    on orders.USER_ID = customers.ID 
    group by 1),


-- final CTE
final as (select
    p.*,

    ROW_NUMBER() OVER (ORDER BY p.order_id) as transaction_seq,

    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY p.order_id) as customer_sales_seq,

    CASE WHEN c.first_order_date = p.order_placed_at
        THEN 'new'
        ELSE 'return' 
    END as nvsr,

    x.clv_bad as customer_lifetime_value,
    c.first_order_date as fdos

    FROM paid_orders p
    left join customer_orders as c USING (customer_id)
    LEFT OUTER JOIN 
     x on x.order_id = p.order_id
    ORDER BY order_id
)

-- simple select statement
select * from final


    
