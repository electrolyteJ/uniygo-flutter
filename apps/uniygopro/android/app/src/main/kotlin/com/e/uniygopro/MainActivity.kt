package com.e.uniygopro

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 横屏时刘海/挖孔位于左右短边。系统默认模式会给挖孔让位，
        // 在那一侧留一条黑边；这里显式允许窗口铺进挖孔区。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val attrs = window.attributes
            attrs.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            window.attributes = attrs
        }

        // 让内容延伸到系统栏区域（配合 Dart 侧的 immersiveSticky 一起用）。
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
