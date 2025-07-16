import pyaudio
import numpy as np
import time
import threading
import psycopg2
from datetime import datetime
import librosa

# --- 設定 ---
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 44100
MIN_INTERVAL_MS = 100  # 最小100ms
INTERVAL_MS = 500      # 計測間隔(ミリ秒)
INPUT_DEVICE_INDEX = 1  # マイクデバイス番号指定

# PostgreSQL接続情報
DB_HOST = "localhost"
DB_PORT = 5432
DB_NAME = "DecibelMonitor"
DB_USER = "DMLogger"
DB_PASS = "s#gs1Gk3Dh8sa!g3s"
TABLE_NAME = "decibel_log"

def rms_librosa(buf):
    rms = librosa.feature.rms(y=buf)
    return float(np.mean(rms))

def db_a_librosa(buf):
    rms = librosa.feature.rms(y=buf)
    db_a = librosa.amplitude_to_db(rms, ref=2*1e-5)
    return float(np.mean(db_a))

def connect_db():
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )
    return conn

def create_table_if_not_exists(conn):
    with conn.cursor() as cur:
        cur.execute(f"""
        CREATE TABLE IF NOT EXISTS {TABLE_NAME} (
            id SERIAL PRIMARY KEY,
            timestamp TIMESTAMP(3) NOT NULL,
            decibel_a REAL NOT NULL
        )
        """)
        conn.commit()

def insert_decibel(conn, dt, db_a):
    with conn.cursor() as cur:
        cur.execute(
            f"INSERT INTO {TABLE_NAME} (timestamp, decibel_a) VALUES (%s, %s)",
            (dt, db_a)
        )
        conn.commit()

def measure_and_log():
    # DB準備
    conn = connect_db()
    create_table_if_not_exists(conn)

    # 音声ストリーム準備
    audio = pyaudio.PyAudio()
    stream = audio.open(format=FORMAT,
                        channels=CHANNELS,
                        rate=RATE,
                        input=True,
                        input_device_index=INPUT_DEVICE_INDEX,
                        frames_per_buffer=CHUNK)

    interval_sec = max(INTERVAL_MS, MIN_INTERVAL_MS) / 1000.0

    try:
        while True:
            start_time = time.time()
            audio_bytes = stream.read(CHUNK, exception_on_overflow=False)
            data = np.frombuffer(audio_bytes, dtype=np.int16)
            audiodata = data.astype(np.float32) / ((2**15)-1)
            db_a = db_a_librosa(audiodata)

            now = datetime.now()
            # ミリ秒まで取得
            now_str = now.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
            # DB登録
            insert_decibel(conn, now, db_a)
            print(f"{now_str}: {db_a:.2f} dB(A) logged.")

            elapsed = time.time() - start_time
            sleep_time = interval_sec - elapsed
            if sleep_time > 0:
                time.sleep(sleep_time)
    except KeyboardInterrupt:
        print("Measurement stopped.")
    finally:
        stream.stop_stream()
        stream.close()
        audio.terminate()
        conn.close()

if __name__ == "__main__":
    # バックグラウンドスレッドで実行
    t = threading.Thread(target=measure_and_log, daemon=True)
    t.start()
    print("Decibel logger started. Press Ctrl+C to stop.")
    try:
        while t.is_alive():
            time.sleep(1)
    except KeyboardInterrupt:
        print("Exiting logger.")
