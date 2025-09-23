import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Naya import
import 'screens/student_list_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- YAHAN SE THEME KA CODE UPDATE HUA HAI ---
    final seedColor = Colors.deepPurple; // Aap yeh color badal sakte hain

    return MaterialApp(
      title: 'Attendance App',
      // Theming
      theme: ThemeData(
        useMaterial3: true, // Material 3 On
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true, // Material 3 On
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
      ),
      themeMode: ThemeMode.system, // Phone ki setting ke hisaab se theme badlega
      // --- THEME KA CODE YAHAN TAK UPDATE HUA HAI ---

      home: const StudentListScreen(),
    );
  }
}

