package com.myassistant.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.SystemUpdate
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.myassistant.app.data.ChatMessage
import com.myassistant.app.ui.chat.ChatViewModel
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

        setContent {
            MyAssistantTheme {
                var config by remember { mutableStateOf(RemoteConfig()) }
                LaunchedEffect(Unit) { config = ConfigRepository.refresh() }
                AppScaffold(config, updateManager)
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
            ChatScreen(Modifier.weight(1f))
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

@Composable
fun ChatScreen(modifier: Modifier = Modifier, vm: ChatViewModel = viewModel()) {
    var input by remember { mutableStateOf("") }

    Column(modifier.fillMaxSize()) {
        LazyColumn(Modifier.weight(1f).padding(horizontal = 12.dp), reverseLayout = false) {
            items(vm.messages) { msg -> MessageBubble(msg) }
            if (vm.isThinking.value) item { Text("Thinking…", Modifier.padding(8.dp)) }
            vm.error.value?.let { item { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(8.dp)) } }
        }
        Row(
            Modifier.fillMaxWidth().padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = input,
                onValueChange = { input = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("Ask anything…") },
                shape = RoundedCornerShape(24.dp)
            )
            Spacer(Modifier.width(8.dp))
            FilledIconButton(onClick = { vm.send(input); input = "" }) {
                Icon(Icons.AutoMirrored.Filled.Send, "Send")
            }
        }
    }
}

@Composable
fun MessageBubble(msg: ChatMessage) {
    val isUser = msg.role == "user"
    Row(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        Surface(
            color = if (isUser) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface,
            contentColor = if (isUser) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
            shape = RoundedCornerShape(16.dp),
            tonalElevation = 1.dp
        ) {
            Text(msg.content, Modifier.padding(12.dp).widthIn(max = 300.dp))
        }
    }
}
