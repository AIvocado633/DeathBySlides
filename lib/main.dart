import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

import 'game/audio/audio_backend.dart';
import 'game/death_by_slides_game.dart';
import 'game/save/save_store.dart';
import 'game/theme/palette.dart';
import 'game/theme/slide_text.dart';

const Set<TargetPlatform> _mobile = {TargetPlatform.android, TargetPlatform.iOS};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The bundled font's licence asks to travel with it.
  LicenseRegistry.addLicense(() async* {
    final licence = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks([kFontFamily], licence);
  });
  if (_mobile.contains(defaultTargetPlatform)) {
    // The game is laid out on a 16:9 slide, so it wants the screen the same way
    // round as a projector. Orientation and system UI are mobile-only concerns;
    // on desktop the window is already whatever shape the player made it.
    await Flame.device.setLandscape();
    await Flame.device.fullScreen();
  }
  runApp(const DeathBySlidesApp());
}

class DeathBySlidesApp extends StatefulWidget {
  const DeathBySlidesApp({super.key});

  @override
  State<DeathBySlidesApp> createState() => _DeathBySlidesAppState();
}

class _DeathBySlidesAppState extends State<DeathBySlidesApp> {
  /// Kept here rather than built by the `GameWidget`, so Android's back
  /// gesture can be handed to it.
  late final DeathBySlidesGame _game = DeathBySlidesGame(
    gamepadEvents: Gamepads.normalizedEvents,
    saveStore: SharedPreferencesSaveStore(),
    audioBackend: FlameAudioBackend(),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Death by Slides',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: kFontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.brand,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Palette.workspace,
      ),
      // The navigator has one route, the game, so an unhandled back gesture
      // would close the app from anywhere -- mid-fight included. Back goes to
      // the game instead, and only leaves the app from the title slide.
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_game.goBack()) {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          backgroundColor: Palette.workspace,
          body: GameWidget(game: _game),
        ),
      ),
    );
  }
}
