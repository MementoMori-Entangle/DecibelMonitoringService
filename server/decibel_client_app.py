import datetime
import sys

import grpc
import matplotlib.pyplot as plt
from matplotlib.backends.backend_qt5agg import \
    FigureCanvasQTAgg as FigureCanvas
from PyQt5 import QtCore, QtWidgets

import decibel_logger_pb2
import decibel_logger_pb2_grpc

class DecibelClientApp(QtWidgets.QWidget):
    def on_hscroll(self, value):
        # 横スクロールでxlimを調整（y軸は常に全体表示）
        ax = self.figure.axes[0] if self.figure.axes else None
        if ax and ax.lines:
            xdata = ax.lines[0].get_xdata()
            ydata = ax.lines[0].get_ydata()
            data_len = len(xdata)
            if data_len > 0:
                view_count = min(100, data_len)
                start = int((data_len - view_count) * value / 99) if value > 0 else 0
                end = start + view_count
                # xlimはdatetime値で指定
                ax.set_xlim(xdata[start], xdata[min(end, data_len-1)])
                # y軸は全体範囲で固定
                if len(ydata) > 0:
                    ax.set_ylim(min(ydata) - 2, max(ydata) + 2)
                self.canvas.draw_idle()
    def __init__(self):
        import matplotlib.font_manager as fm
        import matplotlib.pyplot as plt

        # 日本語フォント設定（Windows標準のMS Gothic, Meiryo, Yu Gothicを優先）
        font_path = fm.findSystemFonts(fontpaths=None, fontext='ttf')
        jp_font = None
        for path in font_path:
            lower = path.lower()
            if 'msgothic' in lower or 'meiryo' in lower or 'yugoth' in lower:
                jp_font = path
                break
        if jp_font:
            plt.rcParams['font.family'] = fm.FontProperties(fname=jp_font).get_name()
        else:
            plt.rcParams['font.family'] = 'sans-serif'
        super().__init__()
        self.setWindowTitle('Decibel Logger gRPC Client')
        self.resize(1500, 1000)
        self.setup_ui()

    def setup_ui(self):
        # 認証方式選択
        self.auth_mode = QtWidgets.QComboBox()
        self.auth_mode.addItems(["認証なし", "TLS(サーバー認証のみ)", "mTLS(相互認証)"])
        layout = QtWidgets.QVBoxLayout(self)
        form_layout = QtWidgets.QFormLayout()
        form_layout.addRow('認証方式:', self.auth_mode)
        self.host_edit = QtWidgets.QLineEdit('localhost')
        self.port_edit = QtWidgets.QLineEdit('50051')
        self.token_edit = QtWidgets.QLineEdit('12345')
        self.start_edit = QtWidgets.QLineEdit('20250701 00:00:00')
        self.end_edit = QtWidgets.QLineEdit('20250715 00:00:00')
        form_layout.addRow('サーバー:', self.host_edit)
        form_layout.addRow('ポート番号:', self.port_edit)
        form_layout.addRow('アクセストークン:', self.token_edit)
        form_layout.addRow('開始日時:', self.start_edit)
        form_layout.addRow('終了日時:', self.end_edit)
        layout.addLayout(form_layout)
        self.request_btn = QtWidgets.QPushButton('リクエスト')
        self.request_btn.clicked.connect(self.on_request)
        layout.addWidget(self.request_btn)
        self.result_list = QtWidgets.QListWidget()
        layout.addWidget(self.result_list)
        self.graph_btn = QtWidgets.QPushButton('グラフ表示')
        self.graph_btn.clicked.connect(self.show_graph)
        layout.addWidget(self.graph_btn)
        self.figure = plt.Figure()
        self.canvas = FigureCanvas(self.figure)
        # スクロールエリアにキャンバスを追加
        self.scroll_area = QtWidgets.QScrollArea()
        self.scroll_area.setWidget(self.canvas)
        self.scroll_area.setWidgetResizable(True)
        layout.addWidget(self.scroll_area)
        # matplotlibのナビゲーションツールバー追加
        from matplotlib.backends.backend_qt5 import \
            NavigationToolbar2QT as NavigationToolbar
        self.toolbar = NavigationToolbar(self.canvas, self)
        layout.addWidget(self.toolbar)
        # 横スクロールバーの追加
        self.h_scroll = QtWidgets.QScrollBar(QtCore.Qt.Horizontal)
        self.h_scroll.valueChanged.connect(self.on_hscroll)
        layout.addWidget(self.h_scroll)
        self.decibel_data = []

    def on_request(self):
        self.result_list.clear()
        self.decibel_data = []
        host = self.host_edit.text()
        port = self.port_edit.text()
        server_addr = f"{host}:{port}"
        token = self.token_edit.text()
        start_dt = self.start_edit.text()
        end_dt = self.end_edit.text()
        try:
            mode = self.auth_mode.currentText()
            if mode == "認証なし":
                channel = grpc.insecure_channel(server_addr)
            elif mode == "TLS(サーバー認証のみ)":
                import os
                with open(os.path.join("certs", "ca.crt"), "rb") as f:
                    ca_cert = f.read()
                creds = grpc.ssl_channel_credentials(root_certificates=ca_cert)
                channel = grpc.secure_channel(server_addr, creds)
            elif mode == "mTLS(相互認証)":
                import os
                with open(os.path.join("certs", "client.crt"), "rb") as f:
                    client_cert = f.read()
                with open(os.path.join("certs", "client.key"), "rb") as f:
                    client_key = f.read()
                with open(os.path.join("certs", "ca.crt"), "rb") as f:
                    ca_cert = f.read()
                creds = grpc.ssl_channel_credentials(
                    root_certificates=ca_cert,
                    private_key=client_key,
                    certificate_chain=client_cert
                )
                channel = grpc.secure_channel(server_addr, creds)
            else:
                raise Exception("不明な認証方式")
            stub = decibel_logger_pb2_grpc.DecibelLoggerStub(channel)
            req = decibel_logger_pb2.DecibelLogRequest(
                access_token=token,
                start_datetime=start_dt,
                end_datetime=end_dt
            )
            resp = stub.GetDecibelLog(req)
            for log in resp.logs:
                self.result_list.addItem(f"{log.datetime}: {log.decibel:.2f} dB")
                self.decibel_data.append((log.datetime, log.decibel))
        except Exception as e:
            QtWidgets.QMessageBox.critical(self, 'エラー', str(e))

    def show_graph(self):
        if not self.decibel_data:
            QtWidgets.QMessageBox.information(self, '情報', 'データがありません')
            return
        self.figure.clear()
        ax = self.figure.add_subplot(111)
        times = [datetime.datetime.strptime(dt, '%Y%m%d %H:%M:%S') for dt, _ in self.decibel_data]
        decibels = [db for _, db in self.decibel_data]
        max_points = 1000
        if len(times) > max_points:
            step = len(times) // max_points
            times = times[::step]
            decibels = decibels[::step]
        line, = ax.plot(times, decibels, color='tab:blue', alpha=0.7, linewidth=1.2)
        ax.set_xlabel('日時')
        ax.set_ylabel('デシベル')
        ax.set_title('デシベル推移')
        self.figure.autofmt_xdate()
        # y軸（デシベル値）は常に全体表示
        if decibels:
            ax.set_ylim(min(decibels) - 2, max(decibels) + 2)
        # x軸は最初100点だけ表示、スクロールで移動
        if len(times) > 100:
            ax.set_xlim(times[0], times[99])
            self.h_scroll.setMaximum(99)
            self.h_scroll.setEnabled(True)
        else:
            if times:
                ax.set_xlim(times[0], times[-1])
            self.h_scroll.setEnabled(False)
        self.canvas.draw()

if __name__ == '__main__':
    app = QtWidgets.QApplication(sys.argv)
    win = DecibelClientApp()
    win.show()
    sys.exit(app.exec_())
