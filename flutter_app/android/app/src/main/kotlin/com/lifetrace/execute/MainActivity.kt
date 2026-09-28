package com.lifetrace.execute

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val UPDATE_CHANNEL = "com.lifetrace.execute/app_update"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "APK path is empty.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        result.success(installApk(path))
                    } catch (error: Exception) {
                        result.error(
                            "install_failed",
                            error.message ?: "Unable to start Android package installer.",
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(path: String): String {
        val apk = File(path)
        require(apk.exists()) { "Downloaded APK does not exist." }

        if (!hasMatchingSignature(apk)) {
            return "signature_mismatch"
        }

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            return "permission_required"
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        return "launched"
    }

    @Suppress("DEPRECATION")
    private fun hasMatchingSignature(apk: File): Boolean {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }

        val installed = packageManager.getPackageInfo(packageName, flags)
        val archive = packageManager.getPackageArchiveInfo(apk.absolutePath, flags)
            ?: return false
        if (archive.packageName != packageName) {
            return false
        }

        val installedSignatures = signatureStrings(installed)
        val archiveSignatures = signatureStrings(archive)
        return installedSignatures.isNotEmpty() &&
            installedSignatures == archiveSignatures
    }

    @Suppress("DEPRECATION")
    private fun signatureStrings(info: PackageInfo): Set<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return emptySet()
            val signatures = if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
            signatures.map { it.toCharsString() }.toSet()
        } else {
            info.signatures?.map { it.toCharsString() }?.toSet() ?: emptySet()
        }
    }
}
