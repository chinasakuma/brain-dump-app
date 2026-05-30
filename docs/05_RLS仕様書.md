# ブレインダンプアプリ RLS 仕様書（Row Level Security）

## 1. 文書概要

| 項目 | 内容 |
|------|------|
| 目的 | ログイン済みユーザーが **自分が作成したメモのみ**操作でき、他ユーザーのデータや未認証アクセスを **DB 層で拒否**する |
| 対象 DB | Supabase（PostgreSQL）`public` スキーマ |
| 関連要求 | 要求仕様 **FR-08**（メモのユーザー別管理）、**FR-09**（DB レベルのアクセス制御）、§6.1 セキュリティ |
| 関連文書 | `docs/02_DB仕様書.md`（テーブル定義）、`docs/04_機能仕様書.md`（アプリ側クエリ） |

**本書の位置づけ**

- **どのテーブルに・どの操作（SELECT / INSERT / UPDATE / DELETE）に・どの条件で**アクセスを許可するかを定義する。
- 実行用 SQL は **`sql/enable_rls_policies.sql`**、手順は **`docs/06_RLS適用手順.md`** を参照。

## 2. 対象テーブルと前提

| 論理名（要求・画面） | 物理テーブル名 | 所有者列 | 備考 |
|----------------------|----------------|----------|------|
| メモ | **`public.brain_dumps`** | **`user_id`**（`auth.users.id` 参照） | ユーザーが作成するデータ。RLS の主対象 |
| カテゴリ（categories） | **`public.memo_categories`** | **なし**（共有マスタ） | アプリは **SELECT のみ**。ユーザー別の作成データではない |

**共通前提**

- クライアントはブラウザから **anon key** で Supabase JS SDK を利用するが、メモ操作時は **ログイン済み JWT** が付与され、PostgREST 上は **`authenticated` ロール**として扱われる。
- ポリシーで参照する現在ユーザー ID は Supabase 標準の **`auth.uid()`** とする（`brain_dumps.user_id` と比較）。
- **RLS を有効化したテーブルでは、ポリシーに合致しない操作はすべて拒否**される（デフォルト deny）。
- **`service_role` キー**は RLS をバイパスする。ブラウザには埋め込まない。

**`memo_categories` について**

- スキーマに `user_id` は **持たない**（DB 変更範囲外）。
- 「自分が作成したデータのみ」は **メモ（`brain_dumps`）に適用**する。カテゴリは **認証済みユーザー全員が同じマスタを読む**設計とし、**書き込みはアプリ・クライアントから行わない**。

## 3. ロール別の原則

| ロール | 説明 | `brain_dumps` | `memo_categories` |
|--------|------|---------------|-------------------|
| **`anon`** | 未ログイン（JWT なし） | **すべて拒否** | **すべて拒否** |
| **`authenticated`** | ログイン済み | 下記 §4 のとおり（本人の行のみ） | **SELECT のみ許可**、書き込み系は拒否 |
| **`service_role`** | サーバー管理用 | 本仕様の対象外（運用・マイグレーション用） | 同左 |

## 4. テーブル別ポリシー定義

### 4.1 `public.brain_dumps`（メモ）

**RLS:** **有効（ENABLE ROW LEVEL SECURITY）**

いずれのポリシーも、条件式の核心は次とする。

- **行の所有者:** `user_id`
- **ログイン中ユーザー:** `auth.uid()`
- **一致条件:** `user_id = auth.uid()`

| 操作 | 許可ロール | USING（既存行の判定） | WITH CHECK（新規・変更後の判定） | 意図 |
|------|------------|------------------------|----------------------------------|------|
| **SELECT** | `authenticated` | `user_id = auth.uid()` | — | 本人のメモのみ一覧・単件取得 |
| **INSERT** | `authenticated` | — | `user_id = auth.uid()` | 他人の `user_id` での作成を防止 |
| **UPDATE** | `authenticated` | `user_id = auth.uid()` | `user_id = auth.uid()` | 本人の行のみ更新。更新後も所有者が自分 |
| **DELETE** | `authenticated` | `user_id = auth.uid()` | — | 本人の行のみ削除 |
| **SELECT / INSERT / UPDATE / DELETE** | `anon` | **許可しない**（ポリシーなし＝拒否） | — | 未ログインではメモ不可 |

**INSERT 時の注意（実装・SQL 生成時）**

