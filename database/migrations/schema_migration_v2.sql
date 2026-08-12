-- Run this in Supabase SQL Editor for an existing Star Citizen Tracker database.

alter table public.ore_transactions
    add column if not exists quantity_scu numeric not null default 0;

alter table public.ore_transactions
    drop constraint if exists ore_transactions_total_value_check;

alter table public.ore_transactions
    add constraint ore_transactions_total_value_check
    check (total_value >= 0);

alter table public.ore_transactions
    drop constraint if exists ore_transactions_quantity_scu_check;

alter table public.ore_transactions
    add constraint ore_transactions_quantity_scu_check
    check (quantity_scu >= 0);
