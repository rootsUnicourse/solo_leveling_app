import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math';

class AIImageService {
  // Use the standard predictions endpoint with model version
  static const String _apiUrl = 'https://api.replicate.com/v1/predictions';
  static const String _modelVersion = 'zsxkib/instant-id:c98b2e7a196828d00955767813b81fc05c5c9b294c670c6d147d545fed4ceecf';
  
  // Helper function to remove null values from map
  static Map<String, dynamic> _cleanInput(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(raw)..removeWhere((k, v) => v == null);
  }

  // Level-specific prompts for Solo Leveling progression
  static const Map<int, String> _levelPrompts = {
    1: 'A young Korean man in his early 20s, wearing basic hunter gear, E-rank hunter, average build, determined expression, anime style, Solo Leveling art style, dark background, subtle shadow aura',
    2: 'Same character as level 1 but slightly more confident stance, basic combat gear, subtle shadow particles around hands',
    3: 'E-rank hunter with improved gear, shadow particles more visible, determined expression, slight muscle definition, Solo Leveling art style',
    4: 'E-rank hunter with enhanced shadow control, shadow particles forming basic shapes, more confident stance, improved combat gear',
    5: 'E-rank hunter with visible shadow manipulation, shadows forming basic weapons, stronger presence, improved physique',
    6: 'D-rank hunter transformation, shadows more defined, forming basic armor pieces, stronger aura, improved combat stance',
    7: 'D-rank hunter with partial shadow armor, shadows forming weapons and basic armor, more muscular build, confident expression',
    8: 'D-rank hunter with complete shadow armor set, shadows forming complex shapes, strong presence, battle-ready stance',
    9: 'C-rank hunter transformation, advanced shadow manipulation, shadows forming complex armor and weapons, powerful aura',
    10: 'C-rank hunter with mastery over shadows, complete shadow armor set, shadows forming intricate patterns, powerful presence, battle-ready stance'
  };

  static const String _negativePrompt = 'blurry, low quality, distorted, deformed, ugly, bad anatomy, bad proportions, female, feminine features, unrealistic proportions, western art style, photorealistic';

  // Generate a hunter image for the specified level
  static Future<String?> generateHunterImage(
    String faceImagePath, 
    int level, {
    String? customPrompt,
    String? poseImagePath,
  }) async {
    try {
      final apiKey = await _getApiKey();
      if (apiKey == null) {
        throw Exception('API key not found');
      }

      // Read and preprocess the face image
      final faceImageFile = File(faceImagePath);
      final faceImageBytes = await faceImageFile.readAsBytes();
      final processedFaceBytes = await _preprocessImage(Uint8List.fromList(faceImageBytes));
      
      final faceImageBase64 = base64Encode(processedFaceBytes);
      final faceMime = faceImagePath.toLowerCase().endsWith('.jpg') || faceImagePath.toLowerCase().endsWith('.jpeg') 
          ? 'image/jpeg' 
          : 'image/png';
      final faceImageDataUrl = 'data:$faceMime;base64,$faceImageBase64';

      // Add pose image if provided
      String? poseImageDataUrl;
      if (poseImagePath != null) {
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
        'image': faceImageDataUrl,
        'prompt': prompt,
        'negative_prompt': _negativePrompt,
        'width': 640,
        'height': 640,
        'guidance_scale': 5,
        'num_inference_steps': 40,
        'ip_adapter_scale': 0.65,
        'pose_image_path': poseImageDataUrl,
        'seed': Random().nextInt(2147483647),
      });

      print('Starting image generation with prompt: $prompt');
      print('Using 640x640 resolution for faster processing');
      
      // Make the API call to Replicate
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Prefer': 'wait=60',
        },
        body: jsonEncode({
          'version': _modelVersion.split(':').last,
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
            
            if (output is List && output.isNotEmpty) {
              print('Image generation completed successfully!');
              return await _downloadAndSaveImage(output[0], level);
            } else {
              print('No output URL found in successful response');
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
        final directory = await getApplicationDocumentsDirectory();
        final String folderPath = '${directory.path}/user_images';
        
        // Create folder if it doesn't exist
        final folder = Directory(folderPath);
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }
        
        // Save the image with a unique name
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final String imagePath = '$folderPath/user_level_${level}_${variationTag ?? timestamp}.jpg';
        final File file = File(imagePath);
        await file.writeAsBytes(response.bodyBytes);
        
        debugPrint('Image saved: $imagePath');
        return imagePath;
      } else {
        debugPrint('Failed to download image: ${response.statusCode}');
        return null;
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
    // For now, we'll use the environment variable
    // TODO: Implement a more flexible solution like flutter_dotenv
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

    for (int i = 0; i < variations.length; i++) {
      try {
        final String? imagePath = await generateHunterImage(
          faceImagePath,
          1,
          customPrompt: variations[i],
        );
        if (imagePath != null) {
          imagePaths.add(imagePath);
        }
      } catch (e) {
        print('Error generating image variation ${i + 1}: $e');
      }
    }

    return imagePaths;
  }
} 