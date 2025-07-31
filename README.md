# DecibelMonitoringService

ラズパイ + USBマイクでデシベルロガー

# クライアントアプリについて
server内にあるdecibel_client_app.pyは簡易確認用です。  
実際のクライアントはclient内のFlutter(Android)アプリです。

端末 Raspberry Pi 4 ModelB  
USBマイク MI-305  
<img width="600" height="400" alt="2018年製ラズパイ" src="https://github.com/user-attachments/assets/11e98145-9f6d-46e2-8dd5-232249493acb" />

Raspberry Pi OS 64bit  
(Raspberry Pi Imager使用)

サーバー(Raspberry Pi)  
デシベル収集プログラム(mic_db_logger.py)  
データベース(PostgreSQL)  
データアクセスはgRPCサーバー経由 (mTLS対応)

開発環境  
　Python 3.13.3  
　PostgreSQL 17.5 on x86_64-windows, compiled by msvc-19.44.35209, 64-bit  
　gRPC grpcio 1.73.1

実行環境  
　Python 3.11.2  
　psql (PostgreSQL) 15.13 (Debian 15.13-0+deb12u1)  
　gRPC grpcio 1.73.1

---
# id、password、portなどの値はテスト用です。
# 必要に応じて変更してください。
---

ラズパイOSインストール後設定  
sudo apt update  
sudo apt upgrade -y  
sudo apt full-upgrade -y  
sudo apt autoremove -y  

SDカードにOS書き込む時点で設定している場合は不要  
sudo raspi-config

ファイヤーウォール設定  
sudo apt install ufw

[初期設定確認]  
sudo nano /etc/default/ufw

sudo ufw disable

sudo ufw default deny  
sudo ufw allow 80/tcp  
sudo ufw allow 443/tcp  
sudo ufw allow 50051/tcp # gRPC  
sudo ufw allow from 192.168.11.0/24 to any port 22 proto tcp # SSH  
sudo ufw allow from 192.168.11.0/24 to any port 5900 proto tcp # VNC

sudo ufw enable

PostgreSQLインストール  
sudo apt update  
sudo apt install postgresql postgresql-contrib

## 今回は未対応
検索などの日本語環境特有のソート順などが必要な場合はクラスタレベルで作り直す必要あり  
locale -a | grep ja_JP  
未設定の場合  
sudo locale-gen ja_JP.UTF-8  
追加失敗した場合は有効ロケール修正(ja行コメントアウト)  
sudo nano /etc/locale.gen  
sudo update-locale  
ラズパイがイギリス製だからen_GB.UTF-8がデフォルト?  
(Raspberry Pi Imagerで日本語設定していたが、適用できていない状態でした)
##

# クラスタ再構築方法
ラズパイ初期設定(ロケールGB)でPostgreSQLをインストールした後に  
やっぱりOS環境は日本語がいいからJAにした場合、  
PostgreSQLのクラスタがGBのままなので、サービスの起動に失敗します。  
以下の方法でクラスタを再作成して対応が必要です。

-- データは完全に消えるので注意  
sudo pg_dropcluster 15 main --stop  
sudo pg_createcluster 15 main --locale=ja_JP.UTF-8 --start  
-- サービス起動  
sudo systemctl restart postgresql

データベース状態確認  
sudo su - postgres  
psql -U postgres -c "\l"  
psql -U postgres -c "\du"

ユーザーとDB作成  
CREATE USER "DMLogger" WITH PASSWORD 's#gs1Gk3Dh8sa!g3s';  
CREATE DATABASE "DecibelMonitor" OWNER "DMLogger";

## ja_JP.UTF-8対応クラスタ対応後なら可能  
CREATE DATABASE "DecibelMonitor"  
  OWNER "DMLogger"  
  ENCODING 'UTF8'  
  LC_COLLATE='ja_JP.utf8'  
  LC_CTYPE='ja_JP.utf8'  
  TEMPLATE template0;  
##

権限追加  
GRANT CONNECT ON DATABASE "DecibelMonitor" TO "DMLogger";  
GRANT USAGE, CREATE ON SCHEMA public TO "DMLogger";  
ALTER DEFAULT PRIVILEGES IN SCHEMA public  
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "DMLogger";

