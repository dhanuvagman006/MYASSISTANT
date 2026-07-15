package com.myassistant.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Brand palette — from MYASSISTANT UI Design V1.0
val Peacock = Color(0xFF0F6B66)      // primary actions
val PeacockDeep = Color(0xFF0A4744)  // emphasis
val Marigold = Color(0xFFF6A21E)     // voice & alerts
val Ink = Color(0xFF0E1B1D)          // text, dark surfaces
val Mist = Color(0xFFF2F6F5)         // cards, surfaces

private val LightColors = lightColorScheme(
    primary = Peacock,
    onPrimary = Color.White,
    primaryContainer = PeacockDeep,
    onPrimaryContainer = Color.White,
    secondary = Marigold,
    onSecondary = Ink,
    background = Mist,
    onBackground = Ink,
    surface = Color.White,
    onSurface = Ink,
)

private val DarkColors = darkColorScheme(
    primary = Peacock,
    onPrimary = Color.White,
    secondary = Marigold,
    onSecondary = Ink,
    background = Ink,
    onBackground = Mist,
    surface = PeacockDeep,
    onSurface = Mist,
)

@Composable
fun MyAssistantTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content
    )
}
