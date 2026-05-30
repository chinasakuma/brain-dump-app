-- memo_categories マスタの作成と brain_dumps への category_id 追加（NULL 可）
-- およびカテゴリ仮データ 5 件
-- Supabase SQL Editor / psql で実行すること。
--
-- 前提: public.brain_dumps が既に存在する環境向け。
-- 新規から一式作成する場合は sql/create_brain_dumps.sql を参照。

-- 1) カテゴリマスタ
create table if not exists public.memo_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sort_order integer not null default 0,
  constraint memo_categories_name_key unique (name)
);

create index if not exists memo_categories_sort_order_idx
  on public.memo_categories (sort_order);

-- 2) メモへの外部キー列（任意。未選択は NULL）
alter table public.brain_dumps
  add column if not exists category_id uuid null
  references public.memo_categories (id)
  on delete set null;

create index if not exists brain_dumps_category_id_idx
  on public.brain_dumps (category_id);

-- 3) 仮データ（再実行時は名前衝突を無視）
insert into public.memo_categories (name, sort_order) values
  ('アイデア', 10),
  ('タスク', 20),
  ('学習・調査', 30),
  ('雑記', 40),
  ('その他', 50)
on conflict on constraint memo_categories_name_key do nothing;
