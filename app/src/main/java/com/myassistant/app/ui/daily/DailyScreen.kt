package com.myassistant.app.ui.daily

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NotificationsNone
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.myassistant.app.ui.theme.Marigold
import com.myassistant.app.ui.theme.Peacock

/** Screen 03 — Daily & Morning Briefing (C1, C2, D3, D4). Mock data; live data wires in later. */
@Composable
fun DailyScreen() {
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp), contentPadding = PaddingValues(vertical = 12.dp)) {
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column {
                    Text("Daily", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Text("MONDAY 13 JULY · 3 EVENTS · 2 REMINDERS", style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f))
                }
                FilledTonalButton(onClick = { /* TTS briefing later */ }) {
                    Icon(Icons.Default.PlayArrow, null, Modifier.size(18.dp)); Spacer(Modifier.width(4.dp)); Text("Play briefing")
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Weather card
        item {
            Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Marigold.copy(alpha = 0.15f))) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("⛅", style = MaterialTheme.typography.headlineMedium)
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text("29° Partly cloudy", fontWeight = FontWeight.Bold)
                        Text("Light rain after 6 pm — leave early for badminton", style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Next meeting + meeting prep (D4)
        item {
            Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Peacock.copy(alpha = 0.08f))) {
                Column(Modifier.padding(16.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("NEXT · 11:00 AM", style = MaterialTheme.typography.labelSmall, color = Peacock, fontWeight = FontWeight.Bold)
                        Text("Google Meet", style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                    }
                    Spacer(Modifier.height(4.dp))
                    Text("Design review — MYASSISTANT", fontWeight = FontWeight.Bold)
                    Text("with Priya, Suresh · 45 min", style = MaterialTheme.typography.bodySmall)
                    Spacer(Modifier.height(8.dp))
                    Surface(shape = MaterialTheme.shapes.medium, color = MaterialTheme.colorScheme.surface) {
                        Column(Modifier.padding(12.dp)) {
                            Text("MEETING PREP", style = MaterialTheme.typography.labelSmall, color = Peacock, fontWeight = FontWeight.Bold)
                            Text("Priya sent revised flows on Fri; Suresh asked about the call-preview screen. 2 emails attached →",
                                style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Reminders (C1)
        item {
            Card(Modifier.fillMaxWidth()) {
                Column {
                    ReminderRow("Pay electricity bill", "Today · ₹2,140 due", "6 PM")
                    HorizontalDivider()
                    ReminderRow("Call Amma", "Tomorrow · 8:00 AM", null)
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Headlines (C2)
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("HEADLINES FOR YOU", style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    Text("Kerala monsoon arrives early this year", fontWeight = FontWeight.Medium)
                    Spacer(Modifier.height(4.dp))
                    Text("UPI adds cross-border payments to UAE", fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                }
            }
        }
    }
}

@Composable
private fun ReminderRow(title: String, subtitle: String, badge: String?) {
    Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Default.NotificationsNone, null, tint = Peacock)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.Medium)
            Text(subtitle, style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
        }
        badge?.let {
            Surface(color = Marigold.copy(alpha = 0.2f), shape = MaterialTheme.shapes.small) {
                Text(it, Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
            }
        }
    }
}
