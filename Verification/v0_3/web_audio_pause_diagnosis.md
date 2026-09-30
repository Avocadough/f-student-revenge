# Web ambience pause diagnosis — Godot 4.7.2

Status: source-confirmed allocation mechanism; the corrected browser run must establish the runtime improvement. The failing export's manifests, import/export logs and HTML are preserved in `webqa_failed_audio/`.

`Scripts/game_audio.gd` previously assigned `stream_paused = false` on every active combat frame. The exact 4.7.2 engine forwards every setter call to the sample backend, without rejecting an unchanged state. Its getter only reads playback pause state and does not create or clone an audio buffer: [audio_stream_player_internal.cpp, lines 169–183](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/audio/audio_stream_player_internal.cpp#L169-L183).

In the Web sample backend, `pause(false)` invokes `_unpause()`, which unconditionally invokes `_restart()`. Restart creates a new source and requests its buffer; `getAudioBuffer()` duplicates the channel arrays and AudioBuffer. See [library_godot_audio.js, getAudioBuffer/_duplicateAudioBuffer, lines 119–162](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/js/libs/library_godot_audio.js#L119-L162), [pause, lines 540–546](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/js/libs/library_godot_audio.js#L540-L546), and [restart/unpause, lines 683–726](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/js/libs/library_godot_audio.js#L683-L726). The same functions were verified in the failing export's actual `index.js`.

The fix guards the setter with a comparison against the existing pause state. Ambience content, mixing, effects, renderer, models and graphics settings are unchanged. The unrelated QA console-error collection now stores at most 100 messages while retaining the total count.

Validation: Godot 4.7.2 headless audio checks 10/10 and motion checks 14/14 pass with exit code 0 and no script errors (`audio_pause_guard_test.log`, `motion_pause_guard_test.log`). Browser A/B validation remains a separate step; native tests cannot establish Web memory or frame performance.
