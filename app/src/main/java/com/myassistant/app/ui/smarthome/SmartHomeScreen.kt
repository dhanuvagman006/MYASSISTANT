package com.myassistant.app.ui.smarthome

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.myassistant.app.ui.theme.Marigold
import com.myassistant.app.ui.theme.Peacock
import com.myassistant.app.ui.theme.PeacockDeep

/** Screen 07 — Smart Home & Routines (I1–I3, H2, H3). Google Home/Matter wiring is Phase 2 Month 7. */
data class DeviceTile(val emoji: String, val name: String, val status: String, val on: Boolean)

@Composable
fun SmartHomeScreen() {
    val devices = remember {
        mutableStateListOf(
            DeviceTile("💡", "Hall lights", "On · 60%", true),
            DeviceTile("❄️", "Bedroom AC", "24° · Cooling", true),
            DeviceTile("🚿", "Geyser", "On · 18 min", true),
            DeviceTile("🌀", "Fan · Study", "Off", false),
        )
    }
    var scene by remember { mutableStateOf("Movie night") }

    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Spacer(Modifier.height(12.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text("Home", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Surface(color = Peacock.copy(alpha = 0.12f), shape = MaterialTheme.shapes.small) {
                Text("12 DEVICES ONLINE", Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = PeacockDeep)
            }
        }
        Spacer(Modifier.height(12.dp))

        // Plain-language status answer (I3)
        Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Peacock.copy(alpha = 0.08f))) {
            Text("🎙 \u201CIs the geyser on?\u201D — Yes, on for 18 min. Turn it off?",
                Modifier.padding(14.dp), style = MaterialTheme.typography.bodyMedium)
        }
        Spacer(Modifier.height(12.dp))

        // Scenes (I2)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("🎬 Movie night", "🌅 Good morning", "🛏 Sleep").forEach { label ->
                val selected = label.contains(scene)
                FilterChip(selected = selected, onClick = { scene = label.substringAfter(" ") },
                    label = { Text(label) },
                    colors = FilterChipDefaults.filterChipColors(selectedContainerColor = PeacockDeep,
                        selectedLabelColor = MaterialTheme.colorScheme.onPrimary))
            }
        }
        Spacer(Modifier.height(12.dp))

        // Device tiles (I1)
        LazyVerticalGrid(GridCells.Fixed(2), Modifier.weight(1f),
            horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(devices.size) { i ->
                val d = devices[i]
                Card(
                    onClick = { devices[i] = d.copy(on = !d.on, status = if (d.on) "Off" else "On") },
                    colors = CardDefaults.cardColors(
                        containerColor = if (d.on) Marigold.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surface)
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(d.emoji, style = MaterialTheme.typography.headlineSmall)
                        Spacer(Modifier.height(8.dp))
                        Text(d.name, fontWeight = FontWeight.Bold)
                        Text(d.status, style = MaterialTheme.typography.bodySmall,
                            color = if (d.on) Marigold else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                    }
                }
            }
        }

        // Routines (H2, H3)
        Card(Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
            Column(Modifier.padding(16.dp)) {
                Text("ROUTINES", style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                RoutineRow("🛒", "Friday shopping list", "Fri 6 PM · pantry notes → grocery app", "FRI")
                Spacer(Modifier.height(8.dp))
                RoutineRow("🏠", "Leaving office", "Location · navigation + message family", "ON")
            }
        }
    }
}

@Composable
private fun RoutineRow(emoji: String, title: String, subtitle: String, badge: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(emoji)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.Medium)
            Text(subtitle, style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
        }
        Surface(color = Peacock.copy(alpha = 0.12f), shape = MaterialTheme.shapes.small) {
            Text(badge, Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = PeacockDeep)
        }
    }
}
