package com.fredysomy.money_management

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode

class QuickAddActivity : FlutterActivity() {

    override fun getDartEntrypointFunctionName(): String = "quickAddMain"

    // TextureView supports transparent backgrounds (SurfaceView does not)
    override fun getRenderMode(): RenderMode = RenderMode.texture
    override fun getTransparencyMode(): TransparencyMode = TransparencyMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        super.onCreate(savedInstanceState)
    }
}
