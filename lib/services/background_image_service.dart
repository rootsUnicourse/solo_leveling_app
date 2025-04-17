import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'ai_image_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class BackgroundImageService {
  static const String uniqueWorkName = 'backgroundImageGeneration';
  static const String faceImagePathKey = 'face_image_path';
  static const String generatingLevelsKey = 'generating_levels';
  static const String completedLevelsKey = 'completed_levels';
  
  // Initialize the background service
  static Future<void> initialize() async {
    if (Platform.isIOS) {
      // Initialize iOS background service
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: (ServiceInstance service) async {
            onStart(service);
          },
          autoStart: true,
          isForegroundMode: true,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: (ServiceInstance service) async {
            onStart(service);
          },
          onBackground: (ServiceInstance service) async {
            return onIosBackground(service);
          },
        ),
      );
    } else {
      // Initialize Android workmanager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
    }
  }
  
  static Future<void> initializeBackgroundGeneration(String faceImagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save the face image path
      await prefs.setString(faceImagePathKey, faceImagePath);
      
      // Initialize the levels to generate (5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70)
      final levelsToGenerate = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70];
      await prefs.setStringList(generatingLevelsKey, levelsToGenerate.map((e) => e.toString()).toList());
      
      // Initialize completed levels list
      await prefs.setStringList(completedLevelsKey, []);
      
      debugPrint('Background image generation initialized for 15 levels (1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70)');
    } catch (e) {
      debugPrint('Error initializing background generation: $e');
    }
  }
  
  // Start generating images for all levels in the background
  static Future<void> startGeneratingImages(String faceImagePath) async {
    try {
      // Store the face image path
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(faceImagePathKey, faceImagePath);
      
      // Set up the list of levels to generate
      final List<int> levelsToGenerate = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70];
      await prefs.setStringList(generatingLevelsKey, levelsToGenerate.map((e) => e.toString()).toList());
      await prefs.setStringList(completedLevelsKey, []);
      
      if (Platform.isIOS) {
        // Start iOS background service
        final service = FlutterBackgroundService();
        await service.startService();
      } else {
        // Schedule Android background task
        await Workmanager().registerOneOffTask(
          'generate_hunter_images',
          uniqueWorkName,
          existingWorkPolicy: ExistingWorkPolicy.replace,
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresBatteryNotLow: true,
          ),
        );
      }
      
      debugPrint('Background image generation scheduled for 15 levels');
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
  
  static Future<bool> hasImagesForLevel(int level) async {
    try {
      // Check if completed in background generation
      final prefs = await SharedPreferences.getInstance();
      final List<String> completedLevels = prefs.getStringList(completedLevelsKey) ?? [];
      
      // If marked as completed in the background service, return true
      if (completedLevels.contains(level.toString())) {
        return true;
      }
      
      // Also check if the file actually exists on disk (for manually saved images)
      final directory = await getApplicationDocumentsDirectory();
      final String imagePath = '${directory.path}/user_images/user_level_$level.jpg';
      final exists = await File(imagePath).exists();
      
      // If the file exists, also add it to the completed levels list
      if (exists && !completedLevels.contains(level.toString())) {
        completedLevels.add(level.toString());
        await prefs.setStringList(completedLevelsKey, completedLevels);
      }
      
      return exists;
    } catch (e) {
      debugPrint('Error checking completed levels: $e');
      return false;
    }
  }

  static Future<void> startBackgroundGeneration() async {
    try {
      bool isComplete = false;
      while (!isComplete) {
        isComplete = await _generateImages();
        // Only wait 5 seconds between attempts instead of 5 minutes
        await Future.delayed(const Duration(seconds: 5));
      }
      debugPrint('Background image generation completed');
    } catch (e) {
      debugPrint('Error in background generation loop: $e');
    }
  }
}

// Move _generateImages outside the class to make it accessible to the callback dispatcher
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
      
      // If there are more levels to generate, return false to continue
      if (generatingLevels.isNotEmpty) {
        debugPrint('Continuing with next level...');
        return false;
      }
    } else {
      // Failed to generate, add back to the queue
      generatingLevels.add(levelStr);
      await prefs.setStringList(BackgroundImageService.generatingLevelsKey, generatingLevels);
      debugPrint('Failed to generate image for level $level, will retry later');
    }
    
    // Return true only if we're done with all levels
    return generatingLevels.isEmpty;
  } catch (e) {
    debugPrint('Error in background image generation: $e');
    return true;
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

// iOS background service handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  service.invoke('setAsForeground');
  
  // Start the image generation process
  BackgroundImageService.startBackgroundGeneration();
  
  service.invoke('setAsBackground');
} 