import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const InstantsApp());
}

class InstantsApp extends StatelessWidget {
  const InstantsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instants',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
        ),
      ),
      home: const CameraScreen(),
    );
  }
}