アプリで使用するユーザーでアクセストークンテーブル作成  
psql -h localhost -d "DecibelMonitor" -U "DMLogger"

VNCでデスクトップ表示が正常にできない → 一度直繋ぎで設定したらできました。  
webアプリでアクセストークンを設定できないため、  
直接DBテーブル作成してデータ設定

CREATE TABLE IF NOT EXISTS access_tokens (  
 id SERIAL PRIMARY KEY,  
 token VARCHAR(128) UNIQUE NOT NULL,  
 description VARCHAR(256),  
 enabled BOOLEAN DEFAULT TRUE  
);

INSERT INTO access_tokens (token, description, enabled)  
VALUES('12345', 'テスト', true);

権限確認  
SELECT tablename, tableowner  
FROM pg_tables  
WHERE schemaname = 'public';

SELECT grantee, privilege_type  
FROM information_schema.role_table_grants  
WHERE grantee = 'DMLogger';


gRPC自動生成部分  
cd C:\workspace\DecibelMonitoringService\proto  
python -m grpc_tools.protoc -I ../proto --python_out=../server --grpc_python_out=../server ../proto/decibel_logger.proto

# pipではインストールできないので事前にapt対応
sudo apt update  
sudo apt install python3-pyqt5 python3-pyqt5.qtsvg python3-pyqt5.qtwebengine  
sudo apt install portaudio19-dev  
sudo apt install libpq-dev

1. venvを作成  
-- python3 -m venv dms # PyQt5の問題が解決できないため--system-site-packages使用  
python3 -m venv dms --system-site-packages

2. 仮想環境を有効化  
source dms/bin/activate

3. 仮想環境でpip install (PyQt5やPyAudio、psycopg2の一部はaptでインストール)  
基本パッケージ  
pip install pyaudio numpy librosa psycopg2 grpcio grpcio-tools matplotlib  
管理画面用パッケージ  
pip install fastapi uvicorn[standard] sqlalchemy psycopg2-binary fastapi-admin jinja2

4. 仮想環境を抜ける  
deactivate

## Windows環境では直インストール可能(PEP668警告がないため)
基本パッケージ  
pip install pyaudio numpy librosa psycopg2 grpcio grpcio-tools PyQt5 matplotlib  

管理画面用パッケージ  
pip install fastapi uvicorn[standard] sqlalchemy psycopg2-binary fastapi-admin jinja2

アプリソース取得  
sudo apt update  
sudo apt install git

クローンしてソース取得  
git clone https://github.com/MementoMori-Entangle/DecibelMonitoringService.git

# 証明書関連
リポジトリには/server/配下の  
certs/  
ca.crt  
client.crt  
client.key  
server.crt  
server.key  
client/配下の  
assets/certs/  
ca.crt  
client.crt  
client.key  
android/  
key.properties  
android/app/  
my-release-key.jks  
は登録されていません。  
環境に合わせて作成してください。

デシベルデータ登録常駐アプリ  
[Windows]  
cd C:\workspace\DecibelMonitoringService\server  
python mic_db_logger.py

[Linux]  
cd /home/entangle/workspace/DecibelMonitoringService/server  
python mic_db_logger.py

mic_db_logger.pyと同じ方法でテスト集計したデシベル値  
<img width="320" height="240" alt="マイクテスト" src="https://github.com/user-attachments/assets/916a0ff6-e1c4-406c-8163-4cd373950223" />

# ALSAやJACK関連のエラー・警告  
LinuxでPyAudioやPortAudioが内部でデバイス探索を行う際によく出るものです。  
Windowsでは表示されず、Linux固有の現象  
気になる人は環境変数かimport冒頭で抑制してください。

# 低音・中音・高音の問題
dB(A)は中音(人の音域)設定のため、  
金属がすれる音(低音)などは実際の人間の感じられるdB(A)値より低く求められる問題がある。  
70dB(A)に感じても50dB(A)ほどとして求められる(自前ツールやwebフリーツールで確認)

アクセストークンはpsqlで直接操作するかWebアプリ(ローカル限定)で登録  
cd C:\workspace\DecibelMonitoringService\server  
uvicorn admin.main:app --reload --host 127.0.0.1 --port 8000

