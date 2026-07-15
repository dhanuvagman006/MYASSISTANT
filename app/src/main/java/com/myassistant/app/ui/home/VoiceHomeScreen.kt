package com.myassistant.app.ui.home

import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.myassistant.app.ui.theme.*

/**
 * Screen 01 — Voice Home (A1–A4, M1).
 * The bloom orb with its four states: Idle / Listening / Thinking / Speaking.
 * Voice capture wires in later; tapping the orb cycles states for now.
 */
enum class OrbState { IDLE, LISTENING, THINKING, SPEAKING }

@Composable
fun VoiceHomeScreen() {
    var orbState by remember { mutableStateOf(OrbState.IDLE) }

    Column(
        Modifier.fillMaxSize().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(12.dp))
        Text("Good morning, Arjun", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text(
            when (orbState) {
                OrbState.IDLE -> "Tap the orb or say \"Hey Assistant\""
                OrbState.LISTENING -> "I'm listening — speak in any language"
                OrbState.THINKING -> "Thinking…"
                OrbState.SPEAKING -> "Speaking — tap to interrupt"
            },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)
        )

        Spacer(Modifier.weight(1f))
        BloomOrb(orbState) {
            orbState = OrbState.entries[(orbState.ordinal + 1) % OrbState.entries.size]
        }
        Spacer(Modifier.weight(1f))

        // Live transcript card — mock of the Malayalam example from the design
        Card(
            Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Peacock.copy(alpha = 0.08f))
        ) {
            Column(Modifier.padding(16.dp)) {
                Text("HEARD · MALAYALAM", style = MaterialTheme.typography.labelSmall, color = Marigold, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(4.dp))
                Text("\u201Cഇന്ന് വൈകുന്നേരം മഴ പെയ്യുമോ?\u201D", fontWeight = FontWeight.Medium)
                Spacer(Modifier.height(4.dp))
                Text(
                    "Will it rain this evening? — Yes, light rain is likely in Thiruvananthapuram after 6 pm. Carry an umbrella…",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                )
            }
        }

        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SuggestionChip("☀️ Morning briefing")
            SuggestionChip("📞 Book a table")
            SuggestionChip("✉️ Read inbox")
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun SuggestionChip(label: String) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.3f)),
        color = MaterialTheme.colorScheme.surface
    ) {
        Text(label, Modifier.padding(horizontal = 12.dp, vertical = 10.dp), style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
fun BloomOrb(state: OrbState, onTap: () -> Unit) {
    val infinite = rememberInfiniteTransition(label = "orb")
    val pulse by infinite.animateFloat(
        initialValue = 1f, targetValue = if (state == OrbState.LISTENING || state == OrbState.SPEAKING) 1.08f else 1f,
        animationSpec = infiniteRepeatable(tween(700, easing = EaseInOut), RepeatMode.Reverse),
        label = "pulse"
    )

    Box(contentAlignment = Alignment.Center) {
        // Outer marigold rings
        Box(
            Modifier.size(230.dp).scale(pulse).clip(CircleShape)
                .border(1.dp, Marigold.copy(alpha = 0.4f), CircleShape)
        )
        Box(
            Modifier.size(190.dp).clip(CircleShape)
                .border(1.dp, Marigold.copy(alpha = 0.7f), CircleShape)
        )
        // The orb itself
        Box(
            Modifier
                .size(150.dp)
                .scale(pulse)
                .clip(CircleShape)
                .background(Brush.radialGradient(listOf(Color(0xFF1A9E96), PeacockDeep)))
                .clickable { onTap() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                if (state == OrbState.IDLE) Icons.Default.Mic else Icons.Default.GraphicEq,
                contentDescription = "Assistant",
                tint = if (state == OrbState.SPEAKING) Marigold else Color.White,
                modifier = Modifier.size(48.dp)
            )
        }
    }
}
