package com.nextpital.prodoc

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge display for Android 15+ (API 35+) compatibility
        // This ensures the app displays correctly on Android 15 and later
        // For Android 15+, apps targeting SDK 35 will display edge-to-edge by default
        // This call enables backward compatibility and ensures proper behavior
        if (Build.VERSION.SDK_INT >= 35) { // Android 15 (API 35)
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
        super.onCreate(savedInstanceState)
    }
}
