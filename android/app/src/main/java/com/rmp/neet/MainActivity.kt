package com.rmp.neet

import Counter
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import uniffi.neet.RmpModel

class MainActivity : ComponentActivity() {
    companion object {
        private const val TAG = "MainActivity"
        
        // Load the Rust library
        init {
            System.loadLibrary("neet")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Create RmpModel to access Rust functions
        val model = RmpModel(filesDir.absolutePath)
        
        // Setup logging
        model.setupLogging()
        
        // List audio devices
        val devices = model.listAudioDevices()
        Log.i(TAG, "Audio devices: $devices")
        
        setContent {
            App()
        }
    }
}

@Composable
fun App() {
    val context = LocalContext.current
    val viewModel = ViewModel(context)
    Counter(viewModel)
}

