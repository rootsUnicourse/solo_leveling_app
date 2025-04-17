import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'ai_image_service.dart';

class BackgroundImageService {
  static const String uniqueWorkName = 'backgroundImageGeneration';
  static const String faceImagePathKey = 'faceImagePath';
  static const String generatingLevelsKey = 'generatingLevels';
  static const String completedLevelsKey = 'completedLevels';
  
  // Initialize the background service
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }
  
  // Start generating images for all levels in the background
  static Future<void> startGeneratingImages(String faceImagePath) async {
    try {
      // Store the face image path
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(faceImagePathKey, faceImagePath);
      
      // Set up the list of levels to generate (2-25, since level 1 is done at onboarding)
      final List<int> levelsToGenerate = [3, 5, 10, 15, 20, 25];
      await prefs.setStringList(generatingLevelsKey, levelsToGenerate.map((e) => e.toString()).toList());
      await prefs.setStringList(completedLevelsKey, []);
      
      // Schedule the background task
      await Workmanager().registerOneOffTask(
        'generate_hunter_images',
        uniqueWorkName,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
      
      debugPrint('Background image generation scheduled');
    } catch (e) {
      debugPrint('Error scheduling background tasks: $e');
    }
  }
  
  // Get the completion status of image generation
  static Future<Map<String, dynamic>> getGenerationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> generatingLevels = prefs.getStringList(generatingLevelsKey) ?? [];
      final List<String> completedLevels = prefs.getStringList(completedLevelsKey) ?? [];
      
      return {
        'total': generatingLevels.length + completedLevels.length,
        'completed': completedLevels.length,
        'completedLevels': completedLevels.map((e) => int.parse(e)).toList(),
        'inProgress': generatingLevels.map((e) => int.parse(e)).toList(),
      };
    } catch (e) {
      debugPrint('Error getting generation status: $e');
      return {
        'total': 0,
        'completed': 0,
        'completedLevels': <int>[],
        'inProgress': <int>[],
      };
    }
  }
}

// This is the callback function that will be called by Workmanager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == BackgroundImageService.uniqueWorkName) {
        return await _generateImages();
      }
      return true;
    } catch (e) {
      debugPrint('Error in background task: $e');
      return false;
    }
  });
}

// Generate images one by one
Future<bool> _generateImages() async {
  try {
    // Get the face image path and levels to generate
    final prefs = await SharedPreferences.getInstance();
    final String? faceImagePath = prefs.getString(BackgroundImageService.faceImagePathKey);
    final List<String> generatingLevels = prefs.getStringList(BackgroundImageService.generatingLevelsKey) ?? [];
    final List<String> completedLevels = prefs.getStringList(BackgroundImageService.completedLevelsKey) ?? [];
    
    if (faceImagePath == null || generatingLevels.isEmpty) {
      debugPrint('No face image path or levels to generate');
      return true;
    }
    
    // Take the first level to generate
    final String levelStr = generatingLevels.first;
    final int level = int.parse(levelStr);
    
    // Update the lists
    generatingLevels.remove(levelStr);
    await prefs.setStringList(BackgroundImageService.generatingLevelsKey, generatingLevels);
    
    // Generate the image
    debugPrint('Generating image for level $level');
    final String? imagePath = await AIImageService.generateHunterImage(faceImagePath, level);
    
    if (imagePath != null) {
      // Image generation successful
      completedLevels.add(levelStr);
      await prefs.setStringList(BackgroundImageService.completedLevelsKey, completedLevels);
      debugPrint('Generated image for level $level: $imagePath');
    } else {
      // Failed to generate, add back to the queue
      generatingLevels.add(levelStr);
      await prefs.setStringList(BackgroundImageService.generatingLevelsKey, generatingLevels);
      debugPrint('Failed to generate image for level $level');
    }
    
    // If there are more levels to generate, schedule another task
    if (generatingLevels.isNotEmpty) {
      await Workmanager().registerOneOffTask(
        'generate_hunter_images_${DateTime.now().millisecondsSinceEpoch}',
        BackgroundImageService.uniqueWorkName,
        initialDelay: const Duration(minutes: 1),
        existingWorkPolicy: ExistingWorkPolicy.append,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
    }
    
    return true;
  } catch (e) {
    debugPrint('Error generating images: $e');
    return false;
  }
} 