import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraScreen(camera: getFrontCamera()),
    );
  }

  CameraDescription getFrontCamera() {
    // Encontre a câmera frontal na lista de câmeras disponíveis
    for (CameraDescription camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        return camera;
      }
    }
    return cameras[0];
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({required this.camera});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isTorchOn = false; // Estado da lanterna

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.ultraHigh,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleTorch() async {
    try {
      if (_isTorchOn) {
        await _controller.setFlashMode(FlashMode.off);
      } else {
        await _controller.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (e) {
      print('Erro ao controlar a lanterna: $e');
    }
  }

  void _processFaceDetection(FirebaseVisionImage image) async {
    final faceDetector = FirebaseVision.instance.faceDetector();
    final faces = await faceDetector.processImage(image);

    // Processar as informações de cada rosto detectado
    for (final face in faces) {
      // Acessar os detalhes do rosto, como posição, expressão facial, etc.
      final boundingBox = face.boundingBox;
      final left = boundingBox.left;
      final top = boundingBox.top;
      final width = boundingBox.width;
      final height = boundingBox.height;

      // Fazer algo com as informações do rosto detectado
      // Por exemplo, desenhar um retângulo na posição do rosto na tela
      // ou exibir informações relevantes do rosto na interface do usuário
    }
  }

  void _processImage(CameraImage image) {
    // Converter a imagem da câmera para um formato adequado para o Firebase ML Vision
    final FirebaseVisionImage visionImage = FirebaseVisionImage.fromBytes(
      image.planes[0].bytes,
      FirebaseVisionImageMetadata(
        rawFormat: image.format.raw,
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: ImageRotation.rotation90,
        planeData: image.planes.map(
          (plane) {
            return FirebaseVisionImagePlaneMetadata(
              bytesPerRow: plane.bytesPerRow,
              height: plane.height,
              width: plane.width,
            );
          },
        ).toList(),
      ),
    );

    // Processar a detecção facial
    _processFaceDetection(visionImage);
  }

  void _startImageStream() {
    _controller.startImageStream((CameraImage image) {
      if (_controller.value.isStreamingImages) {
        _processImage(image);
      }
    });
  }

  void _stopImageStream() {
    _controller.stopImageStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            _startImageStream(); // Iniciar o streaming de imagens da câmera
            return CameraPreview(_controller);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(_isTorchOn ? Icons.flash_off : Icons.flash_on),
        onPressed: _toggleTorch,
      ),
    );
  }
}
