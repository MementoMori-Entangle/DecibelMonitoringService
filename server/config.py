import os

DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_PORT = os.environ.get('DB_PORT', '5432')
DB_NAME = os.environ.get('DB_NAME', 'DecibelMonitor')
DB_USER = os.environ.get('DB_USER', 'DMLogger')
DB_PASS = os.environ.get('DB_PASS', 's#gs1Gk3Dh8sa!g3s')
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

PORT = int(os.environ.get('GRPC_PORT', 50051))
SLEEP_TIME = int(os.environ.get('SLEEP_TIME', 86400))

# 認証方式: 'none', 'tls', 'mtls'
AUTH_MODE = os.environ.get('GRPC_SERVER_AUTH', 'none').lower()
# IPv4優先でアクセスログ記録するか
LOG_IPV4_ONLY = os.environ.get('GRPC_LOG_IPV4_ONLY', 'false').lower() == 'true'

DECIBEL_LOG_TABLE = 'decibel_log'
ACCESS_LOG_TABLE = 'access_log'
