package com.fatih.eventful

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Bundle
import androidx.activity.enableEdgeToEdge

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
