package com.myassistant.app.ui.documents

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.myassistant.app.ui.theme.Marigold
import com.myassistant.app.ui.theme.Peacock
import com.myassistant.app.ui.theme.PeacockDeep

/** Screen 04 — Photos, Documents & Screenshots (B1–B4). Document AI wires in Month 2. */
@Composable
fun DocumentsScreen() {
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp), contentPadding = PaddingValues(vertical = 12.dp)) {
        item {
            Text("Rental_Agreement.pdf", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Badge("24 PAGES", Peacock.copy(alpha = 0.12f), PeacockDeep)
                Badge("SUMMARISED", Marigold.copy(alpha = 0.2f), PeacockDeep)
                Spacer(Modifier.weight(1f))
                OutlinedButton(onClick = {}, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)) {
                    Text("⧉ Copy as text", style = MaterialTheme.typography.labelMedium)
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Summary (B2)
        item {
            Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Peacock.copy(alpha = 0.08f))) {
                Column(Modifier.padding(16.dp)) {
                    Text("SUMMARY", style = MaterialTheme.typography.labelSmall, color = Peacock, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(4.dp))
                    Text("11-month agreement for a 2BHK in Kowdiar. Rent ₹18,500/month, due by the 5th. Deposit ₹55,500, refundable in 30 days.")
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Watch these clauses
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("WATCH THESE CLAUSES", style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    ClauseRow("§9", "Rent increases 7% on renewal — above the usual 5%.")
                    ClauseRow("§14", "Notice period is 2 months, both sides.")
                    ClauseRow("§17", "Painting charges deducted from deposit at exit.")
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Q&A exchange (B2 question-answering)
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                Surface(color = PeacockDeep, shape = MaterialTheme.shapes.large) {
                    Text("Can I terminate early without penalty?",
                        Modifier.padding(12.dp), color = MaterialTheme.colorScheme.onPrimary)
                }
            }
            Spacer(Modifier.height(8.dp))
            Surface(color = MaterialTheme.colorScheme.surface, shape = MaterialTheme.shapes.large, tonalElevation = 1.dp) {
                Text(
                    "Yes — after the 6th month with 2 months' written notice (§14). Before that, one month's rent applies as penalty (§15, page 11).",
                    Modifier.padding(12.dp)
                )
            }
        }
    }
}

@Composable
private fun Badge(label: String, bg: androidx.compose.ui.graphics.Color, fg: androidx.compose.ui.graphics.Color) {
    Surface(color = bg, shape = MaterialTheme.shapes.small) {
        Text(label, Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = fg)
    }
}

@Composable
private fun ClauseRow(section: String, text: String) {
    Row(Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.Top) {
        Surface(color = Marigold.copy(alpha = 0.2f), shape = MaterialTheme.shapes.small) {
            Text(section, Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.width(8.dp))
        Text(text, style = MaterialTheme.typography.bodyMedium)
    }
}
