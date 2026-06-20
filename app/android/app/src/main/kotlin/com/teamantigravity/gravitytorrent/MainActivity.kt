package com.teamantigravity.gravitytorrent

import android.content.Context
import android.os.Bundle
import android.system.Os
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import kotlin.io.copyTo
import kotlin.io.outputStream
import kotlin.io.use

fun getAssetFilePath(context: Context, assetFileName: String): String? {
    val inputStream = context.assets.open(assetFileName)
    val tempFile = File.createTempFile("cacert", null, context.cacheDir)
    inputStream.use { input ->
        tempFile.outputStream().use { output ->
            input.copyTo(output)
        }
    }
    return tempFile.absolutePath
}

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        Os.setenv("CURL_CA_BUNDLE", getAssetFilePath(this, "cacert-2024-09-24.pem"), true)
        super.onCreate(savedInstanceState)
    }
}
