package com.fredysomy.money_management

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class QuickAddActivity : FlutterActivity() {

    override fun getDartEntrypointFunctionName(): String = "quickAddMain"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Make the window transparent before Flutter renders
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        super.onCreate(savedInstanceState)
    }
}
