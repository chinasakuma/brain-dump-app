-- brain_dumps / memo_categories: ブレインダンプアプリ用テーブル
-- Supabase SQL Editor / psql で実行すること。
--
-- Row Level Security (RLS) は当面オフとする。
-- 有効化する際は: alter table public.brain_dumps enable row level security;
-- に加えてポリシーを定義すること。

create table if not exists public.memo_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sort_order integer not null default 0,
  constraint memo_categories_name_key unique (name)
);

create index if not exists memo_categories_sort_order_idx
  on public.memo_categories (sort_order);

create table if not exists public.brain_dumps (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  category_id uuid null references public.memo_categories (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists brain_dumps_created_at_desc_idx
  on public.brain_dumps (created_at desc);

create index if not exists brain_dumps_category_id_idx
  on public.brain_dumps (category_id);

-- 開発用マスタ（必要に応じて削除・変更可）
insert into public.memo_categories (name, sort_order) values
  ('アイデア', 10),
  ('タスク', 20),
  ('学習・調査', 30),
  ('雑記', 40),
  ('その他', 50)
on conflict on constraint memo_categories_name_key do nothing;
