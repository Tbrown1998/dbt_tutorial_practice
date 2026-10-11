-- Net sales, order count and estimated processing fees per store and payment method.
-- Compile with `dbt compile --select sales_by_store_and_payment` and run the
-- generated SQL in target/compiled/ against your warehouse.

SELECT
    st.store_name,
    s.payment_method,
    pm.payment_category,
    COUNT(s.sales_id)                                  AS total_orders,
    SUM(s.quantity)                                    AS total_units,
    ROUND(SUM(s.net_amount), 2)                        AS total_net_sales,
    ROUND(SUM(s.net_amount * pm.processing_fee_pct), 2) AS est_processing_fees
FROM {{ ref('bronze_sales') }} AS s
LEFT JOIN {{ ref('bronze_store') }} AS st
    ON s.store_sk = st.store_sk
LEFT JOIN {{ ref('payment_method_lookup') }} AS pm
    ON s.payment_method = pm.payment_method
GROUP BY
    st.store_name,
    s.payment_method,
    pm.payment_category
ORDER BY
    st.store_name,
    total_net_sales DESC
