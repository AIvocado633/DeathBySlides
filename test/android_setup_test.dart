import 'dart:io';

import 'package:death_by_slides/game/theme/palette.dart';
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

  group('release builds (docs/releasing.md)', () {
    test(
      'are signed with the upload key whenever key.properties names one',
      () {
        final gradle = File('android/app/build.gradle.kts').readAsStringSync();
        expect(gradle, contains('rootProject.file("key.properties")'));
        expect(
          gradle,
          contains(
            'signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")',
          ),
          reason: 'a release signed with the debug key is refused by Play',
        );
      },
    );

    test('are numbered 0.x until the release', () {
      final version = RegExp(
        r'^version: (\S+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())![1]!;
      expect(version, startsWith('0.'));
    });

    test('ask for no network access, as the privacy policy says', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, isNot(contains('android.permission.INTERNET')));
    });

    test('start on the workspace grey rather than flashing white', () {
      final hex = Palette.workspace.toARGB32().toRadixString(16).toUpperCase();
      expect(
        File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        contains('<color name="workspace">#$hex</color>'),
      );
      for (final drawable in ['drawable', 'drawable-v21']) {
        expect(
          File(
            'android/app/src/main/res/$drawable/launch_background.xml',
          ).readAsStringSync(),
          contains('@color/workspace'),
          reason: drawable,
        );
      }
      for (final values in ['values', 'values-night']) {
        expect(
          File(
            'android/app/src/main/res/$values/styles.xml',
          ).readAsStringSync(),
          isNot(contains('?android:colorBackground')),
          reason: '$values: the window behind the game would be white or black',
        );
      }
    });

    test(
      'have an adaptive launcher icon, with a foreground for every density',
      () {
        expect(
          File(
            'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
          ).readAsStringSync(),
          contains('@mipmap/ic_launcher_foreground'),
        );
        for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
          expect(
            File(
              'android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png',
            ).existsSync(),
            isTrue,
            reason: density,
          );
        }
      },
    );
  });
}
