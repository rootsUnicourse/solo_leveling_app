import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solo_leveling_app/services/storage_service.dart';
import 'package:solo_leveling_app/screens/camera_screen.dart';
import 'package:solo_leveling_app/screens/hunter_generation_screen.dart';

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({Key? key}) : super(key: key);

  static Future<void> checkAndShow(BuildContext context) async {
    final isFirstTime = await StorageService.isFirstTimeOpen();
    
    if (isFirstTime) {
      if (context.mounted) {
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const WelcomeDialog(),
        );
        
        if (result == true) {
          // User accepted, proceed to camera screen
          if (context.mounted) {
            final imagePath = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (context) => const CameraScreen(),
              ),
            );
            
            if (imagePath != null && context.mounted) {
              // Mark app as opened
              await StorageService.markAppOpened();
              
              // Navigate to hunter generation screen
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => HunterGenerationScreen(
                    faceImagePath: imagePath,
                  ),
                ),
              );
            } else if (context.mounted) {
              // User cancelled camera, mark app as opened anyway
              await StorageService.markAppOpened();
            }
          }
        } else {
          // User declined or dialog was dismissed, exit app
          SystemNavigator.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_active,
              color: Theme.of(context).colorScheme.primary,
              size: 60,
            ),
            const SizedBox(height: 24),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'You have acquired the qualifications\nto be a '),
                  TextSpan(
                    text: 'Player',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const TextSpan(text: '. Will you accept?'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'By accepting, you will become a hunter. We will create a personalized hunter profile based on your face.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 