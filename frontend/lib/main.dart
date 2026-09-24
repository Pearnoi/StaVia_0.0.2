import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stavia_ff/data/notifiers.dart';
import 'package:provider/provider.dart';
import 'screens/homepage.dart';
import 'viewmodel/all_viewmodel.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => PipelineViewModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
            primaryColor: Colors.black,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.grey, 
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
            ).copyWith(
              primary: Colors.blue, 
              outline: Colors.grey,  
            ),
            fontFamily: GoogleFonts.montserrat().fontFamily,
          ),
          home: const HomePage(), 
        );
      }
    );
  }
}

