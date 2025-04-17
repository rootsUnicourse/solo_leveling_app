import 'package:flutter/material.dart';
import 'package:solo_leveling_app/screens/dashboard_screen.dart';
import 'dart:io';

class HunterProfileScreen extends StatelessWidget {
  final String faceImagePath;
  final String hunterImagePath;

  const HunterProfileScreen({
    Key? key,
    required this.faceImagePath,
    required this.hunterImagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Hunter Profile'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Your Hunter Profile has been created!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Image.file(
              File(hunterImagePath),
              width: 300,
              height: 300,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(),
                  ),
                );
              },
              child: const Text('Continue to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
} 