-- anon キー（ブラウザ）から brain_dumps / memo_categories に読み書きできるようにする
-- Supabase の Table Editor でテーブルだけ作った場合、RLS が有効でブロックされることがあります。
-- Supabase SQL Editor でこのファイルを実行してください。

alter table if exists public.brain_dumps disable row level security;
alter table if exists public.memo_categories disable row level security;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on table public.brain_dumps to anon, authenticated;
grant select, insert, update, delete on table public.memo_categories to anon, authenticated;
