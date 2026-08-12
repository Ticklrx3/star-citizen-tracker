-- Star Citizen Tracker
-- Version 7: Ore quantity, unit-price, and cash-effect repair
-- Run this entire file once in Supabase SQL Editor.

begin;

-- Version 7 originally omitted this line. It is required before the update
-- and trigger reference quantity_scu.
alter table public.ore_transactions
    add column if not exists quantity_scu numeric not null default 0;

alter table public.ore_transactions
    add column if not exists unit_price numeric not null default 0;

alter table public.ore_transactions
    add column if not exists cash_effect numeric not null default 0;

update public.ore_transactions
set
    action = case
        when lower(coalesce(action, '')) similar to '%(mine|extract)%'
            then 'Mined'
        when lower(coalesce(action, '')) similar to '%(buy|bought|purchas)%'
            then 'Bought'
        when lower(coalesce(action, '')) similar to '%(sell|sold|sale)%'
            then 'Sold'
        else action
    end,
    ore_name = coalesce(
        nullif(trim(ore_name), ''),
        'Unknown Resource'
    ),
    quantity_scu = greatest(coalesce(quantity_scu, 0), 0),
    unit_price = case
        when coalesce(unit_price, 0) > 0
            then unit_price
        when coalesce(quantity_scu, 0) > 0
         and coalesce(total_value, 0) > 0
            then total_value / quantity_scu
        else 0
    end,
    total_value = greatest(coalesce(total_value, 0), 0);

create or replace function public.sync_ore_transaction_math()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
    new.ore_name := coalesce(
        nullif(trim(new.ore_name), ''),
        'Unknown Resource'
    );
    new.quantity_scu := greatest(
        coalesce(new.quantity_scu, 0),
        0
    );
    new.unit_price := greatest(
        coalesce(new.unit_price, 0),
        0
    );
    new.total_value := greatest(
        coalesce(new.total_value, 0),
        0
    );

    if new.quantity_scu > 0 and new.unit_price > 0 then
        new.total_value := new.quantity_scu * new.unit_price;
    elsif new.quantity_scu > 0
      and new.total_value > 0
      and new.unit_price <= 0 then
        new.unit_price := new.total_value / new.quantity_scu;
    end if;

    new.cash_effect := case new.action
        when 'Bought' then -new.total_value
        when 'Sold' then new.total_value
        else 0
    end;

    return new;
end;
$$;

drop trigger if exists ore_transaction_math_trigger
on public.ore_transactions;

create trigger ore_transaction_math_trigger
before insert or update of
    action,
    ore_name,
    quantity_scu,
    unit_price,
    total_value
on public.ore_transactions
for each row
execute function public.sync_ore_transaction_math();

-- Re-run the trigger against existing rows.
update public.ore_transactions
set total_value = total_value;

alter table public.ore_transactions
    drop constraint if exists ore_transactions_action_check;

alter table public.ore_transactions
    add constraint ore_transactions_action_check
    check (action in ('Mined', 'Bought', 'Sold'));

alter table public.ore_transactions
    drop constraint if exists ore_transactions_quantity_scu_check;

alter table public.ore_transactions
    add constraint ore_transactions_quantity_scu_check
    check (quantity_scu >= 0);

alter table public.ore_transactions
    drop constraint if exists ore_transactions_unit_price_check;

alter table public.ore_transactions
    add constraint ore_transactions_unit_price_check
    check (unit_price >= 0);

alter table public.ore_transactions
    drop constraint if exists ore_transactions_total_value_check;

alter table public.ore_transactions
    add constraint ore_transactions_total_value_check
    check (total_value >= 0);

grant select, insert, update, delete
    on table public.ore_transactions
    to authenticated;

commit;

notify pgrst, 'reload schema';

select
    count(*) as ore_records,
    coalesce(sum(quantity_scu), 0) as entered_scu,
    coalesce(sum(total_value), 0) as verified_value,
    coalesce(sum(cash_effect), 0) as net_cash_effect,
    count(*) filter (
        where quantity_scu <= 0 and total_value > 0
    ) as records_missing_scu_quantity
from public.ore_transactions;
