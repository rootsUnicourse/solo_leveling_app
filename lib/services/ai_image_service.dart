import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AIImageService {
  // Use the standard predictions endpoint with model version
  static const String _apiUrl = 'https://api.replicate.com/v1/predictions';
  
  // Model version IDs
  static const String _modelVersionAnimagine = '7af46ee494f1cf196d49a8592737f4eb789e34a5a995751b23a869d19f5dc2ba';
  static const String _modelVersionInstantID = '11219f80ba03ca1ce78194191ffa4fc74f7c1afeef50df95f477aa66f2f65bc5';
  
  // Runtime model selection
  static const bool kUseInstantID = true; // Enable InstantID to use face images
  static const String _modelVersion = kUseInstantID ? _modelVersionInstantID : _modelVersionAnimagine;
  
  // Fixed seed for consistent progression
  static const int _fixedSeed = 42;
  
  // Toggle for stronger anime stylization
  static const bool kPureAnime = true;
  static double get _animeScale => kPureAnime ? 0.55 : 0.8;
  
  // Gradually decrease face lock strength as level increases, with stronger 2D bias
  static double _animeScaleFor(int lvl) => (0.18 - lvl * 0.003).clamp(0.08, 0.18);
  
  // Valid anime checkpoint from Replicate's allowed list - exact name
  static const String _animeCheckpoint = 'animagine-xl-30';  // exact name from Replicate's enum
  
  // ── Improved prompt style for stronger anime look ──
  static const String _promptPrefix =
    // strong anime keywords first, ordered by "power"
    'anime illustration, 2d illustration, cel-shaded, masterpiece, best quality, ultra-detailed, anime screencap, crisp line-art, '
    'vibrant colors, 1person, head-and-shoulders, looking at viewer';
  
  // Helper function to remove null values from map
  static Map<String, dynamic> _cleanInput(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(raw)..removeWhere((k, v) => v == null);
  }

  // Updated milestone prompts for Solo Leveling character progression
  static const Map<int, String> _milestonePrompts = {
    1 : 'the user\'s face with a calm determined expression, wearing a simple blue hoodie and jeans (casual style), very faint purple glow in the eyes, slight wisps of blue-black mist around the shoulders, Solo Leveling inspired',
    5 : 'the user\'s face with a confident smirk, wearing a simple t-shirt with high collar that fully covers chest and shoulders (casual attire), faint purple gleam in the eyes, a barely visible purple aura flickering around the head, wisps of shadow mist, Solo Leveling inspired',
    10: 'the user\'s face with a focused serious expression, wearing a dark hoodie with high collar that fully covers chest and shoulders, eyes lightly glowing purple, soft purple aura beginning to swirl at the shoulders, thin blue-black tendrils of shadow forming behind, Solo Leveling inspired',
    15: 'the user\'s face with a determined gaze, dressed in a black jacket with high collar that fully covers chest and shoulders, eyes shining with a soft purple glow, moderate purple aura enveloping the upper torso, blue-black shadow mist curling around the neck, Solo Leveling inspired',
    20: 'the user\'s face with a fierce glare, wearing a sleek dark leather jacket with high collar that fully covers chest and shoulders, eyes bright purple, a strong pulsing purple aura around the head and shoulders, dark blue-black shadow tendrils swirling intensely, Solo Leveling inspired',
    25: 'the user\'s face with a narrowed, intense look, dressed in a fitted black jacket with high collar that fully covers chest and shoulders, subtle purple accents, eyes glowing deep purple, vibrant purple aura radiating outward, thick blue-black shadow mist swirling wildly around the bust, Solo Leveling inspired',
    30: 'the user\'s face with a serious, commanding expression, wearing a dark leather coat with high collar that fully covers chest and shoulders (no armor plating yet), eyes fully purple and blazing, brilliant purple aura flaring behind, heavy blue-black shadow tendrils twisting around the shoulders, Solo Leveling inspired',
    35: 'the user\'s face with a smirk of confidence, clad in a sleek black coat with high collar that fully covers chest and shoulders, eyes glowing bright purple, intense violet aura now radiating around the head, swirling inky-blue shadow smoke curling behind, Solo Leveling inspired',
    40: 'the user\'s face with a bold, almost aggressive grin, wearing a dark coat with high collar that fully covers chest and shoulders, eyes intensely purple-bright, powerful purple aura pulsating around the bust, thick blue-black shadow tendrils fanning out behind, Solo Leveling inspired',
    45: 'the user\'s face with a commanding glare, dressed in a black leather jacket with high collar that fully covers chest and shoulders (no visible weapon), eyes blazing bright purple, brilliant purple aura and energy crackles visible, swirling black-purple shadow mist and tendrils enveloping the shoulders, Solo Leveling inspired',
    50: 'the user\'s face with a ferocious, determined scowl, wearing a fitted black coat with high collar that fully covers chest and shoulders, subtle design, eyes glowing vibrant purple, intense purple aura surging around him, thick bluish-black shadow fog swirling and dancing behind the bust, Solo Leveling inspired',
    55: 'the user\'s face with a savage grin and narrowed eyes, dressed in a black leather trench coat with high collar that fully covers chest and shoulders, eyes shining piercing purple, overwhelming purple aura and crackling energy around his form, heavy dark shadow mist with visible tendrils clinging to the shoulders, Solo Leveling inspired',
    60: 'the user\'s face with an intense, almost predatory stare, wearing a high-collared black coat with subtle shadow-armor plating on the shoulders that fully covers chest and shoulders, eyes glowing luminous purple, raging purple aura enveloping the upper body, thick blue-black shadow armor fragments and mist swirling fiercely around, Solo Leveling inspired',
    65: 'the user\'s face with a brutal confident smile, outfitted in a dark coat with high collar that fully covers chest and shoulders, emerging shadow-armor details on chest and shoulders, eyes blazing bright purple with dark sclera, overwhelming purple aura and shadow energy radiating, black-blue tendrils of shadow swirling like wings behind, Solo Leveling inspired',
    70: 'the user\'s face with a fearless, commanding expression, fully in a dark outfit with high collar that fully covers chest and shoulders, prominent shadow-armor plating on shoulders, eyes fully glowing intense purple, colossal purple-black aura swirling violently, massive blue-black shadow mist swirling like spikes behind him, Solo Leveling inspired'
  };
  
  // Helper picks the last milestone ≤ level so you can still call with any level
  static String _promptFor(int level) {
    final keys = _milestonePrompts.keys.where((k) => k <= level).toList()..sort();
    final levelPrompt = keys.isEmpty ? _milestonePrompts[1]! : _milestonePrompts[keys.last]!;
    return '$_promptPrefix, $levelPrompt.';
  }

  // Updated negative prompt to strongly avoid photorealism and NSFW content
  static const String _negativePrompt =
    'nsfw, nude, nudity, exposed skin, lingerie, cleavage, suggestive, erotic, bare shoulders, '
    'photorealistic, realistic skin, photographic, real photo, 3d, realistic, photo, photographic, skin pores, hyperrealistic, '
    'render, cgi, doll, plastic, blurry, lowres, watermark, text, logo, '
    'extra limbs, hands, arms, weapon, background, out-of-frame, bad anatomy, '
    'worst quality, distorted, deformed, ugly, grainy';

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

      // Use custom prompt if provided, otherwise use the level-specific prompt using the helper
      const _angles = ['¾ view left', '¾ view right', 'front view', 'slight low-angle'];
      const _lights = ['cool rim-light', 'warm back-light', 'dramatic top-light', 'purple under-glow'];
      final suffix = '${_angles[level % 4]}, ${_lights[level % 4]}';
      final prompt = '${customPrompt ?? _promptFor(level)}, $suffix';

      // Higher resolution for top-tier levels
      final imageSize = level >= 60 ? 1024 : 768;
      
      // Generate unique, deterministic seed per level
      final seed = (level * 7919) % 2147483647; // 2^31-1

      // Create base input for the API
      final Map<String, dynamic> input = {
        'prompt': '$prompt, wearing a high-collar black coat that fully covers chest and shoulders',
        'negative_prompt': _negativePrompt,
        'width': imageSize,
        'height': imageSize,
        'num_inference_steps': 30,
        'guidance_scale': 7.5,
        'seed': seed,
        'sdxl_weights': _animeCheckpoint, // Using exact value from allowed list
      };

      // Determine model version and whether to add face image data
      String modelVersion = _modelVersionAnimagine;
      
      // If face image is provided, use InstantID
      if (faceImagePath != null && faceImagePath.isNotEmpty) {
        // Preprocess the face image
        final faceImageFile = File(faceImagePath);
        final faceImageBytes = await faceImageFile.readAsBytes();
        final processedFaceBytes = await _preprocessImage(Uint8List.fromList(faceImageBytes));
        
        final faceImageBase64 = base64Encode(processedFaceBytes);
        final faceMime = faceImagePath.toLowerCase().endsWith('.jpg') || faceImagePath.toLowerCase().endsWith('.jpeg') 
            ? 'image/jpeg' 
            : 'image/png';
        final faceImageDataUrl = 'data:$faceMime;base64,$faceImageBase64';
        
        // Add face image to input
        input['image'] = faceImageDataUrl;
        input['ip_adapter_scale'] = _animeScaleFor(level);
        
        // Use InstantID model
        modelVersion = _modelVersionInstantID;
        
        debugPrint('Starting image generation with face image');
        debugPrint('Using InstantID model with anime stylization');
      } else {
        // No face image, using regular Animagine model
        debugPrint('Starting image generation without face image');
        debugPrint('Using Animagine model with anime stylization');
      }

      // Clean up the input to remove null values
      final cleanedInput = _cleanInput(input);
      
      // Make the API call to Replicate with Prefer: wait header for synchronous mode
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Prefer': 'wait', // Use synchronous mode instead of wait=60
        },
        body: jsonEncode({
          'version': modelVersion,
          'input': cleanedInput
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 202) {
        debugPrint('Failed to start prediction: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        
        // If we get a 422 error about sdxl_weights, throw an exception instead of removing the parameter
        if (response.statusCode == 422 && response.body.contains('sdxl_weights')) {
          throw Exception(
            'Invalid sdxl_weights: "$_animeCheckpoint".\n'
            'Choose one of the allowed values listed in the response body.'
          );
        }
        
        throw Exception('Failed to start prediction: ${response.statusCode}');
      }

      final prediction = jsonDecode(response.body);
      debugPrint('Prediction started: ${prediction['id']}');
      debugPrint('Initial status: ${prediction['status']}');
      
      // If the prediction is already complete, get the output URL
      if (prediction['status'] == 'succeeded' && prediction['output'] != null) {
        final resultUrl = prediction['output'][0];
        debugPrint('Image generation completed immediately. Output URL: $resultUrl');
        return await _downloadAndSaveImage(resultUrl, level, variationTag: 'immediate');
      }

      // If not complete (model still warming up), poll for the result with exponential backoff
      return await _pollForResult(prediction['id'], apiKey, level, faceImagePath: faceImagePath);
    } catch (e) {
      debugPrint('Error generating hunter image: $e');
      return null;
    }
  }
  
  // Poll the API for result with exponential backoff
  static Future<String?> _pollForResult(
    String predictionId,
    String apiKey,
    int level, {
    bool canRetryNSFW = true, // Allow only one retry for NSFW
    String? faceImagePath,    // Added parameter to pass face image path directly
  }) async {
    const terminal = {'succeeded', 'failed', 'canceled'};
    int delaySec = 2; // Fixed initial delay as integer

    for (var attempt = 1; attempt <= 10; attempt++) { // Reduced from 20 to 10 attempts
      debugPrint('Polling attempt $attempt/10 for prediction $predictionId');
      
      await Future.delayed(Duration(seconds: delaySec));
      delaySec = (delaySec * 1.6).toInt().clamp(2, 15); // Fixed integer calculation
      
      try {
        final response = await http.get(
          Uri.parse('$_apiUrl/$predictionId'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode != 200) continue; // network hiccup → try again
        
        final data = jsonDecode(response.body);
        final status = data['status'] as String;
        debugPrint('Current status: $status');
        
        if (status == 'succeeded') {
          final output = data['output'];
          
          // Handle both array and string output formats
          String? imageUrl;
          if (output is List && output.isNotEmpty) {
            imageUrl = output[0];
          } else if (output is String) {
            imageUrl = output;
          }
          
          if (imageUrl != null) {
            debugPrint('Image generation completed successfully!');
            return await _downloadAndSaveImage(imageUrl, level);
          } else {
            debugPrint('No output URL found in successful response');
            throw Exception('No output URL found in successful response');
          }
        }
        
        if (status == 'failed') {
          final err = data['error']?.toString() ?? 'unknown error';
          debugPrint('Image generation failed: $err');
          
          // Try a single extra attempt if it's NSFW and we haven't tried already
          if (canRetryNSFW && err.contains('NSFW') && faceImagePath != null) {
            debugPrint('NSFW detected - attempting one retry with stricter prompts');
            return await _retryWithSafePrompt(level, apiKey, err, faceImagePath);
          }
          
          throw Exception('Generation failed: $err');
        }
        
        if (status == 'canceled') {
          debugPrint('Image generation was canceled');
          throw Exception('Generation was canceled on the server');
        }
        
        // Otherwise it's still in progress, continue polling
        
      } catch (e) {
        if (e is Exception && (e.toString().contains('Generation failed') || 
            e.toString().contains('canceled'))) {
          // Re-throw terminal errors
          rethrow;
        }
        debugPrint('Error during polling: $e');
        // Re-throw all exceptions to break the polling loop
        rethrow;
      }
    }

    debugPrint('Image generation timed out after 10 attempts');
    throw Exception('Prediction timed-out after 10 attempts');
  }
  
  // Helper: retry with a safer prompt
  static Future<String?> _retryWithSafePrompt(
    int level,
    String apiKey,
    String originalError,
    String faceImagePath  // Direct parameter instead of preferences lookup
  ) async {
    debugPrint('NSFW flagged. Retrying with stricter negative prompt...');
    
    // Add extra explicit NSFW blockers beyond what's already in _negativePrompt
    final saferNegativePrompt = 
      '$_negativePrompt, extremely detailed nsfw content, private parts, '
      'lower body, upper body, torso';
    
    try {
      // Preprocess the face image
      final faceImageFile = File(faceImagePath);
      final faceImageBytes = await faceImageFile.readAsBytes();
      final processedFaceBytes = await _preprocessImage(Uint8List.fromList(faceImageBytes));
      
      final faceImageBase64 = base64Encode(processedFaceBytes);
      final faceMime = faceImagePath.toLowerCase().endsWith('.jpg') || faceImagePath.toLowerCase().endsWith('.jpeg') 
          ? 'image/jpeg' 
          : 'image/png';
      final faceImageDataUrl = 'data:$faceMime;base64,$faceImageBase64';

      // Use the level-specific prompt but with different seed and safer negative prompt
      const _angles = ['¾ view left', '¾ view right', 'front view', 'slight low-angle'];
      const _lights = ['cool rim-light', 'warm back-light', 'dramatic top-light', 'purple under-glow'];
      final suffix = '${_angles[level % 4]}, ${_lights[level % 4]}';
      final prompt = '${_promptFor(level)}, $suffix';
      
      final imageSize = level >= 60 ? 1024 : 768;
      
      // Use a different but still deterministic seed for retry
      final seed = ((level * 7919) + 100) % 2147483647;

      // Create the input with safer parameters
      final input = _cleanInput({
        'prompt': '$prompt, wearing a high-collar black coat that fully covers chest and shoulders, fully clothed, modest outfit',
        'negative_prompt': saferNegativePrompt,
        'width': imageSize,
        'height': imageSize,
        'num_inference_steps': 30,
        'guidance_scale': 7.5,
        'seed': seed,
        'image': faceImageDataUrl,
        'ip_adapter_scale': _animeScaleFor(level),
        'sdxl_weights': _animeCheckpoint, // Keep the anime checkpoint for NSFW retry
      });

      debugPrint('Starting safer image generation with adjusted prompt and stricter negative prompt');
      
      // Make the API call to Replicate
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Prefer': 'wait',
        },
        body: jsonEncode({
          'version': _modelVersion,
          'input': input
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 202) {
        debugPrint('Failed to start safer prediction: ${response.statusCode}');
        throw Exception('Failed to start safer prediction: ${response.statusCode}');
      }

      final prediction = jsonDecode(response.body);
      
      // If the prediction is already complete, get the output URL
      if (prediction['status'] == 'succeeded' && prediction['output'] != null) {
        final resultUrl = prediction['output'][0];
        debugPrint('Safer image generation completed immediately. Output URL: $resultUrl');
        return await _downloadAndSaveImage(resultUrl, level, variationTag: 'safer');
      }

      // If not complete, poll for the result but don't allow further NSFW retries
      return await _pollForResult(prediction['id'], apiKey, level, canRetryNSFW: false, faceImagePath: faceImagePath);
    } catch (e) {
      debugPrint('Error in safer image generation: $e');
      // Don't swallow the error during retry
      throw Exception('Failed to generate safer image: $e');
    }
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
        debugPrint('Failed to decode image');
        return imageBytes;
      }
      
      // Resize to 512x512
      final resized = img.copyResize(decoded, width: 512, height: 512);
      
      // Encode as JPEG with 80% quality
      return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
    } catch (e) {
      debugPrint('Error preprocessing image: $e');
      return imageBytes; // Fallback to original bytes
    }
  }

  static Future<List<String>> generateMultipleErankImages(String faceImagePath) async {
    final List<String> imagePaths = [];
    final List<String> variations = [
      "$_promptPrefix neutral expression, wearing a simple blue hoodie. Solo Leveling style, E-rank hunter appearance, no visible aura or effects, minimal styling.",
      "$_promptPrefix slight smile, wearing a simple dark jacket. Solo Leveling style, E-rank hunter appearance, very faint blue aura, clean lines.",
      "$_promptPrefix determined expression, wearing a casual outfit with hood. Solo Leveling style, E-rank hunter appearance, subtle styling."
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
        debugPrint('Error generating image variation ${i + 1}: $e');
      }
    }

    return imagePaths;
  }

  // Generate hunter images without face input
  static Future<List<String>> generateAutoHunterImages() async {
    final List<String> imagePaths = [];
    final List<String> variations = [
      "anime illustration, masterpiece, best quality, ultra-detailed, anime screencap, crisp line-art, vibrant colors, Solo Leveling style, young male E-rank hunter with neutral expression, black hair, dark brown eyes, wearing a simple blue hoodie, no visible aura or effects, minimal styling, ¾ view left, cool rim-light",
      "anime illustration, masterpiece, best quality, ultra-detailed, anime screencap, crisp line-art, vibrant colors, Solo Leveling style, young male E-rank hunter with slight smile, black hair, dark brown eyes, wearing a simple dark jacket, very faint blue aura, clean lines, front view, warm back-light",
      "anime illustration, masterpiece, best quality, ultra-detailed, anime screencap, crisp line-art, vibrant colors, Solo Leveling style, young male E-rank hunter with determined expression, black hair, dark brown eyes, wearing a casual outfit with hood, subtle styling, ¾ view right, dramatic top-light"
    ];

    // Create a directory for profile images if it doesn't exist
    final directory = await getApplicationDocumentsDirectory();
    final profileDir = Directory('${directory.path}/profile_images');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    for (int i = 0; i < variations.length; i++) {
      try {
        // Create API request for Replica without InstantID
        final apiKey = dotenv.env['REPLICATE_API_TOKEN'];
        if (apiKey == null) {
          debugPrint('Warning: REPLICATE_API_TOKEN is not set in environment variables');
          continue;
        }

        // Higher resolution for better quality
        const imageSize = 768;
        
        // Generate unique seed per variation
        final seed = ((i + 1) * 7919) % 2147483647; // 2^31-1

        // Create the input for the API with improved parameters for anime style portrait
        final input = _cleanInput({
          'prompt': variations[i],
          'negative_prompt': _negativePrompt,
          'width': imageSize,
          'height': imageSize,
          'num_inference_steps': 30,
          'guidance_scale': 7.5,
          'seed': seed,
          'sdxl_weights': _animeCheckpoint, // Using exact value from allowed list
        });

        debugPrint('Starting image generation for variation ${i + 1}');
        
        // Make the API call to Replicate with Prefer: wait header for synchronous mode
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'Prefer': 'wait', // Use synchronous mode instead of wait=60
          },
          body: jsonEncode({
            'version': _modelVersionAnimagine, // Use Animagine model since we don't need InstantID
            'input': input
          }),
        );

        if (response.statusCode != 201 && response.statusCode != 202) {
          debugPrint('Failed to start prediction: ${response.statusCode}');
          debugPrint('Response body: ${response.body}');
          continue;
        }

        final prediction = jsonDecode(response.body);
        debugPrint('Prediction started: ${prediction['id']}');
        
        // If the prediction is already complete, get the output URL
        if (prediction['status'] == 'succeeded' && prediction['output'] != null) {
          final resultUrl = prediction['output'][0];
          debugPrint('Image generation completed immediately. Output URL: $resultUrl');
          final downloadedPath = await _downloadAndSaveImage(resultUrl, 1, variationTag: 'option_${i + 1}');
          
          if (downloadedPath != null) {
            // Copy the generated image to the profile directory with a specific name
            final profileImagePath = '${profileDir.path}/profile_option_${i + 1}.jpg';
            await File(downloadedPath).copy(profileImagePath);
            imagePaths.add(profileImagePath);
            debugPrint('Profile image saved: $profileImagePath');
          }
        } else {
          // Poll for result
          final imageUrl = await _pollForResult(prediction['id'], apiKey, 1);
          if (imageUrl != null) {
            // Copy the generated image to the profile directory with a specific name
            final profileImagePath = '${profileDir.path}/profile_option_${i + 1}.jpg';
            await File(imageUrl).copy(profileImagePath);
            imagePaths.add(profileImagePath);
            debugPrint('Profile image saved: $profileImagePath');
          }
        }
      } catch (e) {
        debugPrint('Error generating image variation ${i + 1}: $e');
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