# decibel_logger_server.py起動前に環境変数設定
gRPC認証設定  
・認証なし  
set GRPC_SERVER_AUTH=none  
export GRPC_SERVER_AUTH=none  
・サーバー認証のみ  
set GRPC_SERVER_AUTH=tls  
export GRPC_SERVER_AUTH=tls   
・mTLS  
set GRPC_SERVER_AUTH=mtls  
export GRPC_SERVER_AUTH=tls

アクセスログipv4登録設定 (ipv6で登録する場合はfalse)  
set GRPC_LOG_IPV4_ONLY=true  
export GRPC_LOG_IPV4_ONLY=true

# Linux環境でdecibel_client_app.pyを使用する場合
Linux環境日本語フォントインストール(必要な場合)  
sudo apt update  
sudo apt install fonts-noto-cjk

# サービス登録(必要な場合)
対象  
・mic_db_logger.py(デシベルデータ集計 常駐)  
・decibel_logger_server.py(デシベルデータ配信gRPCサービス 常駐)  
注意  
decibel_logger_serverはEnvironmentにGRPC_SERVER_AUTHを  
指定しない場合は認証なしとなります。  
ExecStartのpythonは仮想環境で稼働することを考慮してください。  
上記2サービスはPostgreSQLサービスが稼働していることが前提条件です。  
例) PostgreSQLサービス名を確認して指定してください。  
After=postgresql@15-main.service  
Requires=postgresql@15-main.service  
で制御してください。

# ライセンス 2025年7月31日時点
・server  
python
| パッケージ名       | ライセンス      |
|-------------------|----------------|
| pyaudio	          | MIT            |
| numpy	            | BSD            |
| librosa	          | ISC            | 
| psycopg2	        | LGPL           |
| grpcio	          | Apache-2.0     |
| grpcio-tools	    | Apache-2.0     |
| PyQt5	            | GPL v3         |
| matplotlib	      | PSF            |
| fastapi	          | MIT            |
| uvicorn[standard]	| BSD-3-Clause   |
| sqlalchemy	      | MIT            |
| psycopg2-binary	  | LGPL           |
| fastapi-admin	    | MIT            | 
| jinja2	          | BSD-3-Clause   | 

※ PyQt5はGPL v3（商用利用や配布時は注意）、psycopg2/psycopg2-binaryはLGPLです。  
詳細や条件は各公式リポジトリ・PyPIでご確認ください。  
クライアントアプリ(window画面用)にPyQt5を使用しているため、GPL v3ライセンスとなります。

・client  
Dart/Flutter
| パッケージ名                 | バージョン   | ライセンス    |
|-----------------------------|-------------|--------------|
| flutter                     | SDK         | BSD-3        |
| cupertino_icons             | ^1.0.8      | MIT          |
| grpc                        | ^4.0.4      | BSD-3        |
| local_auth                  | ^2.1.8      | BSD-3        |
| fl_chart                    | ^0.66.2     | MIT          |
| intl                        | ^0.19.0     | BSD-3        |
| protobuf                    | ^4.1.0      | BSD-3        |
| provider                    | ^6.1.2      | MIT          |
| shared_preferences          | ^2.5.3      | BSD-3        |
| flutter_launcher_icons      | ^0.14.4     | MIT          |
| flutter_test                | SDK         | BSD-3        |
| flutter_lints               | ^5.0.0      | BSD-3        |
| workmanager                 | ^0.7.0      | MIT          |
| flutter_local_notifications | ^19.4.0     | BSD-3-Clause |
| permission_handler          | ^11.3.1     | BSD-3-Clause |

Android/Java(kotlin)
| パッケージ名                              | バージョン   | ライセンス      |
|------------------------------------------|-------------|----------------|
| io.grpc:grpc-okhttp                      | 1.63.0	     | Apache-2.0     |
| io.grpc:grpc-protobuf                    | 1.63.0	     | Apache-2.0     |
| io.grpc:grpc-stub                        | 1.63.0	     | Apache-2.0     |
| javax.annotation:javax.annotation-api    | 1.3.2	     | CDDL/GPL-2.0   |
| org.bouncycastle:bcprov-jdk18on          | 1.78.1	     | MIT            |
| org.bouncycastle:bcpkix-jdk18on          | 1.78.1	     | MIT            |
| com.android.tools:desugar_jdk_libs       | 2.1.4       | Apache-2.0     |

