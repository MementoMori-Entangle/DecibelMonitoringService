import os
import sys
import time
from concurrent import futures
from datetime import datetime

import grpc
import psycopg2

sys.path.append(os.path.join(os.path.dirname(__file__), '../proto'))
import decibel_logger_pb2
import decibel_logger_pb2_grpc
from gps_log_util import fetch_gps_logs, build_gps_dict
from config import (ACCESS_LOG_TABLE, AUTH_MODE, DB_HOST, DB_NAME, DB_PASS,
                    DB_PORT, DB_USER, DECIBEL_LOG_TABLE, LOG_IPV4_ONLY, PORT,
                    SLEEP_TIME)


# アクセストークンの有効性をDBから判定
def is_valid_token(token):
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASS
        )
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS access_tokens (
                    id SERIAL PRIMARY KEY,
                    token VARCHAR(128) UNIQUE NOT NULL,
                    description VARCHAR(256),
                    enabled BOOLEAN DEFAULT TRUE
                )
            """)
            cur.execute(
                "SELECT enabled FROM access_tokens WHERE token = %s", (token,)
            )
            row = cur.fetchone()
        conn.close()
        return bool(row) and row[0] is True
    except Exception as e:
        print(f"[TOKEN CHECK ERROR] {e}", flush=True)
        return False


def log_access(ip_addr, access_token, success, reason):
    """
    アクセスログをDBに記録する
    :param ip_addr: str, クライアントIP
    :param access_token: str, アクセストークン
    :param success: bool, 認証成功かどうか
    :param reason: str, エラー理由や備考
    """
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASS
        )
        with conn.cursor() as cur:
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS {ACCESS_LOG_TABLE} (
                    id SERIAL PRIMARY KEY,
                    access_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    ip_addr VARCHAR(64),
                    access_token VARCHAR(128),
                    success BOOLEAN,
                    reason TEXT
                )
            """)
            cur.execute(f"""
                INSERT INTO {ACCESS_LOG_TABLE} (ip_addr, access_token, success, reason)
                VALUES (%s, %s, %s, %s)
            """, (ip_addr, access_token, success, reason))
        conn.commit()
        conn.close()
    except Exception as e:
        try:
            conn.rollback()
        except Exception:
            pass
        print(f"[ACCESS LOGGING ERROR] {e}", flush=True)

def fetch_decibel_logs(start_dt=None, end_dt=None):
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )
    with conn.cursor() as cur:
        query = f"SELECT timestamp, decibel_a FROM {DECIBEL_LOG_TABLE}"
        params = []
        if start_dt and end_dt:
            query += " WHERE timestamp >= %s AND timestamp <= %s"
            params = [start_dt, end_dt]
        elif start_dt:
            query += " WHERE timestamp >= %s"
            params = [start_dt]
        elif end_dt:
            query += " WHERE timestamp <= %s"
            params = [end_dt]
        query += " ORDER BY timestamp ASC"
        cur.execute(query, params)
        results = cur.fetchall()
    conn.close()
    return results

