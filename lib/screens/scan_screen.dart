import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ingridio/models/food_vision_result.dart';
import 'package:ingridio/models/scanned_ingredient.dart';
import 'package:ingridio/services/food_detection_service.dart';
import 'package:ingridio/screens/scan_result_screen.dart';
import 'package:permission_handler/permission_handler.dart';

enum _WebCameraInit { success, permissionDenied, exhausted }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.isActive, this.onClose});

  final bool isActive;

  /// Called when the user taps the close (X) button on the scan HUD.
  /// HomeScreen wires this to switch back to the Home tab.
  final VoidCallback? onClose;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const Color _primaryContainer = Color(0xFFF97316);
  static const String _kDefaultNoCameraMessage =
      'No camera found on this device';
  static const String _kWebCameraOpenFailedMessage =
      'Could not open the camera in the browser. Close other tabs or apps '
      'using the camera (video calls, Windows Camera), wait a few seconds, '
      'then try again—or use “Choose from gallery”.';

  CameraController? _controller;
  bool _initializing = false;
  bool _permissionDenied = false;
  bool _noCamera = false;
  String _noCameraMessage = _kDefaultNoCameraMessage;
  bool _isFlashOn = false;
  bool _capturing = false;
  static const FoodDetectionService _foodDetection = FoodDetectionService();

  int _cameraSession = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initializing = true;
      unawaited(_initCamera());
    }
  }

  @override
  void didUpdateWidget(ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      unawaited(_disposeCamera());
      return;
    }
    if (widget.isActive && !oldWidget.isActive) {
      setState(() {
        _initializing = true;
        _noCamera = false;
        _noCameraMessage = _kDefaultNoCameraMessage;
      });
      unawaited(_initCamera());
    }
  }

  Future<void> _releaseCameraHardware() async {
    final CameraController? c = _controller;
    _controller = null;
    if (c != null) {
      try {
        await c.dispose();
      } on Object catch (_) {}
    }
  }

  Future<void> _disposeCamera() async {
    _cameraSession++;
    await _releaseCameraHardware();
    if (mounted) {
      setState(() {
        _initializing = false;
      });
    }
  }

  Future<void> _initCamera() async {
    final int token = ++_cameraSession;

    await _releaseCameraHardware();
    if (!mounted || _cameraSession != token) {
      return;
    }

    if (!kIsWeb) {
      final PermissionStatus status = await Permission.camera.request();
      if (!mounted || _cameraSession != token) {
        return;
      }
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _initializing = false;
          });
        }
        return;
      }
    }

    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (!mounted || _cameraSession != token) {
        return;
      }

      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _noCamera = true;
            _initializing = false;
            _noCameraMessage =
                'No camera is available. Use “Choose from gallery” to pick a photo instead.';
          });
        }
        return;
      }

      if (kIsWeb) {
        final _WebCameraInit webResult =
            await _tryOpenCameraWeb(cameras, token);
        if (!mounted || _cameraSession != token) {
          return;
        }
        if (webResult == _WebCameraInit.permissionDenied) {
          return;
        }
        if (webResult == _WebCameraInit.exhausted) {
          setState(() {
            _noCamera = true;
            _initializing = false;
            _noCameraMessage = _kWebCameraOpenFailedMessage;
          });
        }
        return;
      }

      CameraDescription? back;
      for (final CameraDescription c in cameras) {
        if (c.lensDirection == CameraLensDirection.back) {
          back = c;
          break;
        }
      }
      back ??= cameras.first;

      // Resolution kept LOW + format yuv420 to mitigate a known Flutter engine race on
      // Android 14+ where ImageReaderSurfaceProducer.onImage fires after FlutterJNI detaches.
      // See: https://github.com/flutter/flutter/issues/151295
      final CameraController controller = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );

      if (!mounted || _cameraSession != token) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _noCameraMessage = _kDefaultNoCameraMessage;
      });
    } on CameraException catch (e) {
      if (!mounted || _cameraSession != token) {
        return;
      }
      if (_cameraExceptionIsPermissionDenied(e)) {
        setState(() {
          _permissionDenied = true;
          _initializing = false;
        });
      } else if (_cameraExceptionIsNotFound(e)) {
        setState(() {
          _noCamera = true;
          _initializing = false;
          _noCameraMessage =
              'No camera was found. Your browser or device may not expose one, or it may be in use elsewhere.';
        });
      } else {
        setState(() {
          _noCamera = true;
          _initializing = false;
          _noCameraMessage = (e.description != null && e.description!.trim().isNotEmpty)
              ? e.description!.trim()
              : 'Could not start the camera. Try again or use “Choose from gallery”.';
        });
      }
    } catch (_) {
      if (mounted && _cameraSession == token) {
        setState(() {
          _noCamera = true;
          _initializing = false;
          _noCameraMessage =
              'Could not start the camera. Try again or use “Choose from gallery”.';
        });
      }
    }
  }

  static bool _cameraExceptionIsPermissionDenied(CameraException e) {
    final String code = e.code;
    switch (code) {
      case 'CameraAccessDenied':
      case 'AudioAccessDenied':
      case 'NotAllowedError':
      case 'PermissionDenied':
      case 'permissionDenied':
      case 'Permission denied':
        return true;
      default:
        return false;
    }
  }

  static bool _cameraExceptionIsNotFound(CameraException e) =>
      e.code == 'cameraNotFound';

  static int _webCameraPriority(CameraDescription c) {
    switch (c.lensDirection) {
      case CameraLensDirection.back:
        return 0;
      case CameraLensDirection.external:
        return 1;
      case CameraLensDirection.front:
        return 2;
    }
  }

  Future<_WebCameraInit> _tryOpenCameraWeb(
    List<CameraDescription> cameras,
    int token,
  ) async {
    final List<CameraDescription> ordered =
        List<CameraDescription>.from(cameras)
          ..sort(
            (CameraDescription a, CameraDescription b) =>
                _webCameraPriority(a).compareTo(_webCameraPriority(b)),
          );

    const List<ResolutionPreset> presets = <ResolutionPreset>[
      ResolutionPreset.veryHigh,
      ResolutionPreset.high,
      ResolutionPreset.medium,
      ResolutionPreset.low,
    ];

    for (final CameraDescription desc in ordered) {
      for (final ResolutionPreset preset in presets) {
        if (!mounted || _cameraSession != token) {
          return _WebCameraInit.exhausted;
        }
        CameraController? trial;
        try {
          trial = CameraController(
            desc,
            preset,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.unknown,
          );
          await trial.initialize();
          if (!mounted || _cameraSession != token) {
            await trial.dispose();
            return _WebCameraInit.exhausted;
          }
          final CameraController ready = trial;
          trial = null;
          setState(() {
            _controller = ready;
            _initializing = false;
            _noCameraMessage = _kDefaultNoCameraMessage;
          });
          return _WebCameraInit.success;
        } on CameraException catch (e) {
          if (trial != null) {
            try {
              await trial.dispose();
            } on Object catch (_) {}
          }
          if (_cameraExceptionIsPermissionDenied(e)) {
            if (mounted && _cameraSession == token) {
              setState(() {
                _permissionDenied = true;
                _initializing = false;
              });
            }
            return _WebCameraInit.permissionDenied;
          }
        }
      }
    }
    return _WebCameraInit.exhausted;
  }

  Future<void> _onGrantPermission() async {
    if (kIsWeb) {
      setState(() {
        _permissionDenied = false;
        _initializing = true;
        _noCamera = false;
        _noCameraMessage = _kDefaultNoCameraMessage;
      });
      await _initCamera();
      return;
    }
    final PermissionStatus s = await Permission.camera.request();
    if (s.isGranted) {
      setState(() {
        _permissionDenied = false;
        _initializing = true;
        _noCamera = false;
        _noCameraMessage = _kDefaultNoCameraMessage;
      });
      await _initCamera();
    } else if (s.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> _toggleFlash() async {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized) {
      return;
    }
    setState(() => _isFlashOn = !_isFlashOn);
    try {
      await c.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      if (mounted) {
        setState(() => _isFlashOn = !_isFlashOn);
      }
    }
  }

  Future<void> _capture() async {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) {
      return;
    }

    XFile imageFile;
    setState(() => _capturing = true);
    try {
      imageFile = await c.takePicture();
    } catch (_) {
      if (mounted) {
        setState(() => _capturing = false);
      }
      return;
    }

    if (!mounted) {
      return;
    }

    await _runGeminiOnXFile(imageFile);
  }

  Future<void> _pickFromGallery() async {
    if (_capturing) {
      return;
    }
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _capturing = true);
    await _runGeminiOnXFile(picked);
  }

  Future<void> _runGeminiOnXFile(XFile imageFile) async {
    if (!mounted) {
      return;
    }
    Uint8List? previewBytes;
    try {
      previewBytes = await imageFile.readAsBytes();
    } on Object {
      previewBytes = null;
    }
    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (BuildContext ctx) =>
          _DetectionLoadingDialog(previewBytes: previewBytes),
    );

    List<ScannedIngredient> detected = <ScannedIngredient>[];
    String? fallbackMessage;
    FoodVisionResult? foodVisionResult;

    try {
      final FoodVisionResult result = await _foodDetection.analyzeCapture(imageFile);
      foodVisionResult = result;
      if (result.detectedIngredientNames.isNotEmpty) {
        detected = result.detectedIngredientNames
            .map(
              (String name) => ScannedIngredient(
                name: _toTitleCase(name),
                confidence: IngredientConfidence.high,
              ),
            )
            .toList(growable: false);
      } else {
        fallbackMessage = 'No ingredients detected in this image. Try again.';
      }
    } on Object catch (error) {
      final String reason = error.toString().replaceFirst('Exception: ', '').trim();
      fallbackMessage = reason.isNotEmpty
          ? reason
          : 'Could not analyze this image. Check your API key and try again.';
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    setState(() => _capturing = false);
    if (fallbackMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fallbackMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (detected.isEmpty) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScanResultScreen(
          initialIngredients: detected,
          foodVisionResult: foodVisionResult,
        ),
      ),
    );
  }

  static String _toTitleCase(String input) {
    final List<String> words = input
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return input;
    }

    return words
        .map(
          (String word) =>
              '${word[0].toUpperCase()}${word.length > 1 ? word.substring(1).toLowerCase() : ''}',
        )
        .join(' ');
  }

  @override
  void dispose() {
    _cameraSession++;
    unawaited(_releaseCameraHardware());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return _PermissionRequiredView(
        onGrant: _onGrantPermission,
        webHint: kIsWeb
            ? 'When your browser asks, allow camera access for this site. You can change this later in the site or lock icon in the address bar.'
            : null,
      );
    }
    if (_noCamera) {
      return _NoCameraView(message: _noCameraMessage);
    }

    return ColoredBox(
      color: const Color(0xFF1c1917),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_initializing || _controller == null)
            const Center(
              child: CircularProgressIndicator(color: _primaryContainer),
            )
          else
            Positioned.fill(
              child: _FullScreenCameraPreview(
                controller: _controller!,
                letterbox: kIsWeb,
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.38),
                    ],
                    stops: const <double>[0.35, 1.0],
                  ),
                ),
              ),
            ),
          ),
          const _ScanHudOverlay(primaryContainer: _primaryContainer),
          _BottomControls(
            onGallery: _pickFromGallery,
            galleryEnabled: !_capturing,
            onVoice: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Voice feature coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            onCapture: _capture,
            captureEnabled: !_initializing &&
                _controller != null &&
                _controller!.value.isInitialized &&
                !_capturing,
          ),
          _TopBar(
            onClose: () {
              if (widget.onClose != null) {
                widget.onClose!();
                return;
              }
              final NavigatorState nav = Navigator.of(context);
              if (nav.canPop()) {
                nav.pop();
              }
            },
            onFlash: _toggleFlash,
            isFlashOn: _isFlashOn,
          ),
        ],
      ),
    );
  }
}

