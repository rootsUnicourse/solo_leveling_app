import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras.isNotEmpty) {
        // Use the front camera by default
        final frontCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );
        
        _controller = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        
        await _controller!.initialize();
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }
  
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }
    
    try {
      setState(() {
        _isCapturing = true;
      });
      
      final XFile picture = await _controller!.takePicture();
      
      // Compress the image
      final compressedImagePath = await _compressImage(picture.path);
      
      // Return the compressed image path
      if (mounted) {
        Navigator.of(context).pop(compressedImagePath);
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }
  
  Future<String> _compressImage(String imagePath) async {
    final directory = await getTemporaryDirectory();
    final targetPath = path.join(directory.path, 'compressed_${path.basename(imagePath)}');
    
    final result = await FlutterImageCompress.compressAndGetFile(
      imagePath,
      targetPath,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    
    return result?.path ?? imagePath;
  }
  
  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      
      if (image != null) {
        // Compress the image
        final compressedImagePath = await _compressImage(image.path);
        
        // Return the compressed image path
        if (mounted) {
          Navigator.of(context).pop(compressedImagePath);
        }
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: Center(
              child: ClipRect(
                child: Transform.scale(
                  scale: _controller!.value.aspectRatio / MediaQuery.of(context).size.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
          
          // Overlay with instructions
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: Colors.black.withOpacity(0.5),
              child: const Text(
                'Position your face in the center of the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Face outline guide
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          
          // Bottom controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                IconButton(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library, color: Colors.white, size: 30),
                ),
                
                // Capture button
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Switch camera button
                IconButton(
                  onPressed: () async {
                    if (_cameras.length > 1) {
                      final currentLensDirection = _controller!.description.lensDirection;
                      CameraDescription newCamera;
                      
                      if (currentLensDirection == CameraLensDirection.front) {
                        newCamera = _cameras.firstWhere(
                          (camera) => camera.lensDirection == CameraLensDirection.back,
                        );
                      } else {
                        newCamera = _cameras.firstWhere(
                          (camera) => camera.lensDirection == CameraLensDirection.front,
                        );
                      }
                      
                      if (_controller != null) {
                        await _controller!.dispose();
                      }
                      
                      _controller = CameraController(
                        newCamera,
                        ResolutionPreset.medium,
                        enableAudio: false,
                      );
                      
                      await _controller!.initialize();
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
          
          // Cancel button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
} 