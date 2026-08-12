-- Read-only commodity-sales verification
-- Run after saving a sale in the app.

select
    action,
    count(*) as records,
    coalesce(sum(quantity_scu), 0) as total_scu,
    coalesce(sum(total_value), 0) as cargo_value,
    coalesce(sum(fees), 0) as fees,
    coalesce(sum(cash_effect), 0) as net_cash_effect
from public.commodity_transactions
group by action
order by action;

select
    id,
    date_saved,
    commodity_name,
    action,
    quantity_scu,
    unit_price,
    total_value,
    fees,
    cash_effect
from public.commodity_transactions
order by id desc
limit 20;
