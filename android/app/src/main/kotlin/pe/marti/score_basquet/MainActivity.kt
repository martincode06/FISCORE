package pe.marti.score_basquet

import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var sounds: SoundPool? = null
    private var buzzerSound = 0
    private var possessionSound = 0
    private val loadedSounds = mutableSetOf<Int>()
    private var soundReady = false
    private var soundFailed = false
    private var activeStream = 0
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPossession = false

    private fun prepareBuzzer() {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val pool = SoundPool.Builder().setMaxStreams(1).setAudioAttributes(attributes).build()
        sounds = pool
        pool.setOnLoadCompleteListener { _, sample, status ->
            if (sample != buzzerSound && sample != possessionSound) return@setOnLoadCompleteListener
            if (status != 0) {
                soundFailed = true
                Log.e("ScoreAudio", "No se pudo cargar la chicharra: $status")
                pendingResult?.error("AUDIO", "No se pudo cargar la chicharra", null)
                pendingResult = null
                return@setOnLoadCompleteListener
            }
            loadedSounds.add(sample)
            soundReady = loadedSounds.contains(buzzerSound) && loadedSounds.contains(possessionSound)
            if (soundReady && !soundFailed) {
                Log.i("ScoreAudio", "Chicharras NBA Horn SFX cargadas")
                val waiting = pendingResult
                pendingResult = null
                if (waiting != null) playBuzzer(pendingPossession, waiting)
            }
        }
        buzzerSound = pool.load(this, R.raw.chicharra_cancha, 1)
        possessionSound = pool.load(this, R.raw.chicharra_posesion, 1)
        soundFailed = buzzerSound == 0 || possessionSound == 0
    }

    private fun playBuzzer(possession: Boolean, result: MethodChannel.Result) {
        val pool = sounds
        if (pool == null || soundFailed) {
            result.error("AUDIO", "Chicharra no disponible", null)
            return
        }
        if (!soundReady) {
            // Keep only the latest cue while the local sample is loading.
            pendingResult?.success(null)
            pendingResult = result
            pendingPossession = possession
            return
        }
        try {
            if (activeStream != 0) pool.stop(activeStream)
            val sample = if (possession) possessionSound else buzzerSound
            val stream = pool.play(sample, 0.95f, 0.95f, 1, 0, 1.0f)
            check(stream != 0) { "No se pudo reproducir la chicharra" }
            activeStream = stream
            Log.i("ScoreAudio", if (possession) "Chicharra de posesion" else "Chicharra de periodo")
            result.success(null)
        } catch (exception: Exception) {
            result.error("AUDIO", exception.message, null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        volumeControlStream = AudioManager.STREAM_ALARM
        prepareBuzzer()
        val preferences = getSharedPreferences("score_basquet", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "pe.marti.score_basquet/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> result.success(preferences.getString("game", null))
                "loadTeams" -> result.success(preferences.getString("saved_teams", null))
                "save", "saveTeams" -> {
                    val data = call.arguments as? String
                    if (data == null) result.error("ARGUMENT", "Partido invalido", null)
                    else if (preferences.edit().putString(if (call.method == "saveTeams") "saved_teams" else "game", data).commit()) result.success(null)
                    else result.error("STORAGE", "No se pudo guardar", null)
                }
                "horn", "shotHorn" -> playBuzzer(call.method == "shotHorn", result)
                "appVersion" -> {
                    try {
                        @Suppress("DEPRECATION")
                        val info = packageManager.getPackageInfo(packageName, 0)
                        result.success(info.versionName)
                    } catch (exception: Exception) {
                        result.error("VERSION", exception.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        pendingResult = null
        sounds?.release()
        sounds = null
        super.onDestroy()
    }
}
