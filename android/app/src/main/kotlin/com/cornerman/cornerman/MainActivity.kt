package com.cornerman.cornerman

import com.ryanheise.audioservice.AudioServiceActivity

// Extends AudioServiceActivity (not FlutterActivity) so the UI reuses the
// same Flutter engine audio_service keeps alive in its foreground service,
// instead of spinning up a second isolate.
class MainActivity : AudioServiceActivity()
