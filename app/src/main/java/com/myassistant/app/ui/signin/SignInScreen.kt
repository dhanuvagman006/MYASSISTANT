package com.myassistant.app.ui.signin

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.myassistant.app.auth.AuthManager
import com.myassistant.app.ui.theme.Marigold
import com.myassistant.app.ui.theme.Peacock
import com.myassistant.app.ui.theme.PeacockDeep
import kotlinx.coroutines.launch

@Composable
fun SignInScreen(authManager: AuthManager, onSignedIn: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    Column(
        Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Bloom orb placeholder — the brand mark from the design doc
        Box(
            Modifier
                .size(140.dp)
                .clip(CircleShape)
                .background(Brush.radialGradient(listOf(Peacock, PeacockDeep))),
        )
        Spacer(Modifier.height(32.dp))
        Text("MyAssistant", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(
            "Your personal assistant — in every language",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f)
        )
        Spacer(Modifier.height(48.dp))

        Button(
            onClick = {
                busy = true; error = null
                scope.launch {
                    try {
                        authManager.signIn(context)
                        onSignedIn()
                    } catch (e: Exception) {
                        error = "Sign-in didn't complete. Please try again."
                    } finally {
                        busy = false
                    }
                }
            },
            enabled = !busy,
            modifier = Modifier.fillMaxWidth().height(52.dp)
        ) {
            if (busy) CircularProgressIndicator(Modifier.size(20.dp), color = Marigold, strokeWidth = 2.dp)
            else Text("Continue with Google")
        }

        error?.let {
            Spacer(Modifier.height(16.dp))
            Text(it, color = MaterialTheme.colorScheme.error)
        }
    }
}
