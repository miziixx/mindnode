import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/audio/audio_engine_factory.dart';
import 'core/design/app_theme.dart';
import 'core/state/app_state.dart';
import 'core/state/playback_controller.dart';
import 'app_root.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final appState = AppState();
  final engine = createAudioEngine();
  final playback = PlaybackController(
    engine: engine,
    presets: appState.presets,
    records: appState.records,
    settingsRepo: appState.settingsRepo,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: playback),
      ],
      child: const MindSoundApp(),
    ),
  );
}

class MindSoundApp extends StatefulWidget {
  const MindSoundApp({super.key});

  @override
  State<MindSoundApp> createState() => _MindSoundAppState();
}

class _MindSoundAppState extends State<MindSoundApp> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '마인드사운드',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppRoot(),
      builder: (context, child) {
        // 시스템 글자 크기 확대 대응(과도 확대는 상한).
        final mq = MediaQuery.of(context);
        final scale = mq.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.4,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: scale),
          child: child!,
        );
      },
    );
  }
}
