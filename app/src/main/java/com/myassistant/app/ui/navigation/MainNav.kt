package com.myassistant.app.ui.navigation

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Adjust
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.ChatBubbleOutline
import androidx.compose.material.icons.filled.PersonOutline
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.myassistant.app.ui.calls.CallsScreen
import com.myassistant.app.ui.chat.ChatScreen
import com.myassistant.app.ui.daily.DailyScreen
import com.myassistant.app.ui.documents.DocumentsScreen
import com.myassistant.app.ui.home.VoiceHomeScreen
import com.myassistant.app.ui.inbox.InboxScreen
import com.myassistant.app.ui.privacy.PrivacyScreen
import com.myassistant.app.ui.smarthome.SmartHomeScreen

/**
 * The 5-tab bottom bar from the design doc:
 * orb (Voice Home) · chat · sun (Today hub) · phone (Calls) · person (Privacy).
 * The Today hub hosts Daily / Inbox / Home / Docs as segments, matching how
 * screens 03, 06, 07 all highlight the sun tab in the designs.
 */
enum class Tab(val label: String, val icon: ImageVector) {
    HOME("Assistant", Icons.Default.Adjust),
    CHAT("Chat", Icons.Default.ChatBubbleOutline),
    TODAY("Today", Icons.Default.WbSunny),
    CALLS("Calls", Icons.Default.Call),
    PROFILE("You", Icons.Default.PersonOutline),
}

@Composable
fun MainNav(modifier: Modifier = Modifier) {
    var tab by rememberSaveable { mutableStateOf(Tab.HOME) }

    Column(modifier.fillMaxSize()) {
        Box(Modifier.weight(1f)) {
            when (tab) {
                Tab.HOME -> VoiceHomeScreen()
                Tab.CHAT -> ChatScreen()
                Tab.TODAY -> TodayHub()
                Tab.CALLS -> CallsScreen()
                Tab.PROFILE -> PrivacyScreen()
            }
        }
        NavigationBar {
            Tab.entries.forEach { t ->
                NavigationBarItem(
                    selected = tab == t,
                    onClick = { tab = t },
                    icon = { Icon(t.icon, t.label) },
                    label = { Text(t.label) }
                )
            }
        }
    }
}

@Composable
private fun TodayHub() {
    var segment by rememberSaveable { mutableStateOf(0) }
    val segments = listOf("Daily", "Inbox", "Home", "Docs")

    Column(Modifier.fillMaxSize()) {
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
            segments.forEachIndexed { i, label ->
                SegmentedButton(
                    selected = segment == i,
                    onClick = { segment = i },
                    shape = SegmentedButtonDefaults.itemShape(i, segments.size)
                ) { Text(label) }
            }
        }
        when (segment) {
            0 -> DailyScreen()
            1 -> InboxScreen()
            2 -> SmartHomeScreen()
            3 -> DocumentsScreen()
        }
    }
}
