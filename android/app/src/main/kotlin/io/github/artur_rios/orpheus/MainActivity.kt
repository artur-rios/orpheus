package io.github.artur_rios.orpheus

import com.ryanheise.audioservice.AudioServiceActivity

/**
 * The one activity.
 *
 * `AudioServiceActivity` rather than `FlutterActivity`: the playback service
 * outlives this activity, and its Flutter engine is the one already running
 * rather than a second one started when the owner comes back to the
 * application. Extending it is what makes those the same engine — with a plain
 * `FlutterActivity` the queue on screen and the queue playing in the
 * notification would be two different players.
 */
class MainActivity : AudioServiceActivity()
