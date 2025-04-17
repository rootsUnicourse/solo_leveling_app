import 'package:flutter/material.dart';
import 'package:solo_leveling_app/services/ai_image_service.dart';
import 'package:solo_leveling_app/services/background_image_service.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class GeneratedImagesScreen extends StatefulWidget {
  const GeneratedImagesScreen({Key? key}) : super(key: key);

  @override
  State<GeneratedImagesScreen> createState() => _GeneratedImagesScreenState();
}

class _GeneratedImagesScreenState extends State<GeneratedImagesScreen> {
  final List<int> _levels = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70];
  Map<int, String?> _imagePaths = {};
  Map<int, bool> _isGenerating = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // First check if we have a face image path
    final prefs = await SharedPreferences.getInstance();
    final faceImagePath = prefs.getString('face_image_path');
    
    if (faceImagePath != null) {
      // Start background generation if not already running
      await BackgroundImageService.startGeneratingImages(faceImagePath);
    }
    
    // Load initial images and status
    await _loadImages();
    await _checkGenerationStatus();
    
    // Set up periodic status checks
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkGenerationStatus();
      await _loadImages();
    });
  }

  Future<void> _checkGenerationStatus() async {
    final status = await BackgroundImageService.getGenerationStatus();
    setState(() {
      for (int level in _levels) {
        _isGenerating[level] = status['inProgress'].contains(level);
      }
    });
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    
    // Check each level for generated images
    for (int level in _levels) {
      final path = await AIImageService.getUserImagePathForLevel(level);
      setState(() {
        _imagePaths[level] = path;
      });
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _forceGenerateAll() async {
    final prefs = await SharedPreferences.getInstance();
    final faceImagePath = prefs.getString('face_image_path');
    
    if (faceImagePath != null) {
      setState(() {
        for (int level in _levels) {
          _isGenerating[level] = true;
        }
      });
      
      await BackgroundImageService.startGeneratingImages(faceImagePath);
      await _checkGenerationStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No face image found. Please set your profile image first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Hunter Images'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadImages();
              await _checkGenerationStatus();
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Force Generate All',
            onPressed: _forceGenerateAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: _levels.length,
              itemBuilder: (context, index) {
                final level = _levels[index];
                final imagePath = _imagePaths[level];
                final isGenerating = _isGenerating[level] ?? false;
                
                return Card(
                  elevation: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: isGenerating
                            ? const Center(
                                child: CircularProgressIndicator(),
                              )
                            : imagePath != null
                                ? Image.file(
                                    File(imagePath),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              'Level $level',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isGenerating)
                              const Text(
                                'Generating...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
} 