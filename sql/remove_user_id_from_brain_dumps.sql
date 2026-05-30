-- 既存の public.brain_dumps から user_id を削除する（Supabase / psql 用）
-- user_id に紐づく外部キー・単一／複合インデックスは、列削除に伴い PostgreSQL が取り除きます。

alter table public.brain_dumps
  drop column if exists user_id;
