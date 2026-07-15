package com.myassistant.app.update

import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import com.myassistant.app.BuildConfig

/**
 * Two-layer update strategy:
 *
 * 1. SERVER FEATURES (instant, no rebuild): handled by ConfigRepository.
 *    New AI capabilities land on the backend; flags light them up here.
 *
 * 2. APP BINARY (needs a release): once the app is live on the Play Store,
 *    this uses Google's official In-App Updates API — the user taps
 *    "Update" inside the app and Play installs the new version without
 *    them visiting the store. FLEXIBLE = background download;
 *    IMMEDIATE = blocking full-screen update (for forceUpdateBelow).
 */
class UpdateManager(private val activity: Activity) {

    private val playUpdateManager = AppUpdateManagerFactory.create(activity)

    data class UpdateStatus(
        val upToDate: Boolean,
        val latestVersion: String,
        val changelog: List<String>,
        val forced: Boolean
    )

    /** Compare installed version against backend config. */
    fun checkFromConfig(config: RemoteConfig): UpdateStatus {
        val installed = BuildConfig.VERSION_CODE
        return UpdateStatus(
            upToDate = installed >= config.latestVersionCode,
            latestVersion = config.latestVersionName,
            changelog = config.changelog,
            forced = installed < config.forceUpdateBelow
        )
    }

    /** Launch the official Play Store in-app update flow. */
    fun launchPlayUpdate(forced: Boolean, requestCode: Int = 9001) {
        playUpdateManager.appUpdateInfo.addOnSuccessListener { info ->
            if (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE) {
                val type = if (forced) AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
                if (info.isUpdateTypeAllowed(type)) {
                    playUpdateManager.startUpdateFlow(
                        info, activity, AppUpdateOptions.defaultOptions(type)
                    )
                }
            }
        }
    }
}
