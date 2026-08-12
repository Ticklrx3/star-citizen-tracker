-- Star Citizen Tracker
-- Profile picture storage migration
-- Run this entire file once in Supabase SQL Editor.

begin;

insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
values (
    'avatars',
    'avatars',
    true,
    2097152,
    array[
        'image/jpeg',
        'image/png',
        'image/webp'
    ]
)
on conflict (id) do update
set
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can view own avatar objects"
on storage.objects;

drop policy if exists "Users can upload own avatars"
on storage.objects;

drop policy if exists "Users can update own avatars"
on storage.objects;

drop policy if exists "Users can delete own avatars"
on storage.objects;

create policy "Users can view own avatar objects"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can upload own avatars"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can update own avatars"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can delete own avatars"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
);

commit;

notify pgrst, 'reload schema';

select
    exists (
        select 1
        from storage.buckets
        where id = 'avatars'
          and public = true
    ) as avatar_bucket_ready;
