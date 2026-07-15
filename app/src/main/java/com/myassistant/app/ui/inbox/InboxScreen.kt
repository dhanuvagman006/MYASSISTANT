package com.myassistant.app.ui.inbox

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.myassistant.app.ui.theme.Marigold
import com.myassistant.app.ui.theme.Peacock
import com.myassistant.app.ui.theme.PeacockDeep

/** Screen 06 — Inbox Summary & Smart Replies (D1, D2, H1). Gmail wiring comes with Google verification. */
@Composable
fun InboxScreen() {
    var autoRules by remember { mutableStateOf(true) }

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp), contentPadding = PaddingValues(vertical = 12.dp)) {
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Inbox digest", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                Surface(color = Peacock.copy(alpha = 0.12f), shape = MaterialTheme.shapes.small) {
                    Text("GMAIL ✓", Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = PeacockDeep)
                }
            }
            Text("14 unread → 3 need you, 6 newsletters archived on your rule.",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f))
            Spacer(Modifier.height(12.dp))
        }

        // Urgent email with draft reply (D2)
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Surface(shape = CircleShape, color = Peacock, modifier = Modifier.size(40.dp)) {
                            Box(contentAlignment = Alignment.Center) { Text("PK", color = Color.White, fontWeight = FontWeight.Bold) }
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text("Priya K. · Landlord", fontWeight = FontWeight.Bold)
                            Text("Re: Lease renewal — asks to confirm by Friday", style = MaterialTheme.typography.bodySmall)
                        }
                        Surface(color = Color(0xFFFFE5E5), shape = MaterialTheme.shapes.small) {
                            Text("URGENT", Modifier.padding(horizontal = 6.dp, vertical = 3.dp),
                                style = MaterialTheme.typography.labelSmall, color = Color(0xFFC62828), fontWeight = FontWeight.Bold)
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                    Surface(shape = MaterialTheme.shapes.medium, color = Peacock.copy(alpha = 0.08f)) {
                        Text(
                            "Draft ready: \u201CHi Priya, yes — we'd like to renew. Could we discuss the 7% increase? Free to talk Thu evening.\u201D",
                            Modifier.padding(12.dp), style = MaterialTheme.typography.bodyMedium
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = {}, Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = PeacockDeep)) {
                            Text("Approve & send")
                        }
                        OutlinedButton(onClick = {}) { Text("Edit") }
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Bill card
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Surface(shape = CircleShape, color = Marigold, modifier = Modifier.size(40.dp)) {
                            Box(contentAlignment = Alignment.Center) { Text("HD", color = Color.White, fontWeight = FontWeight.Bold) }
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text("HDFC Bank", fontWeight = FontWeight.Bold)
                            Text("Credit card statement · ₹23,410 due 19 July", style = MaterialTheme.typography.bodySmall)
                        }
                        Surface(color = Marigold.copy(alpha = 0.2f), shape = MaterialTheme.shapes.small) {
                            Text("BILL", Modifier.padding(horizontal = 6.dp, vertical = 3.dp),
                                style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        SuggestedAction("⏰ Remind on 18th"); SuggestedAction("💳 Prepare UPI")
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Auto-reply rules with master switch (H1 — the kill switch)
        item {
            Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Peacock.copy(alpha = 0.08f))) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Auto-reply rules", fontWeight = FontWeight.Bold)
                        Text("2 active · \u201CDriving → reply to family\u201D sent 1 today",
                            style = MaterialTheme.typography.bodySmall)
                        Text("View log · Master switch ${if (autoRules) "ON" else "OFF"}",
                            style = MaterialTheme.typography.labelMedium, color = Peacock, fontWeight = FontWeight.Medium)
                    }
                    Switch(checked = autoRules, onCheckedChange = { autoRules = it })
                }
            }
        }
    }
}

@Composable
private fun SuggestedAction(label: String) {
    OutlinedButton(onClick = {}, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium)
    }
}
