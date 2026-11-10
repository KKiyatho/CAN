export 'alarm_sound_stub.dart'
    if (dart.library.io) 'alarm_sound_native.dart'
    if (dart.library.js_interop) 'alarm_sound_web.dart';
