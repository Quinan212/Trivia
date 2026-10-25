package ar.maillet.triviaantiguedad

import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        // Controlar multimedia también entre efectos breves o con sonido apagado.
        setVolumeControlStream(AudioManager.STREAM_MUSIC)
    }
}
