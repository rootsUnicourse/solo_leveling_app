import 'package:flutter/material.dart';
import 'package:solo_leveling_app/services/ai_image_service.dart';
import 'package:solo_leveling_app/screens/hunter_profile_screen.dart';
import 'package:solo_leveling_app/services/storage_service.dart';
import 'package:solo_leveling_app/services/background_image_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HunterGenerationScreen extends StatefulWidget {
  final String faceImagePath;

  const HunterGenerationScreen({
    Key? key,
    required this.faceImagePath,
  }) : super(key: key);

  @override
  State<HunterGenerationScreen> createState() => _HunterGenerationScreenState();
}

class _HunterGenerationScreenState extends State<HunterGenerationScreen> {
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    _generateAndSelectImage();
  }

  Future<void> _generateAndSelectImage() async {
    try {
      // Generate the three E-rank hunter images
      final List<String> imagePaths = await AIImageService.generateMultipleErankImages(widget.faceImagePath);
      
      if (imagePaths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate images. Please try again.')),
          );
          setState(() {
            _isGenerating = false;
          });
        }
        return;
      }
      
      // Automatically use the first generated image
      final String selectedImagePath = imagePaths[0];
      
      // Set the user's hunter image
      final success = await StorageService.setUserHunterImage(selectedImagePath, 1);
      
      if (!success) {
        throw Exception('Failed to set user hunter image');
      }
      
      // Get the path to the saved image
      final directory = await getApplicationDocumentsDirectory();
      final String targetPath = '${directory.path}/user_images/user_level_1.jpg';
      
      // Initialize and start background image generation
      await BackgroundImageService.initializeBackgroundGeneration(widget.faceImagePath);
      BackgroundImageService.startBackgroundGeneration();
      
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HunterProfileScreen(
            faceImagePath: widget.faceImagePath,
            hunterImagePath: targetPath,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creating Your Hunter Profile'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Generating your E-rank hunter appearance...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please wait while we create your hunter profile.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            if (!_isGenerating)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isGenerating = true;
                  });
                  _generateAndSelectImage();
                },
                child: const Text('Try Again'),
              ),
          ],
        ),
      ),
    );
  }
} 