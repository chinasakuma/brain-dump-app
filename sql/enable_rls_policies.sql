-- RLS 有効化とポリシー設定（docs/05_RLS仕様書.md に準拠）
-- 対象: public.brain_dumps（メモ）、public.memo_categories（画面上の categories）
-- Supabase SQL Editor で本ファイルを一括実行すること。
--
-- 前提:
--   - sql/add_user_id_to_brain_dumps.sql 実行済み
--   - sql/backfill_brain_dumps_user_id.sql で既存行の user_id が埋まっていること

-- ---------------------------------------------------------------------------
-- 再実行用: 既存ポリシーを削除
-- ---------------------------------------------------------------------------
drop policy if exists brain_dumps_select_own on public.brain_dumps;
drop policy if exists brain_dumps_insert_own on public.brain_dumps;
drop policy if exists brain_dumps_update_own on public.brain_dumps;
drop policy if exists brain_dumps_delete_own on public.brain_dumps;
drop policy if exists memo_categories_select_authenticated on public.memo_categories;

-- ---------------------------------------------------------------------------
-- RLS 有効化
-- ---------------------------------------------------------------------------
alter table public.brain_dumps enable row level security;
alter table public.memo_categories enable row level security;

-- ---------------------------------------------------------------------------
-- brain_dumps: ログイン済みユーザーは本人の行のみ（auth.uid() = user_id）
-- ---------------------------------------------------------------------------

create policy brain_dumps_select_own
  on public.brain_dumps
  for select
  to authenticated
  using (user_id = auth.uid());

create policy brain_dumps_insert_own
  on public.brain_dumps
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy brain_dumps_update_own
  on public.brain_dumps
  for update
  to authenticated
  using (user_id = auth.uid());

create policy brain_dumps_delete_own
  on public.brain_dumps
  for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- memo_categories（categories）: 認証済みユーザーは SELECT のみ（全行）
-- INSERT / UPDATE / DELETE 用ポリシーは作らない（拒否）
-- ---------------------------------------------------------------------------

create policy memo_categories_select_authenticated
  on public.memo_categories
  for select
  to authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- ロールへの権限（RLS と併用。ポリシーを満たす操作のみ成功する）
-- ---------------------------------------------------------------------------
grant usage on schema public to authenticated;

grant select, insert, update, delete on table public.brain_dumps to authenticated;
grant select on table public.memo_categories to authenticated;
