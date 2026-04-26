import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;

  File? selectedImage;
  String? resultLabel;
  double confidence = 0.0;
  bool isScanning = false;

  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _setupCamera();
  }

  Future<void> _setupCamera() async {
    if (widget.cameras.isEmpty) return;

    final CameraDescription backCamera = widget.cameras.firstWhere(
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

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image == null) return;

    setState(() {
      selectedImage = File(image.path);
      resultLabel = null;
    });

    await _fakeAnalyze('unripe', 0.88);
  }

  Future<void> _captureFromCamera() async {
    if (_cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;

    try {
      final XFile image = await _cameraController!.takePicture();

      setState(() {
        selectedImage = File(image.path);
        resultLabel = null;
      });

      await _fakeAnalyze('ready', 0.93);
    } catch (e) {
      debugPrint('Camera capture error: $e');
    }
  }

  Future<void> _fakeAnalyze(String label, double score) async {
    setState(() {
      isScanning = true;
      resultLabel = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      isScanning = false;
      resultLabel = label;
      confidence = score;
    });
  }

  void _clearImage() {
    setState(() {
      selectedImage = null;
      resultLabel = null;
      confidence = 0.0;
      isScanning = false;
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _cameraController?.dispose();
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

  Widget _buildCornerFrame() {
    const double cornerLength = 34;
    const double thickness = 4;
    const Color frameColor = Color(0xFF88FF9B);

    Widget corner({
      required Alignment alignment,
      required BorderRadius borderRadius,
      required double? top,
      required double? bottom,
      required double? left,
      required double? right,
      required bool showTop,
      required bool showBottom,
      required bool showLeft,
      required bool showRight,
    }) {
      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: Align(
          alignment: alignment,
          child: SizedBox(
            width: cornerLength,
            height: cornerLength,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border(
                  top: showTop
                      ? const BorderSide(color: frameColor, width: thickness)
                      : BorderSide.none,
                  bottom: showBottom
                      ? const BorderSide(color: frameColor, width: thickness)
                      : BorderSide.none,
                  left: showLeft
                      ? const BorderSide(color: frameColor, width: thickness)
                      : BorderSide.none,
                  right: showRight
                      ? const BorderSide(color: frameColor, width: thickness)
                      : BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            corner(
              alignment: Alignment.topLeft,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
              top: 20,
              left: 20,
              bottom: null,
              right: null,
              showTop: true,
              showBottom: false,
              showLeft: true,
              showRight: false,
            ),
            corner(
              alignment: Alignment.topRight,
              borderRadius: const BorderRadius.only(topRight: Radius.circular(10)),
              top: 20,
              right: 20,
              bottom: null,
              left: null,
              showTop: true,
              showBottom: false,
              showLeft: false,
              showRight: true,
            ),
            corner(
              alignment: Alignment.bottomLeft,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
              ),
              bottom: 110,
              left: 20,
              top: null,
              right: null,
              showTop: false,
              showBottom: true,
              showLeft: true,
              showRight: false,
            ),
            corner(
              alignment: Alignment.bottomRight,
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(10),
              ),
              bottom: 110,
              right: 20,
              top: null,
              left: null,
              showTop: false,
              showBottom: true,
              showLeft: false,
              showRight: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            _buildCornerFrame(),
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
          onTap: isScanning ? null : _captureFromCamera,
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
                  color: isScanning ? Colors.white38 : Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final bool showLiveHint = selectedImage == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avocado Ripeness Detector'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6EC),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFD6E5D0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildPreviewArea(),
                    ),

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
                onPressed: isScanning ? null : _pickFromGallery,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text(
                  'Choose from gallery',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (resultLabel != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                  );
                },
                child: ResultCard(
                  key: ValueKey(resultLabel),
                  label: resultLabel!,
                  confidence: confidence,
                ),
              ),
          ],
        ),
      ),
    );
  }
}