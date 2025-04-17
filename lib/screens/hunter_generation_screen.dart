import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solo_leveling_app/services/ai_image_service.dart';
import 'package:solo_leveling_app/services/background_image_service.dart';
import 'package:solo_leveling_app/screens/dashboard_screen.dart';
import 'package:solo_leveling_app/services/storage_service.dart';

class HunterGenerationScreen extends StatefulWidget {
  final String faceImagePath;
  
  const HunterGenerationScreen({
    Key? key,
    required this.faceImagePath,
  }) : super(key: key);
  
  @override
  _HunterGenerationScreenState createState() => _HunterGenerationScreenState();
}

class _HunterGenerationScreenState extends State<HunterGenerationScreen> {
  bool _isGenerating = true;
  bool _isError = false;
  String _statusMessage = "Analyzing your hunter potential...";
  late Timer _messageTimer;
  int _messageIndex = 0;
  
  final List<String> _statusMessages = [
    "Analyzing your hunter potential...",
    "Creating your E-Rank hunter profile...",
    "Calculating your Stats...",
    "Calibrating your power level...",
    "Almost there, finalizing your hunter profile...",
  ];
  
  @override
  void initState() {
    super.initState();
    _startMessageRotation();
    _generateFirstHunterImage();
  }
  
  void _startMessageRotation() {
    _messageTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _statusMessages.length;
          _statusMessage = _statusMessages[_messageIndex];
        });
      }
    });
  }
  
  @override
  void dispose() {
    _messageTimer.cancel();
    super.dispose();
  }
  
  Future<void> _generateFirstHunterImage() async {
    try {
      setState(() {
        _isGenerating = true;
        _isError = false;
        _statusMessage = "Initializing hunter image...";
      });

      // Try to use the direct Replicate API first - this has built-in fallback to mock if API fails
      final imagePath = await AIImageService.generateHunterImage(widget.faceImagePath, 1);
      
      if (imagePath != null) {
        setState(() {
          _statusMessage = "Saving your hunter profile...";
        });

        // Update the user's status to indicate they have custom images
        await StorageService.updateUserCustomImageStatus(true);
        
        setState(() {
          _statusMessage = "Preparing your dashboard...";
        });

        // Navigate to dashboard
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DashboardScreen(),
            ),
          );
        }
      } else {
        // Error generating the image
        setState(() {
          _isGenerating = false;
          _isError = true;
          _statusMessage = "Failed to create hunter profile. Please try again.";
        });
      }
    } catch (e) {
      debugPrint('Error generating first hunter image: $e');
      setState(() {
        _isGenerating = false;
        _isError = true;
        _statusMessage = "An error occurred. Please try again later.";
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/2.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.darken,
            ),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'CREATING YOUR HUNTER PROFILE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 40),
              
              if (_isGenerating) ...[
                // Show loading animation
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ] else if (_isError) ...[
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 80,
                ),
                
                const SizedBox(height: 20),
                
                const Text(
                  'Error creating hunter profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                ElevatedButton(
                  onPressed: () {
                    // Navigate to dashboard without the hunter image
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DashboardScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Continue Without Hunter Profile',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 