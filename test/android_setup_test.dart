import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android wiring that fails silently when it goes missing.
///
/// Controllers on Android only work if the activity forwards input to the
/// gamepads plugin. Without that the plugin disables itself with nothing but a
/// logcat line, touch keeps working, and nobody notices until someone plugs a
/// pad in. `flutter create` regenerates this file as a bare FlutterActivity.
void main() {
  test('MainActivity forwards controller input to the gamepads plugin', () {
    final activity = File(
      'android/app/src/main/kotlin/com/deathbyslides/death_by_slides/'
      'MainActivity.kt',
    ).readAsStringSync();

    expect(
      activity,
      contains('GamepadsCompatibleActivity'),
      reason: 'without it the plugin switches gamepad support off',
    );
    expect(activity, contains('override fun dispatchGenericMotionEvent'));
    expect(activity, contains('override fun dispatchKeyEvent'));
  });
}
