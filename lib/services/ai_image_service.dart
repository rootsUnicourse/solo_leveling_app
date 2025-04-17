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
  static const bool kUseInstantID = false; // Set to true if you need face upload
  static const String _modelVersion = kUseInstantID ? _modelVersionInstantID : _modelVersionAnimagine;
  
  // Helper function to remove null values from map
  static Map<String, dynamic> _cleanInput(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(raw)..removeWhere((k, v) => v == null);
  }

  // Level-specific prompts for Solo Leveling progression
  static const Map<int, String> _levelPrompts = {
    1: 'A young Korean man in his early 20s, wearing basic hunter gear, E-rank hunter, average build, determined expression, anime style, Solo Leveling art style, dark background, subtle shadow aura, similar to Sung Jinwoo\'s initial appearance',
    2: 'E-rank hunter with basic shadow manipulation, subtle dark energy around hands, wearing reinforced combat gear, determined expression, standing in a combat stance, dark atmosphere, mysterious lighting, similar to early dungeon exploration scenes',
    3: 'E-rank hunter with visible shadow control, dark energy forming basic shapes, wearing tactical armor, focused expression, ready for battle, dramatic lighting, action pose, reminiscent of early gate raids',
    4: 'E-rank hunter with enhanced shadow manipulation, shadows forming basic weapons, wearing advanced tactical gear, confident stance, dark energy aura, battle-ready pose, similar to early shadow soldier summoning',
    5: 'D-rank hunter with partial shadow armor, shadows forming basic armor pieces, wearing reinforced combat gear, strong presence, battle stance, dark energy radiating, similar to the Red Gate arc',
    6: 'D-rank hunter with complete shadow armor set, shadows forming complex shapes, wearing advanced combat gear, powerful aura, battle-ready stance, dark energy swirling, reminiscent of the Demon Castle arc',
    7: 'D-rank hunter with mastery over shadows, complete shadow armor set, shadows forming weapons and armor, muscular build, confident expression, dark energy radiating, similar to the Job Change Quest arc',
    8: 'C-rank hunter with advanced shadow manipulation, shadows forming complex armor and weapons, wearing elite combat gear, powerful presence, battle stance, dark energy aura, reminiscent of the Retesting Rank arc',
    9: 'B-rank hunter with expert shadow control, shadows forming intricate armor patterns, wearing high-level combat gear, commanding presence, battle-ready stance, dark energy swirling, similar to the Jeju Island arc',
    10: 'B-rank hunter with near-perfect shadow mastery, shadows forming complex armor and weapons, wearing elite combat gear, powerful aura, battle stance, dark energy radiating, reminiscent of the Tokyo S-Rank Gate arc',
    11: 'A-rank hunter with supreme shadow control, shadows forming intricate armor and weapons, wearing legendary combat gear, commanding presence, battle-ready stance, dark energy aura, similar to the Monarchs\' War arc',
    12: 'A-rank hunter with perfect shadow mastery, shadows forming divine armor and weapons, wearing mythical combat gear, godlike presence, battle stance, dark energy swirling, reminiscent of the final battle scenes',
    13: 'S-rank hunter with ultimate shadow control, shadows forming divine armor and weapons, wearing legendary combat gear, supreme presence, battle-ready stance, dark energy radiating, similar to the Shadow Monarch\'s power',
    14: 'S-rank hunter with absolute shadow mastery, shadows forming godlike armor and weapons, wearing mythical combat gear, divine presence, battle stance, dark energy aura, reminiscent of the final transformation',
    15: 'S-rank hunter with complete shadow domination, shadows forming divine armor and weapons, wearing ultimate combat gear, supreme presence, battle-ready stance, dark energy swirling, similar to the ultimate power level',
    // Extended prompts for higher levels
    20: 'S-rank hunter with evolved shadow powers, wearing advanced mythical armor, surrounded by swirling dark energy, commanding presence, battle stance, divine aura, similar to the Monarchs\' War arc',
    25: 'S-rank hunter with enhanced shadow abilities, wearing legendary armor, powerful presence, dark energy radiating, battle-ready pose, similar to the Shadow Monarch\'s power',
    30: 'S-rank hunter with supreme shadow control, wearing divine armor, godlike presence, dark energy swirling, battle stance, similar to the final battle scenes',
    35: 'S-rank hunter with ultimate shadow mastery, wearing mythical armor, supreme presence, dark energy aura, battle-ready stance, similar to the ultimate power level',
    40: 'S-rank hunter with perfected shadow abilities, wearing ultimate armor, divine presence, dark energy radiating, battle stance, similar to the Monarchs\' War arc',
    45: 'S-rank hunter with absolute shadow control, wearing legendary armor, godlike presence, dark energy swirling, battle-ready pose, similar to the Shadow Monarch\'s power',
    50: 'S-rank hunter with complete shadow mastery, wearing divine armor, supreme presence, dark energy aura, battle stance, similar to the final battle scenes',
    55: 'S-rank hunter with evolved shadow powers, wearing mythical armor, divine presence, dark energy radiating, battle-ready stance, similar to the ultimate power level',
    60: 'S-rank hunter with enhanced shadow abilities, wearing ultimate armor, godlike presence, dark energy swirling, battle stance, similar to the Monarchs\' War arc',
    65: 'S-rank hunter with supreme shadow control, wearing legendary armor, supreme presence, dark energy aura, battle-ready pose, similar to the Shadow Monarch\'s power',
    70: 'S-rank hunter with ultimate shadow mastery, wearing divine armor, godlike presence, dark energy radiating, battle stance, similar to the final battle scenes'
  };

  static const String _negativePrompt = 'blurry, low quality, distorted, deformed, ugly, bad anatomy, bad proportions, female, feminine features, unrealistic proportions, western art style, photorealistic';

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

      // Only preprocess when you really need it
      String? faceImageDataUrl;
      if (faceImagePath != null && kUseInstantID) {
        final faceImageFile = File(faceImagePath);
        final faceImageBytes = await faceImageFile.readAsBytes();
        final processedFaceBytes = await _preprocessImage(Uint8List.fromList(faceImageBytes));
        
        final faceImageBase64 = base64Encode(processedFaceBytes);
        final faceMime = faceImagePath.toLowerCase().endsWith('.jpg') || faceImagePath.toLowerCase().endsWith('.jpeg') 
            ? 'image/jpeg' 
            : 'image/png';
        faceImageDataUrl = 'data:$faceMime;base64,$faceImageBase64';
      }

      // Add pose image if provided and using Instant-ID
      String? poseImageDataUrl;
      if (poseImagePath != null && kUseInstantID) {
        final poseImageFile = File(poseImagePath);
        final poseImageBytes = await poseImageFile.readAsBytes();
        final processedPoseBytes = await _preprocessImage(Uint8List.fromList(poseImageBytes));
        
        final poseImageBase64 = base64Encode(processedPoseBytes);
        final poseMime = poseImagePath.toLowerCase().endsWith('.jpg') || poseImagePath.toLowerCase().endsWith('.jpeg') 
            ? 'image/jpeg' 
            : 'image/png';
        poseImageDataUrl = 'data:$poseMime;base64,$poseImageBase64';
      }

      // Use custom prompt if provided, otherwise use the level-specific prompt
      final prompt = customPrompt ?? _levelPrompts[level] ?? _levelPrompts[1]!;

      // Create the input for the API with adjusted parameters
      final input = _cleanInput({
        'prompt': prompt,
        'negative_prompt': _negativePrompt,
        'width': 1024,
        'height': 1024,
        'num_inference_steps': 25,
        'guidance_scale': 6,
        'seed': Random().nextInt(1 << 31),

        // Add these only when Instant-ID is active
        if (kUseInstantID) ...{
          'image': faceImageDataUrl,
          'ip_adapter_scale': 0.65,
          'sdxl_weights': 'rocketdigitalai/animagine-xl-4.0',
          if (poseImageDataUrl != null) 'pose_image': poseImageDataUrl,
        },
      });

      print('Starting image generation with prompt: $prompt');
      print('Using 1024x1024 resolution for faster processing');
      
      // Make the API call to Replicate
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Prefer': 'wait=60',
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
      
      if (prediction['status'] == 'starting') {
        print('Model is warming up - this may take a few minutes on first run');
        print('Subsequent runs will be faster as the model stays warm');
      }
      
      // If the prediction is already complete, get the output URL
      if (prediction['status'] == 'succeeded' && prediction['output'] != null) {
        final resultUrl = prediction['output'][0];
        print('Image generation completed immediately. Output URL: $resultUrl');
        return await _downloadAndSaveImage(resultUrl, level, variationTag: 'immediate');
      }

      // If not complete, poll for the result
      return await _pollForResult(prediction['id'], apiKey, level);
    } catch (e) {
      print('Error generating hunter image: $e');
      return null;
    }
  }
  
  // Poll the API for result
  static Future<String?> _pollForResult(String predictionId, String apiKey, int level) async {
    bool completed = false;
    int attempts = 0;
    const maxAttempts = 60; // 60 attempts with variable delay = 1-2 minutes max
    int delaySeconds = 1;

    while (!completed && attempts < maxAttempts) {
      attempts++;
      print('Polling attempt $attempts/$maxAttempts for prediction $predictionId');
      
      // Increase delay after 15 attempts if still starting
      if (attempts > 15) {
        delaySeconds = 2;
      }
      
      await Future.delayed(Duration(seconds: delaySeconds));
      
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
      print('Image generation timed out after $maxAttempts attempts (${maxAttempts * delaySeconds} seconds)');
      throw Exception('Image generation timed out after ${maxAttempts * delaySeconds} seconds');
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
      final String prompt = _levelPrompts[level] ?? _levelPrompts[1]!;
      
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
      "A young male E-rank hunter in basic black combat gear, standing in a defensive stance with fists raised, looking determined but inexperienced. Anime style, Solo Leveling inspired, male character, serious expression, basic equipment, combat pose, ready to fight, dynamic pose, action shot, dramatic lighting",
      "A young male E-rank hunter in a simple black jacket and pants, crouching in a stealth position, looking focused and alert. Anime style, Solo Leveling inspired, male character, determined expression, minimal gear, stealth pose, hand on weapon, low angle shot, dark atmosphere, mysterious lighting",
      "A young male E-rank hunter in basic black tactical gear, standing with arms crossed, looking confident but still inexperienced. Anime style, Solo Leveling inspired, male character, calm expression, starter equipment, confident pose, slight smirk, high angle shot, urban background, street lighting"
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