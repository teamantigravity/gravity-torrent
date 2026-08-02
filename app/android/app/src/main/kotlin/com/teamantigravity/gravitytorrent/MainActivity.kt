package com.teamantigravity.gravitytorrent

import android.content.Context
import android.os.Bundle
import android.system.Os
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import java.io.File
import kotlin.io.copyTo
import kotlin.io.outputStream
import kotlin.io.use

fun getAssetFilePath(context: Context, assetFileName: String): String? {
    val destFile = File(context.cacheDir, assetFileName)
    if (!destFile.exists()) {
        context.assets.open(assetFileName).use { input ->
            destFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }
    }
    return destFile.absolutePath
}

class MainActivity : AudioServiceFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            getAssetFilePath(this, "cacert-2024-09-24.pem")?.let { path ->
                Os.setenv("CURL_CA_BUNDLE", path, true)
            }
        } catch (e: Exception) {
            // CA bundle asset is not bundled; libcurl will use the system store.
        }
        super.onCreate(savedInstanceState)
    }
}
