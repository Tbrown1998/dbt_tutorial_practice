-- Keeps only the latest version of each item (one row per item_id),
-- ranked by most recent updated_at.
WITH ranked_items AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY item_id
            ORDER BY updated_at DESC
        ) AS row_num
    -- NOTE: Normally this would read from source('source', 'items'), since in a real
    -- project raw tables like this are loaded by an external tool (Fivetran, Airflow,
    -- etc.) and dbt only reads them.
    -- Here the table is loaded by our own dbt seed (seeds/items.csv). With source(),
    -- dbt doesn't know this model depends on that seed, so `dbt build` ran both in
    -- parallel and this model read the table while it was still empty. ref('items')
    -- tells dbt to always load the seed first.
    FROM {{ ref('items') }}
)

SELECT
    item_id,
    item_name,
    category,
    price,
    status,
    updated_at
FROM ranked_items
WHERE row_num = 1
