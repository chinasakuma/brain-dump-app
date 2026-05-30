-- 既存の brain_dumps 行に user_id を設定する（バックフィル）
-- DB 仕様書 v1.3 / docs/02_DB仕様書.md §5.4 手順 2
-- 前提: sql/add_user_id_to_brain_dumps.sql を実行済みであること。
-- Supabase SQL Editor で実行すること。
--
-- ※ 下記 UPDATE の UUID は、Supabase Dashboard > Authentication > Users の
--    対象ユーザーの「User UID」に差し替えてから実行してください。
--    （メッセージに UUID が未記載のため、プレースホルダーを入れています）

update public.brain_dumps
set user_id = '00000000-0000-0000-0000-000000000000'::uuid
where user_id is null;

-- 確認用（任意）: 未設定行が 0 件であること
-- select count(*) from public.brain_dumps where user_id is null;
