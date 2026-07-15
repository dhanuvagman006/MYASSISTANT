package com.myassistant.app.ui.chat

import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.myassistant.app.data.ChatApi
import com.myassistant.app.data.ChatMessage
import kotlinx.coroutines.launch

class ChatViewModel : ViewModel() {
    val messages = mutableStateListOf<ChatMessage>()
    val isThinking = mutableStateOf(false)
    val error = mutableStateOf<String?>(null)

    fun send(text: String) {
        if (text.isBlank() || isThinking.value) return
        messages += ChatMessage("user", text.trim())
        isThinking.value = true
        error.value = null

        viewModelScope.launch {
            try {
                val resp = ChatApi.send(messages.toList())
                messages += ChatMessage("assistant", resp.reply)
            } catch (e: Exception) {
                error.value = "Couldn't reach the assistant. Check your connection."
            } finally {
                isThinking.value = false
            }
        }
    }
}
