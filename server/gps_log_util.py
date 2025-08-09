from psycopg2 import sql
import psycopg2
from config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS, GPS_LOG_TABLE

def fetch_gps_logs(start_dt=None, end_dt=None):
    conn = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASS
        )
        with conn.cursor() as cur:
            base_query = sql.SQL("SELECT timestamp, latitude, longitude FROM {}").format(sql.Identifier(GPS_LOG_TABLE))
            where_clauses = []
            params = []
            if start_dt:
                where_clauses.append(sql.SQL("timestamp >= %s"))
                params.append(start_dt)
            if end_dt:
                where_clauses.append(sql.SQL("timestamp <= %s"))
                params.append(end_dt)
            if where_clauses:
                base_query = base_query + sql.SQL(" WHERE ") + sql.SQL(" AND ").join(where_clauses)
            base_query = base_query + sql.SQL(" ORDER BY timestamp ASC")
            cur.execute(base_query, params)
            results = cur.fetchall()
            return results
    except Exception as e:
        return []
    finally:
        if conn:
            conn.close()

def build_gps_dict(gps_logs):
    # 秒単位でタイムスタンプをキーにする
    gps_dict = {}
    for row in gps_logs:
        ts = row[0].replace(microsecond=0)
        gps_dict[ts] = (row[1], row[2])
    return gps_dict
