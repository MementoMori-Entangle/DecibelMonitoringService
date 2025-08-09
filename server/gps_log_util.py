import psycopg2
from config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS, GPS_LOG_TABLE

def fetch_gps_logs(start_dt=None, end_dt=None):
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )
    with conn.cursor() as cur:
        query = f"SELECT timestamp, latitude, longitude FROM {GPS_LOG_TABLE}"
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

def build_gps_dict(gps_logs):
    # 秒単位でタイムスタンプをキーにする
    gps_dict = {}
    for row in gps_logs:
        ts = row[0].replace(microsecond=0)
        gps_dict[ts] = (row[1], row[2])
    return gps_dict
