-- Star Citizen Tracker
-- Version 8: Ore schema-column and PostgREST cache repair
--
-- Why this file exists:
-- The earlier Version 7 migration referenced quantity_scu before guaranteeing
-- that the column existed. If quantity_scu was missing, PostgreSQL aborted the
-- transaction and rolled the entire migration back.
--
-- Run this COMPLETE file once in the Supabase SQL Editor.

begin;

-- Remove the old trigger first so column repairs cannot conflict with it.
drop trigger if exists ore_transaction_math_trigger
on public.ore_transactions;

-- Guarantee that every column required by the current application exists
-- BEFORE any update, constraint, or trigger references it.
alter table public.ore_transactions
    add column if not exists quantity_scu numeric;

alter table public.ore_transactions
    add column if not exists unit_price numeric;

alter table public.ore_transactions
    add column if not exists cash_effect numeric;

alter table public.ore_transactions
    add column if not exists total_value numeric;

alter table public.ore_transactions
    add column if not exists location text;

alter table public.ore_transactions
    add column if not exists notes text;

-- Set defaults before enforcing NOT NULL.
alter table public.ore_transactions
    alter column quantity_scu set default 0;

alter table public.ore_transactions
    alter column unit_price set default 0;

alter table public.ore_transactions
    alter column cash_effect set default 0;

alter table public.ore_transactions
    alter column total_value set default 0;

-- Copy values from common legacy quantity column names when they exist.
do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'ore_transactions'
          and column_name = 'quantity'
    ) then
        execute $copy$
            update public.ore_transactions
            set quantity_scu = case
                when coalesce(quantity_scu, 0) > 0
                    then quantity_scu
                when trim(quantity::text)
                     ~ '^[+-]?[0-9]+([.][0-9]+)?$'
                    then greatest(quantity::numeric, 0)
                else 0
            end
        $copy$;
    end if;

    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'ore_transactions'
          and column_name = 'scu'
    ) then
        execute $copy$
            update public.ore_transactions
            set quantity_scu = case
                when coalesce(quantity_scu, 0) > 0
                    then quantity_scu
                when trim(scu::text)
                     ~ '^[+-]?[0-9]+([.][0-9]+)?$'
                    then greatest(scu::numeric, 0)
                else 0
            end
        $copy$;
    end if;

    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'ore_transactions'
          and column_name = 'amount_scu'
    ) then
        execute $copy$
            update public.ore_transactions
            set quantity_scu = case
                when coalesce(quantity_scu, 0) > 0
                    then quantity_scu
                when trim(amount_scu::text)
                     ~ '^[+-]?[0-9]+([.][0-9]+)?$'
                    then greatest(amount_scu::numeric, 0)
                else 0
            end
        $copy$;
    end if;
end
$$;

-- Remove constraints before normalizing legacy rows.
alter table public.ore_transactions
    drop constraint if exists ore_transactions_action_check;

alter table public.ore_transactions
    drop constraint if exists ore_transactions_quantity_scu_check;

alter table public.ore_transactions
    drop constraint if exists ore_transactions_unit_price_check;

alter table public.ore_transactions
    drop constraint if exists ore_transactions_total_value_check;

-- Normalize existing records safely.
update public.ore_transactions
set
    action = case
        when lower(coalesce(action, '')) similar to '%(mine|extract)%'
            then 'Mined'
        when lower(coalesce(action, '')) similar to '%(buy|bought|purchas)%'
            then 'Bought'
        when lower(coalesce(action, '')) similar to '%(sell|sold|sale)%'
            then 'Sold'
        when action in ('Mined', 'Bought', 'Sold')
            then action
        else 'Mined'
    end,
    ore_name = coalesce(
        nullif(trim(ore_name), ''),
        'Unknown Resource'
    ),
    quantity_scu = greatest(coalesce(quantity_scu, 0), 0),
    unit_price = case
        when coalesce(unit_price, 0) > 0
            then greatest(unit_price, 0)
        when coalesce(quantity_scu, 0) > 0
         and coalesce(total_value, 0) > 0
            then greatest(total_value / quantity_scu, 0)
        else 0
    end,
    total_value = case
        when coalesce(quantity_scu, 0) > 0
         and coalesce(unit_price, 0) > 0
            then greatest(quantity_scu * unit_price, 0)
        else greatest(coalesce(total_value, 0), 0)
    end,
    cash_effect = case
        when action = 'Bought'
            then -greatest(coalesce(total_value, 0), 0)
        when action = 'Sold'
            then greatest(coalesce(total_value, 0), 0)
        else 0
    end;

