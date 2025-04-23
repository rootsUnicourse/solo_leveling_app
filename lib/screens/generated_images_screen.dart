import 'package:flutter/material.dart';
import 'package:solo_leveling_app/services/ai_image_service.dart';
import 'package:solo_leveling_app/services/background_image_service.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:shimmer/shimmer.dart';

class GeneratedImagesScreen extends StatefulWidget {
  const GeneratedImagesScreen({Key? key}) : super(key: key);

  @override
  State<GeneratedImagesScreen> createState() => _GeneratedImagesScreenState();
}

class _GeneratedImagesScreenState extends State<GeneratedImagesScreen> {
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
      for (int level in BackgroundImageService.milestoneLevels) {
        _isGenerating[level] = status['inProgress'].contains(level);
      }
    });
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    
    // Check each milestone level for generated images
    for (int level in BackgroundImageService.milestoneLevels) {
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
        for (int level in BackgroundImageService.milestoneLevels) {
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

  String _getLevelRankLabel(int level) {
    if (level == 1) return 'E-rank (weak)';
    if (level == 5) return 'E→D (rookie)';
    if (level == 10) return 'D→C';
    if (level == 15) return 'C→B';
    if (level == 20) return 'B→A';
    if (level == 25) return 'Low S';
    if (level == 30) return 'Mid S';
    if (level == 35) return 'High S';
    if (level == 40) return 'Shadow Monarch';
    if (level == 45) return 'Monarch (battle)';
    if (level == 50) return 'Monarch (vs Antares)';
    if (level == 55) return 'Monarch (victorious)';
    if (level == 60) return 'Monarch (sovereign)';
    if (level == 65) return 'Monarch (enthroned)';
    if (level == 70) return 'Monarch (pinnacle)';
    return 'Level $level';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hunter Progression'),
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
            tooltip: 'Generate All',
            onPressed: _forceGenerateAll,
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: BackgroundImageService.milestoneLevels.length,
        itemBuilder: (context, index) {
          final level = BackgroundImageService.milestoneLevels[index];
          final imagePath = _imagePaths[level];
          final isGenerating = _isGenerating[level] ?? false;
          
          return Card(
            elevation: 4,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isGenerating)
                        // Shimmer skeleton loading effect instead of spinner
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            color: Colors.black12,
                          ),
                        )
                      else if (imagePath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(imagePath),
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                        _getLevelRankLabel(level),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Level $level',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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