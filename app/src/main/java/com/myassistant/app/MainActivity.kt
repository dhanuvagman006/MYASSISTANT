package com.myassistant.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SystemUpdate
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.myassistant.app.auth.AuthManager
import com.myassistant.app.ui.signin.SignInScreen
import com.myassistant.app.ui.theme.Marigold
import com.myassistant.app.ui.theme.MyAssistantTheme
import com.myassistant.app.update.ConfigRepository
import com.myassistant.app.update.RemoteConfig
import com.myassistant.app.update.UpdateManager

class MainActivity : ComponentActivity() {

    private lateinit var updateManager: UpdateManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        updateManager = UpdateManager(this)
        val authManager = AuthManager(applicationContext)

        setContent {
            MyAssistantTheme {
                val session by authManager.sessionFlow.collectAsState(initial = null)
                var justSignedIn by remember { mutableStateOf(false) }

                // Sign-in gate disabled until F1 OAuth setup is done (AUTH_ENABLED in build.gradle.kts)
                if (BuildConfig.AUTH_ENABLED && session == null && !justSignedIn) {
                    SignInScreen(authManager) { justSignedIn = true }
                } else {
                    var config by remember { mutableStateOf(RemoteConfig()) }
                    LaunchedEffect(Unit) { config = ConfigRepository.refresh() }
                    AppScaffold(config, updateManager)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppScaffold(config: RemoteConfig, updateManager: UpdateManager) {
    var showUpdateSheet by remember { mutableStateOf(false) }
    val status = remember(config) { updateManager.checkFromConfig(config) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("MyAssistant") },
                actions = {
                    // ---- THE UPDATE BUTTON ----
                    BadgedBox(badge = {
                        if (!status.upToDate) Badge(containerColor = Marigold)
                    }) {
                        IconButton(onClick = { showUpdateSheet = true }) {
                            Icon(Icons.Default.SystemUpdate, "Updates")
                        }
                    }
                }
            )
        }
    ) { padding ->
        Column(Modifier.padding(padding)) {
            config.announcement?.let {
                // Server-pushed announcement — appears without any app release
                Card(
                    Modifier.fillMaxWidth().padding(12.dp),
                    colors = CardDefaults.cardColors(containerColor = Marigold.copy(alpha = 0.15f))
                ) { Text(it, Modifier.padding(12.dp), style = MaterialTheme.typography.bodyMedium) }
            }
            com.myassistant.app.ui.navigation.MainNav(Modifier.weight(1f))
        }

        if (showUpdateSheet) {
            ModalBottomSheet(onDismissRequest = { showUpdateSheet = false }) {
                UpdateSheet(status) { updateManager.launchPlayUpdate(status.forced) }
            }
        }
    }
}

@Composable
fun UpdateSheet(status: UpdateManager.UpdateStatus, onUpdate: () -> Unit) {
    Column(Modifier.padding(24.dp).fillMaxWidth()) {
        Text(
            if (status.upToDate) "You're up to date ✓" else "Update available",
            style = MaterialTheme.typography.headlineSmall
        )
        Spacer(Modifier.height(8.dp))
        Text("Latest version: ${status.latestVersion}")
        if (status.changelog.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            Text("What's new", style = MaterialTheme.typography.titleMedium)
            status.changelog.forEach { Text("• $it", Modifier.padding(top = 4.dp)) }
        }
        if (!status.upToDate) {
            Spacer(Modifier.height(16.dp))
            Button(onClick = onUpdate, Modifier.fillMaxWidth()) { Text("Update now") }
        }
        Spacer(Modifier.height(24.dp))
    }
}