-- Existing null values are repaired, so NOT NULL can now be enforced.
alter table public.ore_transactions
    alter column quantity_scu set not null;

alter table public.ore_transactions
    alter column unit_price set not null;

alter table public.ore_transactions
    alter column cash_effect set not null;

alter table public.ore_transactions
    alter column total_value set not null;

-- Recreate constraints.
alter table public.ore_transactions
    add constraint ore_transactions_action_check
    check (action in ('Mined', 'Bought', 'Sold'));

alter table public.ore_transactions
    add constraint ore_transactions_quantity_scu_check
    check (quantity_scu >= 0);

alter table public.ore_transactions
    add constraint ore_transactions_unit_price_check
    check (unit_price >= 0);

alter table public.ore_transactions
    add constraint ore_transactions_total_value_check
    check (total_value >= 0);

-- Database-side calculation guard.
create or replace function public.sync_ore_transaction_math()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
    new.action := case
        when lower(coalesce(new.action, '')) similar to '%(mine|extract)%'
            then 'Mined'
        when lower(coalesce(new.action, '')) similar to '%(buy|bought|purchas)%'
            then 'Bought'
        when lower(coalesce(new.action, '')) similar to '%(sell|sold|sale)%'
            then 'Sold'
        when new.action in ('Mined', 'Bought', 'Sold')
            then new.action
        else 'Mined'
    end;

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

-- Restore access and RLS policies.
alter table public.ore_transactions enable row level security;

grant usage on schema public to authenticated;

grant select, insert, update, delete
on table public.ore_transactions
to authenticated;

do $$
begin
    if to_regclass('public.ore_transactions_id_seq') is not null then
        execute
            'grant usage, select on sequence '
            'public.ore_transactions_id_seq to authenticated';
    end if;
end
$$;

drop policy if exists "Users can read own ore entries"
on public.ore_transactions;

drop policy if exists "Users can insert own ore entries"
on public.ore_transactions;

drop policy if exists "Users can update own ore entries"
on public.ore_transactions;

drop policy if exists "Users can delete own ore entries"
on public.ore_transactions;

create policy "Users can read own ore entries"
on public.ore_transactions
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own ore entries"
on public.ore_transactions
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own ore entries"
on public.ore_transactions
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own ore entries"
on public.ore_transactions
for delete
to authenticated
using (auth.uid() = user_id);

commit;

-- Force PostgREST/Supabase to refresh its schema cache.
notify pgrst, 'reload schema';
select pg_notify('pgrst', 'reload schema');

-- Verification result 1:
-- These four rows must appear after the migration.
select
    column_name,
    data_type,
    is_nullable,
    column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'ore_transactions'
  and column_name in (
      'quantity_scu',
      'unit_price',
      'total_value',
      'cash_effect'
  )
order by column_name;

-- Verification result 2:
select
    count(*) as ore_records,
    coalesce(sum(quantity_scu), 0) as entered_scu,
    coalesce(sum(total_value), 0) as verified_value,
    coalesce(sum(cash_effect), 0) as net_cash_effect,
    count(*) filter (
        where quantity_scu <= 0 and total_value > 0
    ) as records_missing_scu_quantity
from public.ore_transactions;
