import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';  
import 'package:stavia_ff/widgets/lightdarkmode.dart';
import '../widgets/navigation_drawer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          actions: [LightDarkMode(),],
          title: const Text(
            'StaVia',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 30,
            ),
          ),
          backgroundColor: Colors.black38,
        ),
        drawer: const CustomNavigationDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.center,  
              child: Lottie.asset(
                "assets/lotties/home.json",
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "StaVia",
                    style: TextStyle(
                      fontSize: 150,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -10,
                    ),
                  ),
                  Text(
                    "Uncover cellular trajectories and spatio-temporally dissect \ncomplex biological landscapes",
                    style: TextStyle(
                      fontSize: 25,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}