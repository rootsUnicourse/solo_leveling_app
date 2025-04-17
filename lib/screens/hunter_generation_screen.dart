import 'package:flutter/material.dart';
import 'package:solo_leveling_app/services/ai_image_service.dart';
import 'package:solo_leveling_app/screens/hunter_profile_screen.dart';
import 'package:solo_leveling_app/services/storage_service.dart';
import 'dart:io';

class HunterGenerationScreen extends StatefulWidget {
  final String faceImagePath;

  const HunterGenerationScreen({
    Key? key,
    required this.faceImagePath,
  }) : super(key: key);

  @override
  State<HunterGenerationScreen> createState() => _HunterGenerationScreenState();
}

class _HunterGenerationScreenState extends State<HunterGenerationScreen> {
  bool _isGenerating = false;
  List<String> _generatedImages = [];
  int? _selectedImageIndex;

  Future<void> _generateMultipleImages() async {
    setState(() {
      _isGenerating = true;
      _generatedImages = [];
      _selectedImageIndex = null;
    });

    try {
      final List<String> imagePaths = await AIImageService.generateMultipleErankImages(widget.faceImagePath);
      
      if (imagePaths.isNotEmpty) {
        setState(() {
          _generatedImages = imagePaths;
          _isGenerating = false;
        });
      } else {
        setState(() {
          _isGenerating = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate images. Please try again.')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _selectImage(int index) {
    setState(() {
      _selectedImageIndex = index;
    });
  }

  void _confirmSelection() async {
    if (_selectedImageIndex == null) return;

    try {
      final String selectedImagePath = _generatedImages[_selectedImageIndex!];
      await StorageService.updateUserCustomImageStatus(true);
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HunterProfileScreen(
            faceImagePath: widget.faceImagePath,
            hunterImagePath: selectedImagePath,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving selection: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Hunter Look'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isGenerating)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating your hunter variations...'),
                  ],
                ),
              )
            else if (_generatedImages.isEmpty)
              Center(
                child: ElevatedButton(
                  onPressed: _generateMultipleImages,
                  child: const Text('Generate Hunter Variations'),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _generatedImages.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _selectImage(index),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _selectedImageIndex == index
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_generatedImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImageIndex != null)
                      ElevatedButton(
                        onPressed: _confirmSelection,
                        child: const Text('Confirm Selection'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
} 