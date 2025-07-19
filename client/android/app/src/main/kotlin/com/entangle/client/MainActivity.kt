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
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.security.KeyFactory
import java.security.KeyStore
import java.security.PrivateKey
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.security.spec.PKCS8EncodedKeySpec
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
                    val response = handleGrpcRequest(call.method, call.arguments as? Map<String, Any> ?: emptyMap())
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
            val result = withTimeout(timeoutMillis) {
                when (method) {
                    "getDecibelLog" -> {
                        val stub = DecibelLoggerGrpc.newFutureStub(channel)
                        val req =
                            DecibelMonitoringServiceOuterClass.DecibelLogRequest.newBuilder()
                                .setAccessToken(params["accessToken"] as? String ?: "")
                                .setStartDatetime(params["startDatetime"] as? String ?: "")
                                .setEndDatetime(params["endDatetime"] as? String ?: "")
                                .build()
                        val resp = withContext(Dispatchers.IO) {
                            stub.getDecibelLog(req).get(timeoutMillis.toLong(), TimeUnit.MILLISECONDS)
                        }
                        val logsJson = JSONArray()
                        for (log in resp.logsList) {
                            val logObj = JSONObject()
                            logObj.put("datetime", log.datetime)
                            logObj.put("decibel", log.decibel)
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
                put("error", if (isTimeout) {
                    "サーバーへの接続がタイムアウトしました。ネットワーク環境やサーバー設定をご確認ください。"
                } else {
                    "サーバーとの通信中にエラーが発生しました: ${e.message ?: "不明なエラー"}"
                })
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
            val cf = CertificateFactory.getInstance("X.509")
            val caInput = caFile.inputStream()
            val caCert = caInput.use { cf.generateCertificate(it) as X509Certificate }
            val certInput = certFile.inputStream()
            val clientCert = certInput.use { cf.generateCertificate(it) as X509Certificate }
            val pem = keyFile.readText(Charsets.US_ASCII)
            val privateKeyPem =
                pem.replace(
                    "-----BEGIN PRIVATE KEY-----",
                    "",
                ).replace("-----END PRIVATE KEY-----", "").replace("\\s".toRegex(), "")
            val keyBytes = java.util.Base64.getDecoder().decode(privateKeyPem)
            val keySpec = PKCS8EncodedKeySpec(keyBytes)
            val keyFactory = KeyFactory.getInstance("RSA")
            val privateKey: PrivateKey = keyFactory.generatePrivate(keySpec)
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
            return OkHttpChannelBuilder.forAddress(host, port)
                .sslSocketFactory(sslContext.socketFactory)
                .build()
        } catch (e: Exception) {
            throw RuntimeException("証明書・秘密鍵の生成に失敗しました", e)
        }
    }
}
