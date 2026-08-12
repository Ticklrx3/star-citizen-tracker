-- Star Citizen Tracker V20
-- Contract salvage proceeds and connection hardening
-- Run this once in Supabase SQL Editor, then wait 10 seconds and reload the app.

begin;

alter table public.contracts
    add column if not exists salvage_value numeric;

update public.contracts
set salvage_value = 0
where salvage_value is null;

alter table public.contracts
    alter column salvage_value set default 0;

alter table public.contracts
    alter column salvage_value set not null;

alter table public.contracts
    drop constraint if exists contracts_salvage_value_check;

alter table public.contracts
    add constraint contracts_salvage_value_check
    check (salvage_value >= 0);

create index if not exists contracts_user_id_idx
    on public.contracts(user_id);

create index if not exists contracts_date_saved_idx
    on public.contracts(date_saved desc);

alter table public.contracts enable row level security;

drop policy if exists "Users can read own contracts" on public.contracts;
drop policy if exists "Users can insert own contracts" on public.contracts;
drop policy if exists "Users can update own contracts" on public.contracts;
drop policy if exists "Users can delete own contracts" on public.contracts;

create policy "Users can read own contracts"
on public.contracts
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can insert own contracts"
on public.contracts
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update own contracts"
on public.contracts
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can delete own contracts"
on public.contracts
for delete
to authenticated
using ((select auth.uid()) = user_id);

commit;

notify pgrst, 'reload schema';

select
    column_name,
    data_type,
    is_nullable,
    column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'contracts'
  and column_name in (
      'total_payout',
      'salvage_value',
      'expenses',
      'net_payout',
      'individual_share'
  )
order by ordinal_position;
