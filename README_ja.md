# nippo

Claude Codeのセッションログから日報を生成するAgent Skill

## 概要

`/nippo` は、Claude Codeのセッションログを分析し、その日に何をしたかをまとめた日報を生成するスキルです。

## 特徴

- Claude Codeセッションログからユーザーメッセージを抽出
- 日付でフィルタリング（今日、昨日、指定日）
- プロジェクト/リポジトリごとに作業内容をグルーピング
- サブエージェントのログを除外（メインセッションのみ対象）
- ファイル更新日時で事前フィルタリングして高速化
- Markdown形式で構造化された日報を出力

## 対応言語

| ディレクトリ | 言語 | コマンド |
|-------------|------|---------|
| `nippo/` | 日本語 | `/nippo` |
| `nippo-en/` | English (英語) | `/nippo` |
| `nippo-zh/` | 中文 (中国語) | `/nippo` |
| `nippo-ko/` | 한국어 (韓国語) | `/nippo` |

## インストール

リポジトリをクローンして、好みの言語のディレクトリをClaude Codeのskillsディレクトリにコピー:

```bash
git clone https://github.com/t-daisuke/nippo.git
cp -r nippo/nippo ~/.claude/skills/       # 日本語
# または
cp -r nippo/nippo-en ~/.claude/skills/    # 英語
# または
cp -r nippo/nippo-zh ~/.claude/skills/    # 中国語
# または
cp -r nippo/nippo-ko ~/.claude/skills/    # 韓国語
```

または1コマンドで（日本語版の例）:

```bash
git clone https://github.com/t-daisuke/nippo.git /tmp/nippo && cp -r /tmp/nippo/nippo ~/.claude/skills/
```

## 使い方

```
/nippo              # 今日の日報
/nippo yesterday    # 昨日の日報
/nippo 2026-01-22   # 指定日の日報
```

## 動作環境

- macOS（`stat -f` と `date -j` を使用しているため）
- `jq` コマンド（JSONパース用）
- Agent Skills対応のClaude Code

## 出力例

```markdown
# 日報 - 2026-01-22

## 今日やったこと

### my-webapp
- JWTを使ったユーザー認証機能を実装
- ログインフォームのバリデーションバグを修正
- 認証ミドルウェアのユニットテストを追加

### api-server
- データベースコネクションプーリングをリファクタリング
- APIドキュメントを更新

## 詳細

### セッション: my-webapp
- 作業ディレクトリ: /Users/alice/projects/my-webapp
- ブランチ: feature/user-auth

### ユーザーメッセージ
- ログインエンドポイントにJWT認証を追加して
- フォームバリデーションが動いてないので直して
- 認証ミドルウェアのテストを書いて

### セッション: api-server
- 作業ディレクトリ: /Users/alice/projects/api-server
- ブランチ: refactor/db-pool

### ユーザーメッセージ
- DBコネクションプールの設定を最適化して
- READMEに新しいAPIエンドポイントを追記して
```

## 仕組み

1. **collect-logs.sh** が `~/.claude/projects/` 配下のセッションログをスキャン
2. ファイル更新日時で事前フィルタリング（±1日）して高速化
3. 最初のユーザーメッセージのタイムスタンプでセッション日付を判定
4. セッションのメタ情報とユーザーメッセージを出力
5. **SKILL.md** がClaudeにデータを日報形式にまとめるよう指示

## ライセンス

MIT
