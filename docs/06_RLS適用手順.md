# RLS 適用手順（Supabase SQL Editor）

本手順は **`sql/enable_rls_policies.sql`** を Supabase 上で実行し、`docs/05_RLS仕様書.md` のポリシーを有効にするためのものです。

## 事前準備

次が完了していることを確認してください。

| 順 | 内容 | ファイル（参考） |
|----|------|------------------|
| 1 | `brain_dumps` に `user_id` 列がある | `sql/add_user_id_to_brain_dumps.sql` |
| 2 | 既存メモ行の `user_id` が自分の Auth ユーザー ID になっている | `sql/backfill_brain_dumps_user_id.sql`（UUID は自分の User UID に差し替えてから実行） |
| 3 | アプリでログインできる（Confirm email が OFF など） | 要求仕様 FR-05 |

**カテゴリテーブル名:** 画面上の「categories」は DB 上 **`public.memo_categories`** です。本 SQL は `memo_categories` に対して RLS を設定します。

## Supabase SQL Editor での実行手順

### 1. プロジェクトを開く

1. [Supabase Dashboard](https://supabase.com/dashboard) にログインする  
2. ブレインダンプアプリ用の **プロジェクト**を選択する  

### 2. SQL Editor を開く

1. 左メニューから **SQL Editor** をクリックする  
2. **New query**（新規クエリ）を選ぶ  

### 3. SQL を貼り付ける

1. ローカルの **`sql/enable_rls_policies.sql`** をエディタで開く  
2. ファイルの内容を **すべてコピー**する  
3. SQL Editor の入力欄に **貼り付け**る  

### 4. 実行する

1. 画面右下（または上部）の **Run**（実行）をクリックする  
2. 結果パネルに **Success** / エラーなしであることを確認する  

再実行する場合も同じファイルで問題ありません（先頭で既存ポリシーを `DROP` してから作り直します）。

### 5. ポリシーが付いたか確認する（任意）

1. 左メニュー **Database** → **Tables** を開く  
2. **`brain_dumps`** を選び、**Policies**（または RLS）タブで次の 4 件があるか確認する  
   - `brain_dumps_select_own`（SELECT）  
   - `brain_dumps_insert_own`（INSERT）  
   - `brain_dumps_update_own`（UPDATE）  
   - `brain_dumps_delete_own`（DELETE）  
3. **`memo_categories`** を選び、**`memo_categories_select_authenticated`**（SELECT）が 1 件あるか確認する  

### 6. アプリで動作確認する

1. `index.html` を **http:// または https://** で開く（`file://` 不可）  
2. **ログイン**する  
3. メモの **一覧表示・保存・編集・削除**ができること  
4. **ログアウト**後、メモ一覧が読めないこと（未ログインでは RLS により拒否）  
5. 別ユーザーアカウントがあれば、ユーザー A のメモがユーザー B の一覧に出ないこと（`docs/05_RLS仕様書.md` §7 T-1〜T-2）  

## 設定内容の要約

| テーブル | RLS | authenticated の許可 |
|----------|-----|----------------------|
| `brain_dumps` | 有効 | SELECT / UPDATE / DELETE: **USING** `(user_id = auth.uid())`、INSERT: **WITH CHECK** `(user_id = auth.uid())` |
| `memo_categories` | 有効 | SELECT のみ **USING** `(true)`（全行）。書き込みポリシーなし＝拒否 |
| 未ログイン（`anon`） | — | 上記ポリシーなしのため **すべて拒否** |

## エラーが出たとき

| 症状 | 対処の例 |
|------|----------|
| `column "user_id" does not exist` | 先に `sql/add_user_id_to_brain_dumps.sql` を実行する |
| INSERT が RLS で失敗する | ログイン JWT 付きで呼んでいるか、`INSERT` の `user_id` が `auth.uid()` と一致しているか確認する |
| 既存メモが一覧に出ない | `backfill` で `user_id` がログイン中ユーザーと一致しているか確認する |
| カテゴリが読めない | ログイン済みか。`memo_categories` に `memo_categories_select_authenticated` があるか確認する |

## 参照

| 文書・ファイル | 内容 |
|----------------|------|
| `docs/05_RLS仕様書.md` | ポリシー定義の正本 |
| `sql/enable_rls_policies.sql` | 実行用 SQL |

---
*要求仕様 FR-09 / AC-11〜13 に対応*
