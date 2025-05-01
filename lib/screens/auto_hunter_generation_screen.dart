import 'package:flutter/material.dart';
import 'package:solo_leveling_app/services/ai_image_service.dart';
import 'package:solo_leveling_app/screens/hunter_profile_screen.dart';
import 'package:solo_leveling_app/services/storage_service.dart';
import 'package:solo_leveling_app/services/background_image_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoHunterGenerationScreen extends StatefulWidget {
  const AutoHunterGenerationScreen({Key? key}) : super(key: key);

  @override
  State<AutoHunterGenerationScreen> createState() => _AutoHunterGenerationScreenState();
}

class _AutoHunterGenerationScreenState extends State<AutoHunterGenerationScreen> {
  bool _isGenerating = true;
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _generateAndSelectImage();
  }

  Future<void> _generateAndSelectImage() async {
    try {
      // Generate the E-rank hunter images without face input
      final List<String> imagePaths = await AIImageService.generateAutoHunterImages();
      
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
      setState(() {
        _selectedImagePath = targetPath;
        _isGenerating = false;
      });
      
      // Initialize and start background image generation without face image
      await BackgroundImageService.initializeAutoBackgroundGeneration();
      BackgroundImageService.startBackgroundGeneration();
      
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

  void _proceedToDashboard() async {
    if (_selectedImagePath == null) return;
    
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HunterProfileScreen(
          faceImagePath: '',  // Empty since we're not using face image
          hunterImagePath: _selectedImagePath!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creating Your Hunter Profile'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGenerating) ...[
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
              ] else if (_selectedImagePath != null) ...[
                const Text(
                  'Your Hunter Profile is Ready!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_selectedImagePath!),
                    width: 250,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _proceedToDashboard,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('Continue to Your Profile'),
                ),
              ] else ...[
                const Text(
                  'Failed to generate hunter profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
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
            ],
          ),
        ),
      ),
    );
  }
} 