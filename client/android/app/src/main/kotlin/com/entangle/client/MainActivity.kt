package com.entangle.client

import android.util.Log
import decibelmonitor.DecibelLoggerGrpc
import decibelmonitor.DecibelMonitoringServiceOuterClass
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.grpc.ManagedChannel
import io.grpc.okhttp.OkHttpChannelBuilder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.bouncycastle.asn1.pkcs.PrivateKeyInfo
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.openssl.PEMKeyPair
import org.bouncycastle.openssl.PEMParser
import org.bouncycastle.openssl.jcajce.JcaPEMKeyConverter
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.FileReader
import java.io.InputStream
import java.util.Arrays
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Security
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManagerFactory

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "mtls_grpc"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "moveTaskToBack") {
                moveTaskToBack(true)
                result.success(null)
                return@setMethodCallHandler
            }
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    // 型安全なキャストを実行
                    val args = call.arguments
                    val params =
                        if (args is Map<*, *>) {
                            @Suppress("UNCHECKED_CAST")
                            args as Map<String, Any>
                        } else {
                            emptyMap()
                        }
                    val response = handleGrpcRequest(call.method, params)
                    withContext(Dispatchers.Main) { result.success(response) }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) { result.error("GRPC_ERROR", e.message, null) }
                }
            }
        }
    }

    private suspend fun handleGrpcRequest(
        method: String,
        params: Map<String, Any>,
    ): String {
        Log.d("mtls_grpc", "handleGrpcRequest called: method=$method, params=$params")
        val caFile = extractAssetToFile("flutter_assets/assets/certs/ca.crt")
        val certFile = extractAssetToFile("flutter_assets/assets/certs/client.crt")
        val keyFile = extractAssetToFile("flutter_assets/assets/certs/client.key")
        val host = params["host"] as? String ?: "10.0.2.2"
        val port =
            when (val p = params["port"]) {
                is Int -> p
                is String -> p.toIntOrNull() ?: 50051
                else -> 50051
            }
        val timeoutMillis =
            when (val t = params["timeoutMillis"]) {
                is Long -> t
                is Int -> t.toLong()
                is String -> t.toLongOrNull() ?: 10000L
                else -> 10000L
            }
        Log.d("mtls_grpc", "host=$host, port=$port")
        val channel = createMtlsChannel(host, port, caFile, certFile, keyFile)
        try {
            val result =
                withTimeout(timeoutMillis) {
                    when (method) {
                        "getDecibelLog" -> {
                            val stub = DecibelLoggerGrpc.newFutureStub(channel)
                            val useGps = when (val u = params["useGps"]) {
                                is Boolean -> u
                                is String -> u.toBooleanStrictOrNull() ?: false
                                is Int -> u != 0
                                else -> false
                            }
                            val req =
                                DecibelMonitoringServiceOuterClass.DecibelLogRequest.newBuilder()
                                    .setAccessToken(params["accessToken"] as? String ?: "")
                                    .setStartDatetime(params["startDatetime"] as? String ?: "")
                                    .setEndDatetime(params["endDatetime"] as? String ?: "")
                                    .setUseGps(useGps)
                                    .build()
                            val resp =
                                withContext(Dispatchers.IO) {
                                    stub.getDecibelLog(req).get(timeoutMillis.toLong(), TimeUnit.MILLISECONDS)
                                }
                            val logsJson = JSONArray()
                            for (log in resp.logsList) {
                                val logObj = JSONObject()
                                logObj.put("datetime", log.datetime)
                                logObj.put("decibel", log.decibel)
                                logObj.put("latitude", log.latitude)
                                logObj.put("longitude", log.longitude)
                                logsJson.put(logObj)
                            }
                            JSONObject().put("logs", logsJson).toString()
                        }
                        else -> {
                            JSONObject().apply {
                                put("error", "Unknown method: $method")
                            }.toString()
                        }
                    }
                }
            return result
        } catch (e: Exception) {
            return JSONObject().apply {
                val isTimeout =
                    e is kotlinx.coroutines.TimeoutCancellationException ||
                        (e.cause?.javaClass?.simpleName?.contains("TimeoutException") == true) ||
                        (e.javaClass.simpleName.contains("TimeoutException"))
                put(
                    "error",
                    if (isTimeout) {
                        "サーバーへの接続がタイムアウトしました。ネットワーク環境やサーバー設定をご確認ください。"
                    } else {
                        "サーバーとの通信中にエラーが発生しました: ${e.message ?: "不明なエラー"}"
                    },
                )
            }.toString()
        } finally {
            channel.shutdown()
            caFile.delete()
            certFile.delete()
            keyFile.delete()
        }
    }

    private fun extractAssetToFile(assetName: String): File {
        try {
            val inputStream: InputStream = assets.open(assetName)
            val file = File.createTempFile(assetName.replace("/", "_"), null, cacheDir)
            inputStream.use { input ->
                FileOutputStream(file).use { output ->
                    input.copyTo(output)
                }
            }
            return file
        } catch (e: Exception) {
            throw RuntimeException("証明書/鍵ファイルの読み込みに失敗しました: $assetName", e)
        }
    }

    private fun createMtlsChannel(
        host: String,
        port: Int,
        caFile: File,
        certFile: File,
        keyFile: File,
    ): ManagedChannel {
        try {
            Log.d("mtls_grpc", "秘密鍵の読み込みを開始します")
            
            // Android Pからの暗号化API変更に対応するため、BouncyCastleプロバイダは解析のみに使用
            // RSA関連の操作はAndroidのデフォルトプロバイダを使用
            if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
                // プロバイダの優先度を低く設定して登録（競合を避けるため）
                Security.addProvider(BouncyCastleProvider())
                Log.d("mtls_grpc", "BouncyCastleプロバイダを登録しました")
            } else {
                Log.d("mtls_grpc", "BouncyCastleプロバイダは既に登録されています")
            }

            val cf = CertificateFactory.getInstance("X.509")
            val caInput = caFile.inputStream()
            val caCert = caInput.use { cf.generateCertificate(it) as X509Certificate }
            Log.d("mtls_grpc", "CA証明書を読み込みました: ${caCert.subjectX500Principal.name}")
            
            val certInput = certFile.inputStream()
            val clientCert = certInput.use { cf.generateCertificate(it) as X509Certificate }
            Log.d("mtls_grpc", "クライアント証明書を読み込みました: ${clientCert.subjectX500Principal.name}")

            if (!keyFile.exists() || !keyFile.canRead()) {
                Log.e("mtls_grpc", "秘密鍵ファイルが存在しないか読み取れません")
            } else {
                Log.d("mtls_grpc", "秘密鍵ファイルの読み取り準備完了: ${keyFile.absolutePath}")
            }

            // BouncyCastleを使用して秘密鍵を安全に解析
            try {
                val pemParser = PEMParser(FileReader(keyFile))
                val pemObject = pemParser.readObject()
                
                if (pemObject == null) {
                    Log.e("mtls_grpc", "PEM解析結果がnullです")
                    throw IllegalArgumentException("秘密鍵の解析に失敗しました: PEM形式が無効です")
                }
                
                Log.d("mtls_grpc", "PEMオブジェクトの解析に成功しました: ${pemObject.javaClass.simpleName}")
                // Android Pからの変更に対応するため、明示的にプロバイダを指定しない
                val converter = JcaPEMKeyConverter()

                // PEM形式に応じた適切な処理
                val privateKey: PrivateKey =
                    when (pemObject) {
                        is PEMKeyPair -> {
                            Log.d("mtls_grpc", "PEMKeyPairを検出しました")
                            converter.getKeyPair(pemObject).private
                        }
                        is PrivateKeyInfo -> {
                            Log.d("mtls_grpc", "PrivateKeyInfoを検出しました")
                            converter.getPrivateKey(pemObject)
                        }
                        else -> {
                            Log.e("mtls_grpc", "未対応の秘密鍵形式です: ${pemObject.javaClass.simpleName}")
                            throw IllegalArgumentException("サポートされていない秘密鍵形式です: ${pemObject.javaClass.simpleName}")
                        }
                    }
                val generatedKey = privateKey
                Log.d("mtls_grpc", "BouncyCastle方式で秘密鍵の生成に成功しました: ${generatedKey.algorithm}")
                // 秘密鍵が正常に生成された場合
                return createMtlsChannelWithKey(host, port, caCert, clientCert, generatedKey)
            } catch (e: Exception) {
                // Android Pからの暗号化API変更に関連するエラーの場合
                if (e.message?.contains("The BC provider no longer provides") == true || 
                    e.cause?.message?.contains("The BC provider no longer provides") == true) {
                    Log.w("mtls_grpc", "BouncyCastleによるRSA鍵の処理はAndroid Pで非推奨になりました。従来の方法にフォールバックします。")
                } else {
                    Log.e("mtls_grpc", "秘密鍵のパースに失敗しました", e)
                }
                
                // 標準Javaの方法でセキュアに秘密鍵を解析
                try {
                    Log.d("mtls_grpc", "標準Javaの方法でセキュアに秘密鍵を解析します")
                    // ストリームから直接読み込み、メモリ上のプレーンテキストを最小限にする
                    keyFile.inputStream().use { inputStream ->
                        try {
                            // Base64デコードした結果を直接バイト配列に
                            val bytes = inputStream.readBytes()
                            val content = String(bytes, Charsets.US_ASCII)
                            
                            // ヘッダーとフッターを取り除き、改行や空白を削除
                            val base64Data = content
                                .replace("-----BEGIN PRIVATE KEY-----", "")
                                .replace("-----END PRIVATE KEY-----", "")
                                .replace("\\s".toRegex(), "")
                            
                            // Base64デコードしてキー仕様に変換
                            val decoder = java.util.Base64.getDecoder()
                            val keyBytes = decoder.decode(base64Data)
                            val keySpec = java.security.spec.PKCS8EncodedKeySpec(keyBytes)
                            
                            // Android標準のプロバイダを使用
                            val keyFactory = java.security.KeyFactory.getInstance("RSA")
                            val fallbackKey: PrivateKey = keyFactory.generatePrivate(keySpec)
                            
                            // 使用したデータを明示的にnullに設定して、GCに回収を促す
                            // これによりメモリに残る秘密鍵データの量と時間を最小化
                            Arrays.fill(keyBytes, 0.toByte())
                            
                            Log.d("mtls_grpc", "標準Java方式で秘密鍵の生成に成功しました: ${fallbackKey.algorithm}")
                            return createMtlsChannelWithKey(host, port, caCert, clientCert, fallbackKey)
                        } catch (decodeEx: Exception) {
                            Log.e("mtls_grpc", "秘密鍵のデコードに失敗しました", decodeEx)
                            throw decodeEx
                        }
                    }
                } catch (fallbackEx: Exception) {
                    Log.e("mtls_grpc", "標準Java方式での秘密鍵処理に失敗しました", fallbackEx)
                    throw RuntimeException("秘密鍵の解析に失敗しました", e)
                }
            }

        } catch (e: Exception) {
            Log.e("mtls_grpc", "mTLSチャンネルの作成に失敗しました", e)
            throw RuntimeException("証明書・秘密鍵の生成に失敗しました", e)
        }
    }
    
    // 鍵と証明書からgRPCチャンネルを作成するヘルパーメソッド
    private fun createMtlsChannelWithKey(
        host: String,
        port: Int,
        caCert: X509Certificate,
        clientCert: X509Certificate,
        privateKey: PrivateKey
    ): ManagedChannel {
        try {
            val keyStore = KeyStore.getInstance(KeyStore.getDefaultType())
            keyStore.load(null, null)
            keyStore.setCertificateEntry("caCert", caCert)
            keyStore.setCertificateEntry("clientCert", clientCert)
            keyStore.setKeyEntry("privateKey", privateKey, null, arrayOf(clientCert))
            
            val tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
            tmf.init(keyStore)
            val kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm())
            kmf.init(keyStore, null)
            
            val sslContext = SSLContext.getInstance("TLS")
            sslContext.init(kmf.keyManagers, tmf.trustManagers, null)
            
            Log.d("mtls_grpc", "SSLコンテキストの初期化に成功しました")
            
            return OkHttpChannelBuilder.forAddress(host, port)
                .sslSocketFactory(sslContext.socketFactory)
                .build()
        } catch (e: Exception) {
            Log.e("mtls_grpc", "キーストア設定中にエラーが発生しました", e)
            throw RuntimeException("SSLコンテキストの初期化に失敗しました", e)
        }
    }
}