class _PermissionRequiredView extends StatelessWidget {
  const _PermissionRequiredView({
    required this.onGrant,
    this.webHint,
  });

  final VoidCallback onGrant;
  final String? webHint;

  static const Color _onSurface = Color(0xFF2F1400);
  static const Color _primaryContainer = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFF8F5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Camera permission required',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: _onSurface,
                ),
              ),
              if (webHint != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  webHint!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.beVietnamPro(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF584237),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onGrant,
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryContainer,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: Text(
                  'Grant Permission',
                  style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoCameraView extends StatelessWidget {
  const _NoCameraView({required this.message});

  final String message;

  static const Color _onSurface = Color(0xFF2F1400);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFF8F5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: _onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenCameraPreview extends StatelessWidget {
  const _FullScreenCameraPreview({
    required this.controller,
    this.letterbox = false,
  });

  final CameraController controller;
  final bool letterbox;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxW = constraints.maxWidth;
        final double maxH = constraints.maxHeight;
        final double ar = controller.value.aspectRatio;

        if (letterbox) {
          double w = maxW;
          double h = w / ar;
          if (h > maxH) {
            h = maxH;
            w = h * ar;
          }
          return ColoredBox(
            color: Colors.black,
            child: Center(
              child: SizedBox(
                width: w,
                height: h,
                child: CameraPreview(controller),
              ),
            ),
          );
        }

        double previewW = maxW;
        double previewH = maxW * ar;
        if (previewH < maxH) {
          previewH = maxH;
          previewW = maxH / ar;
        }
        return ClipRect(
          child: OverflowBox(
            maxWidth: previewW,
            maxHeight: previewH,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewW,
                height: previewH,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScanHudOverlay extends StatelessWidget {
  const _ScanHudOverlay({
    required this.primaryContainer,
  });

  final Color primaryContainer;
  static const double _frameVerticalOffset = -120;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double frameW = (constraints.maxWidth * 0.72).clamp(0.0, 320.0);
        final double frameH = (constraints.maxHeight * 0.26).clamp(160.0, 240.0);

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            IgnorePointer(
              child: Transform.translate(
                offset: const Offset(0, _frameVerticalOffset),
                child: SizedBox(
                  width: frameW,
                  height: frameH,
                  child: const Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      _CornerBracket(alignment: Alignment.topLeft),
                      _CornerBracket(alignment: Alignment.topRight),
                      _CornerBracket(alignment: Alignment.bottomLeft),
                      _CornerBracket(alignment: Alignment.bottomRight),
                    ],
                  ),
                ),
              ),
            ),
            // Subtle text hint above the frame.
            IgnorePointer(
              child: Transform.translate(
                offset: Offset(0, _frameVerticalOffset - frameH / 2 - 36),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    'Point at your ingredients',
                    style: GoogleFonts.beVietnamPro(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    const double s = 30;
    const double t = 2.5;
    const double r = 12;
    const Color color = Colors.white;
    return Align(
      alignment: alignment,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: alignment == Alignment.topLeft
                ? const Radius.circular(r)
                : Radius.zero,
            topRight: alignment == Alignment.topRight
                ? const Radius.circular(r)
                : Radius.zero,
            bottomLeft: alignment == Alignment.bottomLeft
                ? const Radius.circular(r)
                : Radius.zero,
            bottomRight: alignment == Alignment.bottomRight
                ? const Radius.circular(r)
                : Radius.zero,
          ),
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? const BorderSide(color: color, width: t)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? const BorderSide(color: color, width: t)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? const BorderSide(color: color, width: t)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? const BorderSide(color: color, width: t)
                : BorderSide.none,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onClose,
    required this.onFlash,
    required this.isFlashOn,
  });

  final VoidCallback onClose;
  final VoidCallback onFlash;
  final bool isFlashOn;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, pad.top + 12, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _GlassIconButton(
              icon: Icons.close_rounded,
              onPressed: onClose,
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Ingridio AI Scan',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            _GlassIconButton(
              icon: isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              onPressed: onFlash,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.onGallery,
    required this.galleryEnabled,
    required this.onVoice,
    required this.onCapture,
    required this.captureEnabled,
  });

  final VoidCallback onGallery;
  final bool galleryEnabled;
  final VoidCallback onVoice;
  final VoidCallback onCapture;
  final bool captureEnabled;

  static const Color _primary = Color(0xFF9D4300);
  static const Color _primaryContainer = Color(0xFFF97316);
  static const Color _onSurface = Color(0xFF2F1400);

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double navReserve = 88 + bottomInset;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.82),
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.45, 1.0],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 32, 28, navReserve),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Center your ingredients and tap capture',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Keep items inside the frame for better detection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _SideAction(
                    icon: Icons.image_rounded,
                    label: 'Gallery',
                    onTap: onGallery,
                    enabled: galleryEnabled,
                  ),
                  _CaptureButton(
                    enabled: captureEnabled,
                    onTap: onCapture,
                    primary: _primary,
                    primaryContainer: _primaryContainer,
                    onSurface: _onSurface,
                  ),
                  _SideAction(
                    icon: Icons.mic_rounded,
                    label: 'Voice',
                    onTap: onVoice,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.enabled,
    required this.onTap,
    required this.primary,
    required this.primaryContainer,
    required this.onSurface,
  });

  final bool enabled;
  final VoidCallback onTap;
  final Color primary;
  final Color primaryContainer;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 112,
          height: 112,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryContainer.withValues(alpha: 0.22),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: primaryContainer.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: onSurface.withValues(alpha: 0.06),
                      width: 4,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: <Color>[primary, primaryContainer],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetectionLoadingDialog extends StatefulWidget {
  const _DetectionLoadingDialog({required this.previewBytes});

  final Uint8List? previewBytes;

  @override
  State<_DetectionLoadingDialog> createState() =>
      _DetectionLoadingDialogState();
}

