import 'package:flutter/material.dart';
import 'package:stavia_ff/data/notifiers.dart';

class LightDarkMode extends StatelessWidget {
  const LightDarkMode({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        isDarkModeNotifier.value = !isDarkModeNotifier.value; 
      },  
      icon: ValueListenableBuilder(
        valueListenable: isDarkModeNotifier, 
        builder: (context, isDarkMode, child) {
          return Icon(
            isDarkMode ? Icons.dark_mode : Icons.light_mode, 
          ); 
        },
      ),
    );
  }
}