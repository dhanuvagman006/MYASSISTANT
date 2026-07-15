package com.myassistant.app.ui.calls

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Call
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.myassistant.app.ui.theme.Marigold
import com.myassistant.app.ui.theme.Peacock
import com.myassistant.app.ui.theme.PeacockDeep

/**
 * Screen 05 — AI Phone Calling (G1–G3), Phase 2.
 * Call preview with the approval surface: goal, script, disclosure,
 * and calling rules — nothing dials without the user's tap.
 */
@Composable
fun CallsScreen() {
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp), contentPadding = PaddingValues(vertical = 12.dp)) {
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Call preview", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                Surface(color = Marigold.copy(alpha = 0.2f), shape = MaterialTheme.shapes.small) {
                    Text("NEEDS APPROVAL", Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Callee card
        item {
            Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Peacock.copy(alpha = 0.08f))) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Surface(shape = CircleShape, color = Peacock, modifier = Modifier.size(44.dp)) {
                        Box(contentAlignment = Alignment.Center) {
                            Text("VR", color = MaterialTheme.colorScheme.onPrimary, fontWeight = FontWeight.Bold)
                        }
                    }
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text("Villa Maya Restaurant", fontWeight = FontWeight.Bold)
                        Text("+91 471 24x xxxx · open now", style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Goal + script (G2: nothing is hidden)
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("GOAL", style = MaterialTheme.typography.labelSmall, color = Peacock, fontWeight = FontWeight.Bold)
                    Text("Book a table for 4 · Saturday 8:00 PM", fontWeight = FontWeight.Bold)
                    Text("Fallback: 7:30 PM or Sunday 8:00 PM", style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                    Spacer(Modifier.height(12.dp))
                    Text("WHAT I'LL SAY", style = MaterialTheme.typography.labelSmall, color = Peacock, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(4.dp))
                    Surface(shape = MaterialTheme.shapes.medium, color = Peacock.copy(alpha = 0.06f)) {
                        Text(
                            "\u201CNamaskaram! I'm an AI assistant calling on behalf of Arjun. I'd like to book a table for four this Saturday at 8 PM…\u201D",
                            Modifier.padding(12.dp), style = MaterialTheme.typography.bodyMedium
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        TagChip("SPEAKS MALAYALAM"); TagChip("DISCLOSES AI IDENTITY")
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Calling rules (G2)
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Your calling rules", fontWeight = FontWeight.Bold)
                        Text("Edit", color = Peacock, fontWeight = FontWeight.Medium)
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        RulePill("2 OF 3 CALLS LEFT TODAY"); RulePill("9 AM – 8 PM"); RulePill("BOOKINGS ✓")
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }

        // Actions
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(onClick = {}, Modifier.weight(1f).height(50.dp)) { Text("Edit script") }
                Button(
                    onClick = { /* telephony wires in Phase 2 Month 6 */ },
                    Modifier.weight(1.4f).height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = PeacockDeep)
                ) {
                    Icon(Icons.Default.Call, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text("Approve & call")
                }
            }
        }
    }
}

@Composable
private fun TagChip(label: String) {
    Surface(color = Peacock.copy(alpha = 0.12f), shape = MaterialTheme.shapes.small) {
        Text(label, Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall, color = PeacockDeep, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun RulePill(label: String) {
    Surface(color = MaterialTheme.colorScheme.background, shape = MaterialTheme.shapes.small) {
        Text(label, Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
            style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Medium)
    }
}
