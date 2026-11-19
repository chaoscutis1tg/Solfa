package vn.solfa.app.solfa

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "vn.solfa.app.solfa/app_update"
        private const val REQUEST_CODE_IMMEDIATE_UPDATE = 9421
    }

    private val appUpdateManager: AppUpdateManager by lazy {
        AppUpdateManagerFactory.create(applicationContext)
    }

    private var pendingImmediateResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkForUpdate" -> handleCheckForUpdate(result)
                    "startImmediateUpdate" -> handleStartImmediateUpdate(result)
                    "openPlayStoreListing" -> {
                        val opened = openPlayStoreForPackage()
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleCheckForUpdate(result: MethodChannel.Result) {
        try {
            appUpdateManager.appUpdateInfo
                .addOnSuccessListener { info: AppUpdateInfo ->
                    val availability = info.updateAvailability()
                    val isUpdateAvailable =
                        availability == UpdateAvailability.UPDATE_AVAILABLE ||
                            availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                    val isImmediateAllowed = info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
                    result.success(
                        mapOf(
                            "updateAvailable" to isUpdateAvailable,
                            "inProgress" to (availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS),
                            "immediateAllowed" to isImmediateAllowed,
                            "availableVersionCode" to info.availableVersionCode(),
                            "installStatus" to info.installStatus()
                        )
                    )
                }
                .addOnFailureListener { err ->
                    // Offline, sideloaded, or Play Store not logged in -> return safe false so offline study continues
                    result.success(
                        mapOf(
                            "updateAvailable" to false,
                            "inProgress" to false,
                            "immediateAllowed" to false,
                            "availableVersionCode" to 0,
                            "error" to (err.message ?: "play_store_unavailable")
                        )
                    )
                }
        } catch (e: Exception) {
            result.success(
                mapOf(
                    "updateAvailable" to false,
                    "inProgress" to false,
                    "immediateAllowed" to false,
                    "availableVersionCode" to 0,
                    "error" to (e.message ?: "unexpected_error")
                )
            )
        }
    }

    private fun handleStartImmediateUpdate(result: MethodChannel.Result) {
        if (pendingImmediateResult != null) {
            result.success("already_in_progress")
            return
        }
        try {
            appUpdateManager.appUpdateInfo
                .addOnSuccessListener { info: AppUpdateInfo ->
                    val availability = info.updateAvailability()
                    val canRunImmediate =
                        (availability == UpdateAvailability.UPDATE_AVAILABLE ||
                            availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) &&
                            info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)

                    if (!canRunImmediate || isFinishing) {
                        result.success("not_allowed")
                        return@addOnSuccessListener
                    }

                    try {
                        pendingImmediateResult = result
                        val started = appUpdateManager.startUpdateFlowForResult(
                            info,
                            this,
                            AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
                            REQUEST_CODE_IMMEDIATE_UPDATE
                        )
                        if (!started) {
                            pendingImmediateResult = null
                            result.success("failed")
                        }
                    } catch (_: Exception) {
                        pendingImmediateResult = null
                        result.success("failed")
                    }
                }
                .addOnFailureListener {
                    result.success("unavailable")
                }
        } catch (_: Exception) {
            pendingImmediateResult = null
            result.success("failed")
        }
    }

    private fun openPlayStoreForPackage(): Boolean {
        val pkg = applicationContext.packageName
        return try {
            val marketIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("market://details?id=$pkg")
            ).apply {
                setPackage("com.android.vending")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(marketIntent)
            true
        } catch (_: ActivityNotFoundException) {
            try {
                val webIntent = Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=$pkg")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(webIntent)
                true
            } catch (_: Exception) {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_IMMEDIATE_UPDATE) {
            val callback = pendingImmediateResult
            pendingImmediateResult = null
            val status = when (resultCode) {
                Activity.RESULT_OK -> "completed"
                Activity.RESULT_CANCELED -> "canceled"
                else -> "failed"
            }
            callback?.success(status)
        }
    }

    override fun onResume() {
        super.onResume()
        // Per Google Play In-App Updates guideline: if an immediate update was already started
        // and the user minimized/re-opened the app, resume the blocking Google Play update flow.
        if (pendingImmediateResult == null && !isFinishing) {
            try {
                appUpdateManager.appUpdateInfo.addOnSuccessListener { info ->
                    if (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS &&
                        info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE) &&
                        !isFinishing
                    ) {
                        try {
                            appUpdateManager.startUpdateFlowForResult(
                                info,
                                this,
                                AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
                                REQUEST_CODE_IMMEDIATE_UPDATE
                            )
                        } catch (_: Exception) {
                        }
                    }
                }
            } catch (_: Exception) {
            }
        }
    }
}
