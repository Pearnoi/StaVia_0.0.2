import 'package:flutter/material.dart';
import 'package:stavia_ff/widgets/lightdarkmode.dart';
import 'package:stavia_ff/widgets/navigation_drawer.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomNavigationDrawer(),
      appBar: AppBar(
        title: const Text('About Us'),
        backgroundColor: Colors.black38,
        actions: [LightDarkMode()],
      ),
      body: const Center(
        child: Text('Welcome to About Page'),
      ),
    );
  }
}