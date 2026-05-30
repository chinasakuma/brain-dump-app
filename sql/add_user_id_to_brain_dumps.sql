-- brain_dumps に user_id カラムを追加する（NULL 可・auth.users 参照）
-- DB 仕様書 v1.3 / docs/02_DB仕様書.md §5.4 手順 1, 4
-- Supabase SQL Editor で実行すること。
--
-- 実行順: 本ファイル → sql/backfill_brain_dumps_user_id.sql
-- 既存行の user_id を埋めたあと、必要なら ALTER COLUMN user_id SET NOT NULL を別途検討。

alter table public.brain_dumps
  add column if not exists user_id uuid null;

alter table public.brain_dumps
  drop constraint if exists brain_dumps_user_id_fkey;

alter table public.brain_dumps
  add constraint brain_dumps_user_id_fkey
  foreign key (user_id) references auth.users (id) on delete cascade;

create index if not exists brain_dumps_user_id_created_at_idx
  on public.brain_dumps (user_id, created_at desc);
