package com.myassistant.app.ui.privacy

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.myassistant.app.ui.theme.Peacock

/** Screen 08 — Privacy, Memory & Safety (E1–E3, F1–F3). "Trust is a feature." */
data class Memory(val fact: String, val meta: String)
data class Service(val emoji: String, val name: String, var connected: Boolean)

@Composable
fun PrivacyScreen() {
    var appLock by remember { mutableStateOf(true) }
    val memories = remember {
        mutableStateListOf(
            Memory("Prefers vegetarian restaurants", "learnt 2 May · used for bookings"),
            Memory("Wife's birthday — 4 September", "learnt 11 Jun · reminder set"),
            Memory("Replies in Malayalam with family", "learnt 20 Jun"),
        )
    }
    val services = remember {
        mutableStateListOf(
            Service("✉️", "Gmail", true),
            Service("📅", "Google Calendar", true),
            Service("🏠", "Google Home", false),
        )
    }

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp), contentPadding = PaddingValues(vertical = 12.dp)) {
        item {
            Text("Privacy & memory", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(12.dp))
        }

        // App lock (F1)
        item {
            Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Peacock.copy(alpha = 0.08f))) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Lock, null, tint = Peacock)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text("App lock is ${if (appLock) "on" else "off"}", fontWeight = FontWeight.Bold)
                        Text("Fingerprint required to open", style = MaterialTheme.typography.bodySmall)
                    }
                    Switch(checked = appLock, onCheckedChange = { appLock = it })
                }
            }
            Spacer(Modifier.height(16.dp))
        }

        // Memory manager (E3)
        item {
            Text("WHAT I REMEMBER · ${memories.size} ITEMS", style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f), fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
        }
        items(memories.size) { i ->
            val m = memories[i]
            Card(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                Row(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(m.fact, fontWeight = FontWeight.Medium)
                        Text(m.meta, style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                    }
                    IconButton(onClick = { memories.removeAt(i) }) {
                        Icon(Icons.Default.DeleteOutline, "Delete memory", tint = Color(0xFFC62828))
                    }
                }
            }
        }

        // Connected services (F2)
        item {
            Spacer(Modifier.height(8.dp))
            Text("CONNECTED SERVICES", style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f), fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Card(Modifier.fillMaxWidth()) {
                Column {
                    services.forEachIndexed { i, s ->
                        Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(s.emoji); Spacer(Modifier.width(12.dp))
                            Text(s.name, Modifier.weight(1f), fontWeight = FontWeight.Medium)
                            Switch(checked = s.connected, onCheckedChange = { services[i] = s.copy(connected = it) })
                        }
                        if (i < services.lastIndex) HorizontalDivider()
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }

        // Export & erase (F2)
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(onClick = {}, Modifier.weight(1f)) { Text("Export my data") }
                OutlinedButton(
                    onClick = {},
                    Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFC62828))
                ) { Text("Erase everything") }
            }
        }
    }
}
