# アクセストークン管理画面

## 概要
- FastAPI + SQLAlchemy + Jinja2 + モダンCSSで実装したローカル限定のアクセストークン管理Web画面です。
- トークンの追加・有効/無効切替・削除が可能です。
- ローカルホスト(127.0.0.1/::1)からのみアクセス可能です。

## 起動方法

1. 必要パッケージのインストール（初回のみ）
   ```sh
   pip install fastapi uvicorn[standard] sqlalchemy psycopg2-binary jinja2
   ```

2. サーバー起動
   ```sh
   uvicorn admin.main:app --reload --host 127.0.0.1 --port 8000
   ```

3. ブラウザで http://127.0.0.1:8000/ にアクセス

## データベース
- PostgreSQLの `access_tokens` テーブルを自動作成します。
- DB接続情報は `admin/main.py` 冒頭の環境変数で設定可能です。

## 注意
- 外部からのアクセスは自動的に拒否されます。
- 本番運用時は更なる認証・監査対策を推奨します。