class DecibelLoggerServicer(decibel_logger_pb2_grpc.DecibelLoggerServicer):
    def GetDecibelLog(self, request, context):
        # クライアントIP取得
        import urllib.parse
        ip_addr = None
        try:
            peer = context.peer()
            # peer例: 'ipv4:127.0.0.1:12345' または 'ipv6:%5B::1%5D:12345'
            if LOG_IPV4_ONLY and 'ipv4:' in peer:
                # IPv4優先
                ip_and_port = peer.split('ipv4:', 1)[1]
                ip_part = ip_and_port.rsplit(':', 1)[0]
                ip_addr = urllib.parse.unquote(ip_part)
            elif not LOG_IPV4_ONLY and 'ipv6:' in peer:
                # IPv6優先
                ip_and_port = peer.split('ipv6:', 1)[1]
                ip_part = ip_and_port.rsplit(':', 1)[0]
                ip_addr = urllib.parse.unquote(ip_part.strip('[]'))
            elif 'ipv4:' in peer:
                # fallback: IPv4
                ip_and_port = peer.split('ipv4:', 1)[1]
                ip_part = ip_and_port.rsplit(':', 1)[0]
                ip_addr = urllib.parse.unquote(ip_part)
            elif 'ipv6:' in peer:
                # fallback: IPv6
                ip_and_port = peer.split('ipv6:', 1)[1]
                ip_part = ip_and_port.rsplit(':', 1)[0]
                ip_addr = urllib.parse.unquote(ip_part.strip('[]'))
        except Exception:
            ip_addr = None

        # アクセストークン検証（DBから有効なもののみ許可）
        if not is_valid_token(request.access_token):
            print(f"[DEBUG] Logging access failure: ip={ip_addr}, token={request.access_token}", flush=True)
            log_access(ip_addr, request.access_token, False, 'Invalid access token')
            print(f"[DEBUG] log_access called for failure", flush=True)
            context.set_code(grpc.StatusCode.UNAUTHENTICATED)
            context.set_details('Invalid access token')
            return decibel_logger_pb2.DecibelLogResponse()
        # 日時パース
        start_dt = None
        end_dt = None
        dt_format = "%Y/%m/%d %H:%M:%S"
        try:
            if request.start_datetime:
                start_dt = datetime.strptime(request.start_datetime, dt_format)
            if request.end_datetime:
                end_dt = datetime.strptime(request.end_datetime, dt_format)
        except Exception:
            log_access(ip_addr, request.access_token, False, 'Invalid datetime format')
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details('Invalid datetime format')
            return decibel_logger_pb2.DecibelLogResponse()
        # 正常アクセスも記録
        log_access(ip_addr, request.access_token, True, 'OK')
        logs = fetch_decibel_logs(start_dt, end_dt)
        response = decibel_logger_pb2.DecibelLogResponse()
        if getattr(request, 'use_gps', False):
            gps_logs = fetch_gps_logs(start_dt, end_dt)
            gps_dict = build_gps_dict(gps_logs)
            for row in logs:
                ts = row[0].replace(microsecond=0)
                lat, lng = gps_dict.get(ts, (0.0, 0.0))
                dt_str = row[0].strftime("%Y/%m/%d %H:%M:%S")
                response.logs.append(decibel_logger_pb2.DecibelData(datetime=dt_str, decibel=row[1], latitude=lat, longitude=lng))
        else:
            for row in logs:
                dt_str = row[0].strftime("%Y/%m/%d %H:%M:%S")
                response.logs.append(decibel_logger_pb2.DecibelData(datetime=dt_str, decibel=row[1]))
        return response

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    decibel_logger_pb2_grpc.add_DecibelLoggerServicer_to_server(DecibelLoggerServicer(), server)

    if AUTH_MODE == 'none':
        server.add_insecure_port(f'[::]:{PORT}')
        print(f"gRPC server started (no TLS) on port {PORT}.")
    elif AUTH_MODE == 'tls':
        with open(os.path.join("certs", "server.crt"), "rb") as f:
            server_cert = f.read()
        with open(os.path.join("certs", "server.key"), "rb") as f:
            server_key = f.read()
        with open(os.path.join("certs", "ca.crt"), "rb") as f:
            ca_cert = f.read()
        server_credentials = grpc.ssl_server_credentials(
            [(server_key, server_cert)],
            root_certificates=ca_cert,
            require_client_auth=False
        )
        server.add_secure_port(f'[::]:{PORT}', server_credentials)
        print(f"gRPC TLS server started on port {PORT}.")
    elif AUTH_MODE == 'mtls':
        with open(os.path.join("certs", "server.crt"), "rb") as f:
            server_cert = f.read()
        with open(os.path.join("certs", "server.key"), "rb") as f:
            server_key = f.read()
        with open(os.path.join("certs", "ca.crt"), "rb") as f:
            ca_cert = f.read()
        server_credentials = grpc.ssl_server_credentials(
            [(server_key, server_cert)],
            root_certificates=ca_cert,
            require_client_auth=True
        )
        server.add_secure_port(f'[::]:{PORT}', server_credentials)
        print(f"gRPC mTLS server started on port {PORT}.")
    else:
        raise Exception(f"不明なAUTH_MODE: {AUTH_MODE}")

    server.start()
    try:
        while True:
            time.sleep(SLEEP_TIME)
    except KeyboardInterrupt:
        server.stop(0)

if __name__ == "__main__":
    serve()
