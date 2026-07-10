package com.mindsetforge.mindsetforge

import com.ryanheise.audioservice.AudioServiceActivity

/// Extends [AudioServiceActivity] so Future Self practice audio continues
/// when the screen locks or the app is backgrounded.
class MainActivity : AudioServiceActivity()
