package com.myassistant.myassistant

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth requires FlutterFragmentActivity (not FlutterActivity),
// otherwise the biometric prompt throws no_fragment_activity and never shows.
class MainActivity : FlutterFragmentActivity()
