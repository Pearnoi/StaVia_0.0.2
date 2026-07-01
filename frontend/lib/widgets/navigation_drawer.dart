import 'package:flutter/material.dart';
import 'package:stavia_ff/screens/homepage.dart';
import 'package:stavia_ff/screens/tutorial.dart';
import 'package:stavia_ff/screens/action.dart';
import 'package:stavia_ff/screens/about.dart';
import 'package:stavia_ff/screens/contact.dart';

class CustomNavigationDrawer extends StatelessWidget {
  const CustomNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Colors.black38,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(
                  context: context,
                  icon: Icons.home_outlined,
                  title: 'Home',
                  page: const HomePage(),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.book_online_rounded,
                  title: 'Tutorial',
                  page: const TutorialPage(),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.token_outlined,
                  title: 'Action',
                  page: const ActionPage(),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.person_2_rounded,
                  title: 'About Us',
                  page: const AboutPage(),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.phone_android_outlined,
                  title: 'Contact',
                  page: const ContactPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    Widget? page,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title), 
      onTap: () {
        Navigator.pop(context);

        if (page != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        }
      },
    );
  }
}