package com.myassistant.app.auth

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.myassistant.app.BuildConfig
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.authStore by preferencesDataStore("auth")

data class SignedInUser(val idToken: String, val email: String?, val name: String?, val photoUrl: String?)

/**
 * F1 — Google Sign-In via Credential Manager.
 *
 * Flow: signIn() shows Google's account picker → we receive a signed
 * ID token (a JWT) → it's stored locally and sent to the backend as
 * `Authorization: Bearer <token>` → the backend verifies it with
 * Google's public keys, so it always knows which user is calling.
 */
class AuthManager(private val context: Context) {

    private val credentialManager = CredentialManager.create(context)

    companion object {
        private val KEY_ID_TOKEN = stringPreferencesKey("id_token")
        private val KEY_EMAIL = stringPreferencesKey("email")
        private val KEY_NAME = stringPreferencesKey("name")

        /** Read by ChatApi to attach the Bearer header. */
        @Volatile var currentIdToken: String? = null
            private set
    }

    val sessionFlow: Flow<SignedInUser?> = context.authStore.data.map { p ->
        val token = p[KEY_ID_TOKEN] ?: return@map null
        currentIdToken = token
        SignedInUser(token, p[KEY_EMAIL], p[KEY_NAME], null)
    }

    suspend fun signIn(activityContext: Context): SignedInUser {
        val googleIdOption = GetGoogleIdOption.Builder()
            .setServerClientId(BuildConfig.GOOGLE_WEB_CLIENT_ID)
            .setFilterByAuthorizedAccounts(false) // show all accounts on first sign-in
            .setAutoSelectEnabled(true)
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()

        val result = credentialManager.getCredential(activityContext, request)
        val credential = result.credential

        require(
            credential is CustomCredential &&
                credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
        ) { "Unexpected credential type" }

        val googleCred = GoogleIdTokenCredential.createFrom(credential.data)
        val user = SignedInUser(
            idToken = googleCred.idToken,
            email = googleCred.id,
            name = googleCred.displayName,
            photoUrl = googleCred.profilePictureUri?.toString()
        )

        context.authStore.edit { p ->
            p[KEY_ID_TOKEN] = user.idToken
            user.email?.let { p[KEY_EMAIL] = it }
            user.name?.let { p[KEY_NAME] = it }
        }
        currentIdToken = user.idToken
        return user
    }

    suspend fun signOut() {
        context.authStore.edit { it.clear() }
        currentIdToken = null
    }
}