- クライアントが `user_id` に **他人の UUID** を送っても、`WITH CHECK (user_id = auth.uid())` により **拒否**される。
- `user_id` が **NULL** の INSERT も **拒否**される（`auth.uid()` と一致しないため）。アプリは必ずログイン中ユーザーの ID をセットする（機能仕様書）。

**UPDATE 時の注意**

- `USING` により、他ユーザーの行は更新対象に **現れない**（0 件更新）。
- `WITH CHECK` により、更新で `user_id` を他人に **差し替えられない**。

---

### 4.2 `public.memo_categories`（カテゴリ / categories）

**RLS:** **有効（ENABLE ROW LEVEL SECURITY）**

| 操作 | 許可ロール | USING | WITH CHECK | 意図 |
|------|------------|-------|------------|------|
| **SELECT** | `authenticated` | `true`（全行） | — | ログイン済みならドロップダウン用マスタを読める |
| **INSERT** | — | **許可しない** | — | クライアントからのマスタ作成は行わない |
| **UPDATE** | — | **許可しない** | — | 同上 |
| **DELETE** | — | **許可しない** | — | 同上 |
| **すべて** | `anon` | **許可しない** | — | 未ログインではカテゴリも読めない |

**補足**

- マスタの投入・変更は **SQL Editor / 管理操作（`service_role` 等）** で行う想定とする。
- 将来、ユーザー別カテゴリが必要になった場合は **`user_id` 列の追加とポリシー見直し**が別要件となる（本仕様のスコープ外）。

## 5. ポリシー一覧（実装用チェックリスト）

SQL 生成時に、少なくとも次のポリシー（または同等の論理）を定義すること。

| # | テーブル | ポリシー名（例） | コマンド | ロール | 条件の要約 |
|---|----------|------------------|----------|--------|------------|
| 1 | `brain_dumps` | （例）`brain_dumps_select_own` | SELECT | `authenticated` | `user_id = auth.uid()` |
| 2 | `brain_dumps` | （例）`brain_dumps_insert_own` | INSERT | `authenticated` | WITH CHECK `user_id = auth.uid()` |
| 3 | `brain_dumps` | （例）`brain_dumps_update_own` | UPDATE | `authenticated` | USING / WITH CHECK `user_id = auth.uid()` |
| 4 | `brain_dumps` | （例）`brain_dumps_delete_own` | DELETE | `authenticated` | `user_id = auth.uid()` |
| 5 | `memo_categories` | （例）`memo_categories_select_authenticated` | SELECT | `authenticated` | `true` |

**実行順序**

1. `brain_dumps.user_id` 列・外部キー・既存データのバックフィルが済んでいること（`docs/02_DB仕様書.md`）
2. **`sql/enable_rls_policies.sql`** を Supabase SQL Editor で実行（手順: **`docs/06_RLS適用手順.md`**）
3. 必要に応じ、従来の **anon への広い GRANT**（`sql/enable_anon_access.sql`）と併用する場合は、**RLS 優先**となることを理解したうえで権限を見直す

## 6. アプリケーションとの関係

| 層 | 役割 |
|----|------|
| **アプリ（`index.html`）** | `getUser()` の `user.id` で `user_id` を INSERT／クエリに付与（機能仕様書 FR-08） |
| **RLS（本書）** | 上記が漏れても、DB が他ユーザー行へのアクセスをブロック |

両方を満たすことが要求仕様 §6.1 の意図である。

## 7. 受入確認の観点（テスト時）

| # | 確認内容 |
|---|----------|
| T-1 | ユーザー A でログインし、A のメモのみ SELECT できる |
| T-2 | ユーザー A の JWT では、ユーザー B の `brain_dumps` 行を SELECT / UPDATE / DELETE できない |
| T-3 | 未ログイン（anon）では `brain_dumps` / `memo_categories` にアクセスできない |
| T-4 | ログイン済みで `memo_categories` を SELECT できる |
| T-5 | ログイン済みでも `memo_categories` へ INSERT / UPDATE / DELETE できない |

## 8. 参照

| 文書 | 内容 |
|------|------|
| `docs/01_要求仕様書.md` | FR-08 / FR-09、AC-11〜13 |
| `docs/02_DB仕様書.md` | `brain_dumps.user_id`、テーブル定義 |
| `docs/04_機能仕様書.md` | メモ CRUD の `user_id` 条件 |

---
*Document version: 1.1 — 対象: `brain_dumps`, `memo_categories`（categories）。SQL: `sql/enable_rls_policies.sql`*