class _DetectionLoadingDialogState extends State<_DetectionLoadingDialog> {
  static const Color _primary = Color(0xFF9D4300);
  static const Color _primaryContainer = Color(0xFFF97316);
  static const Color _background = Color(0xFFFFF8F5);
  static const Color _onSurface = Color(0xFF2F1400);
  static const Color _onSurfaceVariant = Color(0xFF584237);
  static const Color _surfaceLow = Color(0xFFFFF1E9);

  static const List<String> _steps = <String>[
    'Analyzing your photo',
    'Detecting ingredients',
    'Generating recipes',
  ];

  int _currentStep = 0;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    // Cycle through the step text every 1.6s so the user sees motion.
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentStep = (_currentStep + 1) % _steps.length;
      });
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(24),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 60,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Photo preview at the top.
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: widget.previewBytes != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              Image.memory(
                                widget.previewBytes!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                              // Soft scrim so the spinner reads on bright photos.
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      Colors.black.withValues(alpha: 0.05),
                                      Colors.black.withValues(alpha: 0.35),
                                    ],
                                  ),
                                ),
                              ),
                              // AI badge in the corner.
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'GEMINI AI',
                                        style: GoogleFonts.beVietnamPro(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: _surfaceLow,
                            child: const Icon(
                              Icons.image_rounded,
                              color: _primaryContainer,
                              size: 48,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const _BouncingDots(color: _primaryContainer),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _steps[_currentStep],
                          key: ValueKey<int>(_currentStep),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: _onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This usually takes 3–10 seconds.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.beVietnamPro(
                          color: _onSurfaceVariant,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Step progress indicators.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(_steps.length, (int i) {
                          final bool active = i == _currentStep;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 4,
                            width: active ? 24 : 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? _primary
                                  : _onSurfaceVariant.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots that bounce in a wave — a friendlier loader than a spinner.
class _BouncingDots extends StatefulWidget {
  const _BouncingDots({required this.color});

  final Color color;

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotOffset(double t, double phase) {
    final double v = ((t + phase) % 1.0);
    // Smooth sin-like bounce.
    final double normalised = (v < 0.5) ? (v * 2) : (1 - (v - 0.5) * 2);
    return -10 * normalised;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(3, (int i) {
            final double offset =
                _dotOffset(_controller.value, -i * 0.18);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
