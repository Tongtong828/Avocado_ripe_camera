import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'model.dart';
import 'result.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({super.key, required this.cameras});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final ModelService _modelService = ModelService();

  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;

  File? selectedImage;
  String? resultLabel;
  double confidence = 0.0;
  bool isScanning = false;

  bool isModelLoading = true;
  String? modelError;

  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _setupCamera();
    _loadModel();
  }

  Future<void> _setupCamera() async {
    if (widget.cameras.isEmpty) return;

    final backCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _initializeControllerFuture = _cameraController!.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadModel() async {
    try {
      await _modelService.loadModel();
      if (!mounted) return;
      setState(() {
        isModelLoading = false;
        modelError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isModelLoading = false;
        modelError = 'Model failed to load: $e';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (isModelLoading || modelError != null) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image == null) return;

    setState(() {
      selectedImage = File(image.path);
      resultLabel = null;
      confidence = 0.0;
    });

    await _analyzeSelectedImage();
  }

  Future<void> _captureFromCamera() async {
    if (isModelLoading || modelError != null) return;
    if (_cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;

    try {
      final XFile image = await _cameraController!.takePicture();

      setState(() {
        selectedImage = File(image.path);
        resultLabel = null;
        confidence = 0.0;
      });

      await _analyzeSelectedImage();
    } catch (e) {
      debugPrint('Camera capture error: $e');
    }
  }

  Future<void> _analyzeSelectedImage() async {
    if (selectedImage == null) return;

    setState(() {
      isScanning = true;
      resultLabel = null;
      confidence = 0.0;
    });

    try {
      final prediction = await _modelService.predictImage(selectedImage!);

      if (!mounted) return;
      setState(() {
        isScanning = false;
        resultLabel = prediction.label;
        confidence = prediction.confidence;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isScanning = false;
        modelError = 'Inference failed: $e';
      });
    }
  }

  void _clearImage() {
    setState(() {
      selectedImage = null;
      resultLabel = null;
      confidence = 0.0;
      isScanning = false;
    });
  }

  void _closeResultOverlay() {
    setState(() {
      resultLabel = null;
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _cameraController?.dispose();
    _modelService.dispose();
    super.dispose();
  }

  Widget _buildPreviewArea() {
    if (selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.file(
          selectedImage!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    if (_cameraController == null) {
      return const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF6B7B68),
          ),
        ),
      );
    }

    return FutureBuilder(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox.expand(
              child: CameraPreview(_cameraController!),
            ),
          );
        }

        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  Widget _buildScanningLine() {
    return AnimatedBuilder(
      animation: _scanController,
      builder: (context, child) {
        final alignmentY = -0.78 + (_scanController.value * 1.56);

        return Align(
          alignment: Alignment(0, alignmentY),
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF7BFF8D),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xAA7BFF8D),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            _buildScanningLine(),
            Positioned(
              left: 20,
              right: 20,
              bottom: 118,
              child: Column(
                children: const [
                  Text(
                    'Please photograph your avocado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Align the fruit inside the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 26,
      child: Center(
        child: GestureDetector(
          onTap: isScanning || isModelLoading || modelError != null
              ? null
              : _captureFromCamera,
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.22),
              border: Border.all(
                color: Colors.white.withOpacity(0.65),
                width: 3,
              ),
            ),
            child: Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isScanning || isModelLoading)
                      ? Colors.white38
                      : Colors.white,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFF4A5C3E),
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (isModelLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8EE),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(child: Text('Loading model...')),
          ],
        ),
      );
    }

    if (modelError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          modelError!,
          style: const TextStyle(color: Color(0xFF9A2F2F)),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Model ready',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF476247),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final bool showLiveHint = selectedImage == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          _buildStatusBanner(),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6EC),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFD6E5D0)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: _buildPreviewArea()),
                  if (showLiveHint || isScanning) _buildLiveOverlay(),
                  if (selectedImage == null) _buildCaptureButton(),
                  if (selectedImage != null && !isScanning)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _clearImage,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: isScanning || isModelLoading || modelError != null
                  ? null
                  : _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from gallery'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avocado Ripeness Detector'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _buildMainContent(),
          if (resultLabel != null)
            ResultCardOverlay(
              label: resultLabel!,
              confidence: confidence,
              onClose: _closeResultOverlay,
            ),
        ],
      ),
    );
  }
}