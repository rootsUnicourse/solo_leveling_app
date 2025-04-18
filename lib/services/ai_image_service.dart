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

  // Level-specific prompts for Solo Leveling progression
  static const Map<int, String> _levelPrompts = {
    1: 'A young Korean man in his early 20s, wearing torn basic hunter gear, standing at the mouth of a dimly lit dungeon tunnel. His stance is tense and defensive, knees slightly bent and shoulders trembling from exhaustion. Dirt and blood smear his face, and his wide eyes reflect fear and desperation—yet a spark of determination burns within them. The flickering torchlight casts long shadows behind him, hinting at the darkness and danger surrounding the weakest E-rank hunter at the start of his journey.',
    2: 'E-rank hunter with basic shadow manipulation, subtle dark energy around hands, wearing reinforced combat gear, determined expression, standing in a combat stance, dark atmosphere, mysterious lighting, similar to early dungeon exploration scenes',
    3: 'E-rank hunter with visible shadow control, dark energy forming basic shapes, wearing tactical armor, focused expression, ready for battle, dramatic lighting, action pose, reminiscent of early gate raids',
    4: 'E-rank hunter with enhanced shadow manipulation, shadows forming basic weapons, wearing advanced tactical gear, confident stance, dark energy aura, battle-ready pose, similar to early shadow soldier summoning',
    5: 'A young Korean man in his early 20s, appearing sturdier and more confident in a shallow dungeon chamber littered with the remains of low-level monsters. His cheap armor is still modest, but his grip on a gleaming dagger is steady and sure. He stands catching his breath over a fallen beast, chest heaving from exertion, and a hint of a satisfied smile tugs at his lips. Soft blue light from a magical lantern dances across his face, revealing newfound resolve in his eyes as the once-weak hunter begins tapping into his awakened potential.',
    6: 'D-rank hunter with complete shadow armor set, shadows forming complex shapes, wearing advanced combat gear, powerful aura, battle-ready stance, dark energy swirling, reminiscent of the Demon Castle arc',
    7: 'D-rank hunter with mastery over shadows, complete shadow armor set, shadows forming weapons and armor, muscular build, confident expression, dark energy radiating, similar to the Job Change Quest arc',
    8: 'C-rank hunter with advanced shadow manipulation, shadows forming complex armor and weapons, wearing elite combat gear, powerful presence, battle stance, dark energy aura, reminiscent of the Retesting Rank arc',
    9: 'B-rank hunter with expert shadow control, shadows forming intricate armor patterns, wearing high-level combat gear, commanding presence, battle-ready stance, dark energy swirling, similar to the Jeju Island arc',
    10: 'A young Korean man in his early 20s, his frail physique transformed noticeably—lean muscle now tones his frame under a fitted black combat jacket as he strides through a dungeon corridor. He wields dual daggers, their blades glinting in the eerie green glow of subterranean moss. His once fearful expression has hardened into a look of fierce determination, eyes locked forward as a hulking beast looms ahead. The air around him crackles with anticipation; motes of dust swirl at his boots, and even the shadows seem to bend away from the rising D-rank hunter who refuses to back down.',
    11: 'A-rank hunter with supreme shadow control, shadows forming intricate armor and weapons, wearing legendary combat gear, commanding presence, battle-ready stance, dark energy aura, similar to the Monarchs\' War arc',
    12: 'A-rank hunter with perfect shadow mastery, shadows forming divine armor and weapons, wearing mythical combat gear, godlike presence, battle stance, dark energy swirling, reminiscent of the final battle scenes',
    13: 'S-rank hunter with ultimate shadow control, shadows forming divine armor and weapons, wearing legendary combat gear, supreme presence, battle-ready stance, dark energy radiating, similar to the Shadow Monarch\'s power',
    14: 'S-rank hunter with absolute shadow mastery, shadows forming godlike armor and weapons, wearing mythical combat gear, divine presence, battle stance, dark energy aura, reminiscent of the final transformation',
    15: 'A young Korean man in his early 20s, exuding the poise of a seasoned fighter. He stands amid the aftermath of a fierce battle in a cavernous dungeon hall, the hulking corpse of an orc chieftain collapsed at his feet. His dark combat attire is splattered with monster blood, and he casually twirls a blood-stained dagger in one hand after dispatching his enemy with lethal precision. His stance is relaxed yet ready—a confident smirk on his lips and not a trace of the old fear in his eyes—as embers from fallen torches cast dancing light on the C-rank hunter\'s formidable figure.',
    20: 'A young Korean man in his early 20s, charging head-on toward a towering troll deep within a dungeon\'s core. His twin daggers gleam with faint magical light as he lunges, effortlessly evading a massive stone club that crashes into the ground where he stood mere moments before. Muscles coiled and eyes sharp with focus, he retaliates with blinding speed—a flurry of slashes carving into the beast and sending it reeling. The once-timid young man now radiates unshakable confidence; a subtle aura of dark energy begins to pulse around him, whipping at the edges of his black coat and making the very shadows tremble with his burgeoning B-rank power.',
    25: 'A young Korean man in his early 20s, his prowess grown so much that even seasoned hunters look to him for protection. In a high-level dungeon\'s boss chamber, he plants himself between a wounded ally sprawled on the ground and a towering, snarling stone golem about to strike. His black battle outfit is now reinforced with pieces of magical armor; though scratched and dusty from the fight, he stands unyielding, twin daggers crossed defiantly to block the monster\'s massive blow. His expression remains calm and resolute, eyes burning with a quiet fury as a dark haze gathers around his feet—shadowy tendrils coiling outward as if responding to the near A-rank warrior\'s indomitable will.',
    30: 'A young Korean man in his early 20s, having ascended to the threshold of S-rank strength, capable of feats that astonish veteran hunters. In a blur of motion, he single-handedly cuts through a pack of elite dungeon beasts that would have overwhelmed entire teams before. For the final blow, he springs high into the air above a colossal ogre king, crossing his twin daggers as they crackle with dark energy and executing an X-shaped slash that cleaves the monster in two and splits the stone floor beneath it. He lands lightly amid settling dust and the dissolving ash of defeated foes, silhouetted against the dungeon\'s eerie crystal light as he stands radiating quiet menace. His expression is cold and focused—barely a hint of exertion on his face—while an inky black aura now visibly pulses from his body, foreshadowing the great power he is destined to wield.',
    35: 'A young Korean man in his early 20s, carrying himself with quiet, unshakable confidence as he senses an ominous new challenge on the horizon. He strides into the pitch-black entrance of a hidden dungeon—a special quest only he can perceive—without hesitation. Colossal stone statues stand guard in the cavernous temple hall that unfolds before him, their carved eyes seeming to watch the lone hunter in eerie silence. He pauses at the center of the hall with daggers drawn, his face calm and determined, as a faint violet glow from unseen runes casts an otherworldly light on his features. The air is heavy with anticipation and his very shadow pools darker and larger beneath him, as if sensing that the final barrier to his true power is about to be shattered.',
    40: 'A young Korean man in his early 20s, reborn as something beyond human. In the aftermath of his brutal Job Change Quest, he kneels in the center of a ruined stone temple, surrounded by the shattered remnants of the giant statues he somehow overcame. Blood trickles from cuts on his arms and his chest heaves, but a fierce, triumphant light burns in his eyes as he slowly pushes himself to his feet. An oppressive black aura now rolls off him like living smoke, tinged with flickers of violet—the very shadows in the hall writhe and seem to bow toward their new master. His dagger crackles with dark energy in his grip, and the once-silent chamber trembles as he ascends, heralding the rise of the Shadow Monarch within what was once the weakest of hunters.',
    45: 'A young Korean man in his early 20s, fully embracing his new identity as the commander of shadows. He now dons a sleek black coat that flutters dramatically behind him as he stands in a dungeon antechamber, flanked by two of his summoned dark knights. One is a lithe, red-plumed swordsman in jagged ebon armor, and the other a towering, horn-helmeted giant of a knight—both radiating an eerie blue glow from within their visors as they await their liege\'s command. He holds one hand aloft mid-summon, tendrils of darkness curling around his arm, while his other hand casually twirls a dagger at his side. His expression is calm and authoritative, almost regal, as cold light from the portal reflects off his eyes. Every shifting shadow at his feet moves in accordance with his will, affirming the rise of an S-rank hunter who commands an army of darkness.',
    50: 'A young Korean man in his early 20s, braving the infamous Red Gate—a lethal dungeon that has stranded him in an icy, otherworldly forest under a blood-red sky. In this frozen realm, snow blankets the ground and each breath escapes his lips as a puff of white mist. He wears a heavy white fur cloak over his black armor, taken from a slain beast, and stands protectively close to a trembling survivor he\'s sworn to shield from the elements. His eyes burn with fierce resolve even as frost gathers in his dark hair; around him, shadowy beasts prowl at the edge of the tree line—a colossal shadow bear and wolf-like wraiths ready to strike at his command. Despite the numbing cold, an aura of dark power pulses off him like a black flame, defying the freezing air and casting an eerie warmth across the snow as the Shadow Monarch\'s power asserts itself in this frozen hell.',
    55: 'A young Korean man in his early 20s, having stormed the gates of the Demon Castle, pushing his powers to new heights in that hellish domain. He strides through the Demon King\'s grand throne hall, a vast chamber wreathed in roaring flames and flickering shadows. The charred remains of vanquished demons lie scattered across obsidian tiles, and the colossal, horned Demon King himself lies fallen behind him, his massive form disintegrating into glowing embers. He stands tall and unbowed amid the chaos, clad in battle-scorched black armor etched with faintly glowing crimson runes and gripping a jagged obsidian blade crackling with residual demonic power—a trophy torn from his defeated foe. Bathed in the orange glow of hellfire, his eyes burn with cold fury and triumph as ash swirls in the heat-distorted air. He exudes an aura of absolute dominance, the undisputed master of this infernal domain and every shadow within it.',
    60: 'A young Korean man in his early 20s, emerging triumphant on the blood-soaked shores of Jeju Island after the epic battle against the monstrous ant colony. Around him on the beach lie the colossal carcasses of ant beasts—their black exoskeletons cracked and smoldering, half-buried in sand and surf under a stormy sky. He stands at the center of the carnage with his ebony coat tattered and drenched in monster blood, his chest rising and falling with steady breaths as the adrenaline of battle fades. Before him kneels a towering humanoid ant with a crown-like carapace—the shadow of the defeated Ant King, reborn as his loyal servant. Its insectoid eyes glow an ethereal blue as it bows its head deeply. A shaft of sunlight breaks through the smoky clouds to illuminate his hardened yet relieved expression as he gently extends a hand to acknowledge his new shadow general. With waves crashing behind him and surviving shadow soldiers gathering around, the savior of Jeju Island stands victorious, fully stepping into his role as a legendary Shadow Monarch.',
    65: 'A young Korean man in his early 20s, standing at the epicenter of the ultimate war between the superpowered Monarchs as humanity\'s last hope. On the ruined streets of a city besieged by otherworldly forces, he faces off against two enemy Monarchs amid toppled skyscrapers and raging fires. Colossal shadow creatures from his army clash with the invaders: a resurrected giant swings a wrecking-ball fist into a scaly behemoth, and above them a dark wyvern-like dragon shadow duels in midair with a frost-winged monstrosity summoned by the enemy. At the center of the battlefield, he charges forward, wielding a massive black blade formed from pure shadow, aiming directly for the snarling Beast Monarch that towers in his path. His eyes blaze with furious resolve as a storm of black aura spirals around him, shattering windows and tossing debris with its force. Orchestrating his legion with imperious gestures, he fights like a true Shadow Monarch, turning the tide of this climactic Monarch War through sheer will and unrivaled power.',
    70: 'A young Korean man in his early 20s, having ascended to the very pinnacle of his might, fully manifesting as a godlike Shadow Monarch. Under a storm-black sky torn open by dimensional rifts, he stands unflinchingly against the Dragon Monarch Antares on a battlefield of utter ruin—a colossal crimson dragon rearing up before him and bathing the shattered city in hellish flames. His appearance is truly otherworldly: he is clad in ornate obsidian armor wreathed in swirling shadows, with great black wings unfurled behind him and a crown of crackling dark energy hovering above his head. His eyes glow with a fierce golden light, and waves of dark aura radiate from him, cracking the very earth beneath his feet. An endless legion of shadow soldiers stretches behind him—even a titanic shadow dragon coils in the sky at his side—all awaiting their monarch\'s command as he readies to deliver final judgment. In this ultimate moment, he is no longer merely a hunter but the almighty sovereign of darkness, a Shadow Monarch standing toe-to-toe with a dragon god as the fate of two worlds hangs in the balance.'
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
        'image': faceImageDataUrl,
        'ip_adapter_scale': 0.65,
        'sdxl_weights': 'animagine-xl-30',
      });

      print('Starting image generation with face image and prompt: $prompt');
      print('Using InstantID model for face preservation');
      
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