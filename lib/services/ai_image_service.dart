import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIImageService {
  // Use the standard predictions endpoint with model version
  static const String _apiUrl = 'https://api.replicate.com/v1/predictions';
  
  // Model version IDs
  static const String _modelVersionAnimagine = '7af46ee494f1cf196d49a8592737f4eb789e34a5a995751b23a869d19f5dc2ba';
  static const String _modelVersionInstantID = '11219f80ba03ca1ce78194191ffa4fc74f7c1afeef50df95f477aa66f2f65bc5';
  
  // Runtime model selection
  static const bool kUseInstantID = true; // Enable InstantID to use face images
  static const String _modelVersion = kUseInstantID ? _modelVersionInstantID : _modelVersionAnimagine;
  
  // Helper function to remove null values from map
  static Map<String, dynamic> _cleanInput(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(raw)..removeWhere((k, v) => v == null);
  }

  // Replace the old 70-entry map with the compact milestones map (every 5 levels)
  static const Map<int, String> _milestonePrompts = {
    1 : 'Sung Jin-Woo as a weak E-rank hunter, thin build with disheveled black hair, pale complexion, tired eyes with dark circles, wearing cheap basic black hunter gear, fearful expression, standing at dungeon entrance. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    5 : 'Sung Jin-Woo as a D-rank hunter, slightly broader shoulders, determined gaze, same basic gear, more confident stance. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    10: 'Sung Jin-Woo as a C-rank hunter, athletic build, reinforced black jacket, faint shadow wisps around fingers, focused expression. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    15: 'Sung Jin-Woo as a B-rank hunter, strong physique, combat vest, dual short daggers on belt, confident smirk, shadows forming around hands. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    20: 'Sung Jin-Woo as an A-rank hunter, impressive build, black tactical armour, 2 small shadow figures behind him, intense gaze. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    25: 'Sung Jin-Woo as a low S-rank hunter, powerful physique, glowing blue-black eyes, 5 shadow soldiers following him, enhanced combat gear. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    30: 'Sung Jin-Woo as a mid S-rank hunter, sleek armour with blue energy veins, thick blue aura surrounding him, commanding presence. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    35: 'Sung Jin-Woo as a high S-rank hunter, muscular build, black cape flowing, Igris and Tank at his side, powerful stance. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    40: 'Sung Jin-Woo as the awakening Shadow Monarch, perfect physique, royal black armour, blue energy crown halo, army of shadows rising. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    45: 'Sung Jin-Woo as the Shadow Monarch in battle, battle-worn armour, crackling daggers, fierce expression, surrounded by elite shadows. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    50: 'Sung Jin-Woo facing Antares, godlike physique, massive shadow legion behind him, fierce stare, power radiating. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    55: 'Sung Jin-Woo after defeating Antares, pristine armour, legion kneeling, commanding aura, victorious stance. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    60: 'Sung Jin-Woo as the absolute Shadow Sovereign, perfect form, arms crossed, faint throne silhouette behind, unlimited power. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    65: 'Sung Jin-Woo as the Shadow Sovereign, seated on throne of shadows, calm gaze, royal presence, shadows bowing. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.',
    70: 'Sung Jin-Woo at the pinnacle of power, divine form, hand out-stretched creating new shadow soldier, ultimate power manifested. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.'
  };
  
  // Helper picks the last milestone ≤ level so you can still call with any level
  static String _promptFor(int level) {
    final keys = _milestonePrompts.keys.where((k) => k <= level).toList()..sort();
    return keys.isEmpty ? _milestonePrompts[1]! : _milestonePrompts[keys.last]!;
  }

  static const String _negativePrompt = 'blurry, low quality, distorted, deformed, ugly, bad anatomy, bad proportions, female, feminine features, unrealistic proportions, western art style, photorealistic, cartoon, 3D, painting, crayon, sketch, graphite, impressionist, noisy, blurry, soft, deformed face, deformed eyes, asymmetrical eyes, crossed eyes';

  // Generate a hunter image for the specified level
  static Future<String?> generateHunterImage(
    String? faceImagePath, 
    int level, {
    String? customPrompt,
    String? poseImagePath,
  }) async {
    try {
      final apiKey = dotenv.env['REPLICATE_API_TOKEN'];
      if (apiKey == null) {
        debugPrint('Warning: REPLICATE_API_TOKEN is not set in environment variables');
        return null;
      }

      if (faceImagePath == null) {
        debugPrint('Warning: No face image provided for InstantID');
        return null;
      }

      // Preprocess the face image
      final faceImageFile = File(faceImagePath);
      final faceImageBytes = await faceImageFile.readAsBytes();
      final processedFaceBytes = await _preprocessImage(Uint8List.fromList(faceImageBytes));
      
      final faceImageBase64 = base64Encode(processedFaceBytes);
      final faceMime = faceImagePath.toLowerCase().endsWith('.jpg') || faceImagePath.toLowerCase().endsWith('.jpeg') 
          ? 'image/jpeg' 
          : 'image/png';
      final faceImageDataUrl = 'data:$faceMime;base64,$faceImageBase64';

      // Use custom prompt if provided, otherwise use the level-specific prompt using the helper
      final prompt = customPrompt ?? _promptFor(level);

      // Create the input for the API with adjusted parameters for anime style
      final input = _cleanInput({
        'prompt': prompt,
        'negative_prompt': _negativePrompt,
        'width': 1024,
        'height': 1024,
        'num_inference_steps': 30,
        'guidance_scale': 7.5,
        'seed': Random().nextInt(1 << 31),
        'image': faceImageDataUrl,
        'ip_adapter_scale': 0.8,
        'sdxl_weights': 'animagine-xl-30',
      });

      print('Starting image generation with face image and prompt: $prompt');
      print('Using InstantID model for face preservation');
      
      // Make the API call to Replicate with Prefer: wait header for synchronous mode
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Prefer': 'wait', // Use synchronous mode instead of wait=60
        },
        body: jsonEncode({
          'version': _modelVersion,
          'input': input
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 202) {
        print('Failed to start prediction: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to start prediction: ${response.statusCode}');
      }

      final prediction = jsonDecode(response.body);
      print('Prediction started: ${prediction['id']}');
      print('Initial status: ${prediction['status']}');
      
      // If the prediction is already complete, get the output URL
      if (prediction['status'] == 'succeeded' && prediction['output'] != null) {
        final resultUrl = prediction['output'][0];
        print('Image generation completed immediately. Output URL: $resultUrl');
        return await _downloadAndSaveImage(resultUrl, level, variationTag: 'immediate');
      }

      // If not complete (model still warming up), poll for the result with exponential backoff
      return await _pollForResult(prediction['id'], apiKey, level);
    } catch (e) {
      print('Error generating hunter image: $e');
      return null;
    }
  }
  
  // Poll the API for result with exponential backoff
  static Future<String?> _pollForResult(String predictionId, String apiKey, int level) async {
    bool completed = false;
    int attempts = 0;
    const maxAttempts = 20; // Reduced from 60 to 20 with exponential backoff
    int delaySec = 2; // Starting delay

    while (!completed && attempts < maxAttempts) {
      attempts++;
      print('Polling attempt $attempts/$maxAttempts for prediction $predictionId');
      
      await Future.delayed(Duration(seconds: delaySec));
      // Exponential backoff with clamping
      delaySec = (delaySec * 1.6).clamp(2, 30).round();
      
      try {
        final response = await http.get(
          Uri.parse('https://api.replicate.com/v1/predictions/$predictionId'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'];
          print('Current status: $status');
          
          if (status == 'succeeded') {
            completed = true;
            final output = data['output'];
            
            // Handle both array and string output formats
            String? imageUrl;
            if (output is List && output.isNotEmpty) {
              imageUrl = output[0];
            } else if (output is String) {
              imageUrl = output;
            }
            
            if (imageUrl != null) {
              print('Image generation completed successfully!');
              return await _downloadAndSaveImage(imageUrl, level);
            } else {
              print('No output URL found in successful response');
              print('Full response: $data');
              throw Exception('No output URL found in successful response');
            }
          } else if (status == 'failed') {
            print('Image generation failed: ${data['error']}');
            throw Exception('Image generation failed: ${data['error']}');
          } else if (status == 'canceled') {
            print('Image generation was canceled');
            throw Exception('Image generation was canceled');
          } else if (status == 'starting') {
            print('Model is still warming up...');
          } else {
            print('Current progress: ${data['logs'] ?? 'No progress info available'}');
          }
        } else {
          print('Poll request failed with status: ${response.statusCode}');
          print('Response body: ${response.body}');
          // Don't throw here, just continue polling
        }
      } catch (e) {
        print('Error during polling: $e');
        // Don't throw here, just continue polling
      }
    }

    if (!completed) {
      print('Image generation timed out after $maxAttempts attempts');
      throw Exception('Image generation timed out after $maxAttempts attempts');
    }

    return null;
  }
  
  // Download and save the generated image
  static Future<String?> _downloadAndSaveImage(String imageUrl, int level, {String? variationTag}) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode == 200) {
        // Get the application documents directory
        final directory = await getApplicationDocumentsDirectory();
        final String folderPath = '${directory.path}/user_images';
        
        // Create the user_images folder if it doesn't exist
        final folder = Directory(folderPath);
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }
        
        // Save the image with level in filename
        final filename = 'user_level_$level.jpg';
        final file = File('$folderPath/$filename');
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('Image saved to: ${file.path}');
        return file.path;
      } else {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return null;
    }
  }
  
  // Check if a user image exists for a given level
  static Future<bool> hasUserImageForLevel(int level) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String imagePath = '${directory.path}/user_images/user_level_$level.jpg';
      return await File(imagePath).exists();
    } catch (e) {
      return false;
    }
  }
  
  // Get the path for a user image at a given level
  static Future<String?> getUserImagePathForLevel(int level) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String imagePath = '${directory.path}/user_images/user_level_$level.jpg';
      final file = File(imagePath);
      
      if (await file.exists()) {
        return imagePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // For testing purposes only - this can be used if the API is not working
  static Future<String?> mockGenerateHunterImage(String imagePath, int level) async {
    try {
      debugPrint('Using mock image generation for level $level');
      await Future.delayed(const Duration(seconds: 5)); // Simulate delay
      
      // Just return the original image for testing
      final directory = await getApplicationDocumentsDirectory();
      final String folderPath = '${directory.path}/user_images';
      
      // Create folder if it doesn't exist
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      
      // Save a copy of the original image
      final String targetPath = '$folderPath/user_level_$level.jpg';
      await File(imagePath).copy(targetPath);
      
      return targetPath;
    } catch (e) {
      debugPrint('Exception in mockGenerateHunterImage: $e');
      return null;
    }
  }

  // Call the Node.js service to generate hunter image
  static Future<String?> generateHunterImageWithNodeService(String imagePath, int level) async {
    try {
      debugPrint('Starting image generation via Node.js service for level $level');
      
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        debugPrint('Image file does not exist: $imagePath');
        return null;
      }
      
      // Create the prompt based on level
      final String prompt = _promptFor(level);
      
      // In a real implementation, this would call your Node.js service
      // For example:
      /*
      final response = await http.post(
        Uri.parse('http://localhost:3000/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': prompt,
          'level': level,
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data['success']) {
          // Download the image from the URL
          final imageUrl = data['imageUrl'];
          return await _downloadAndSaveImage(imageUrl, level);
        }
      }
      */
      
      // For now, just use the mock implementation
      debugPrint('NodeJS service not connected, falling back to mock implementation');
      return await mockGenerateHunterImage(imagePath, level);
    } catch (e) {
      debugPrint('Exception in generateHunterImageWithNodeService: $e');
      return null;
    }
  }

  // Preprocess the image to 512x512 and optimize size
  static Future<Uint8List> _preprocessImage(Uint8List imageBytes) async {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        print('Failed to decode image');
        return imageBytes;
      }
      
      // Resize to 512x512
      final resized = img.copyResize(decoded, width: 512, height: 512);
      
      // Encode as JPEG with 80% quality
      return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
    } catch (e) {
      print('Error preprocessing image: $e');
      return imageBytes; // Fallback to original bytes
    }
  }

  static Future<String?> _getApiKey() async {
    // Get the API key from dart-define
    const apiKey = String.fromEnvironment('REPLICATE_API_KEY');
    if (apiKey.isEmpty) {
      print('Warning: REPLICATE_API_KEY is not set in environment variables');
      return null;
    }
    return apiKey;
  }

  static Future<List<String>> generateMultipleErankImages(String faceImagePath) async {
    final List<String> imagePaths = [];
    final List<String> variations = [
      "Sung Jin-Woo as an E-rank hunter, lean build with disheveled black hair, wearing basic black hunter gear, fearful yet determined expression, standing defensively. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.",
      "Sung Jin-Woo as an E-rank hunter, thin physique, messy black hair, wearing simple black jacket and pants, crouching in stealth position, focused expression. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal.",
      "Sung Jin-Woo as an E-rank hunter, slender build, neat black hair, wearing tactical black gear, standing confidently with arms crossed, slight smirk. High-quality anime style, Japanese manga art style, Solo Leveling accurate portrayal."
    ];

    // Create a directory for profile images if it doesn't exist
    final directory = await getApplicationDocumentsDirectory();
    final profileDir = Directory('${directory.path}/profile_images');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    for (int i = 0; i < variations.length; i++) {
      try {
        final String? imagePath = await generateHunterImage(
          faceImagePath,
          1,
          customPrompt: variations[i],
        );
        if (imagePath != null) {
          // Copy the generated image to the profile directory with a specific name
          final profileImagePath = '${profileDir.path}/profile_option_${i + 1}.jpg';
          await File(imagePath).copy(profileImagePath);
          imagePaths.add(profileImagePath);
          debugPrint('Profile image saved: $profileImagePath');
        }
      } catch (e) {
        print('Error generating image variation ${i + 1}: $e');
      }
    }

    return imagePaths;
  }

  // Get the path for a specific profile option
  static Future<String?> getProfileImagePath(int option) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final profileImagePath = '${directory.path}/profile_images/profile_option_$option.jpg';
      final file = File(profileImagePath);
      
      if (await file.exists()) {
        return profileImagePath;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting profile image path: $e');
      return null;
    }
  }

  // Get the appropriate character image based on level
  static Future<String> getCharacterImagePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/user_images/user_level_1.jpg';
    final file = File(imagePath);
    
    if (await file.exists()) {
      return imagePath;
    }
    
    return 'assets/images/1.webp'; // Using an existing image as placeholder
  }
} 