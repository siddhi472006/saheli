import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  final int userId;
  final String language;
  final String patientName;
  final int age;
  final String reason;
  final int? pregnancyWeeks;
  final bool fatigue;
  final bool dizziness;
  final bool paleSkin;
  final bool shortnessOfBreath;
  final bool heavyPeriods;
  final bool headache;
  final String userName;
  final String userType;

  const CameraScreen({
    super.key,
    required this.userId,
    required this.language,
    required this.patientName,
    required this.age,
    required this.reason,
    this.pregnancyWeeks,
    required this.fatigue,
    required this.dizziness,
    required this.paleSkin,
    required this.shortnessOfBreath,
    required this.heavyPeriods,
    required this.headache,
    required this.userName,
    required this.userType,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  bool _invalidImage = false;
  Interpreter? _interpreter;

  bool get isHindi => widget.language == 'Hindi';
  String t(String english, String hindi) => isHindi ? hindi : english;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
          'assets/models/anaemia_model.tflite');
      print('✅ Model loaded successfully');
    } catch (e) {
      print('❌ Error loading model: $e');
    }
  }

  bool _isConjunctivaLike(img.Image resized) {
    int redDominantPixels = 0;
    int totalPixels = 0;
    for (int y = 62; y < 162; y++) {
      for (int x = 62; x < 162; x++) {
        final pixel = resized.getPixel(x, y);
        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;
        if (r > 0.35 && r > g * 1.1 && r > b * 1.1) {
          redDominantPixels++;
        }
        totalPixels++;
      }
    }
    double ratio = redDominantPixels / totalPixels;
    print('👁️ Conjunctiva pink ratio: ${(ratio * 100).toStringAsFixed(1)}%');
    return ratio > 0.15;
  }

  Future<Map<String, dynamic>> _runInference(File imageFile) async {
    double mlScore = 0.5;

    int symptomCount = [
      widget.fatigue,
      widget.dizziness,
      widget.paleSkin,
      widget.shortnessOfBreath,
      widget.heavyPeriods,
      widget.headache,
    ].where((s) => s).length;

    if (_interpreter != null) {
      final rawBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(rawBytes);

      if (image != null) {
        img.Image resized = img.copyResize(image, width: 224, height: 224);

        if (!_isConjunctivaLike(resized)) {
          return {
            'score': -1.0,
            'riskLevel': 'invalid',
            'clinicalNote': 'invalid',
            'mlScore': 0.0,
            'symptomCount': symptomCount,
          };
        }

        // Normalize to [0, 1] range (aligns with model training input)
        // Previously used ImageNet-style normalization; switch to simple 0..1 scaling
        // to ensure the model receives consistent inputs across runs.
        var input = List.generate(
          1,
          (_) => List.generate(
            224,
            (y) => List.generate(
              224,
              (x) {
                final pixel = resized.getPixel(x, y);
                return [
                  pixel.r / 255.0,
                  pixel.g / 255.0,
                  pixel.b / 255.0,
                ];
              },
            ),
          ),
        );

        var output = List.generate(1, (_) => List.filled(1, 0.0));
        _interpreter!.run(input, output);
        mlScore = output[0][0];

        // ── DEBUG: always print so we can calibrate ──
        print('🔴 RAW mlScore from model: $mlScore');
        print('🔴 Model output[0][0]: ${output[0][0]}');
      }
    }

    // ── Clinical note based on raw mlScore ──────────────────
    // We pass mlScore directly — ResultScreen's saheliScore
    // does all the final scoring. We just need a good clinical note.
    String clinicalNote;
    String riskLevel;

    // Determine effective anaemia signal
    // Handles both: HIGH=anaemic and LOW=anaemic models
    final double anaemiaSignal = mlScore >= 0.5
        ? mlScore
        : (1.0 - mlScore);

    print('🟡 anaemiaSignal (after orientation fix): $anaemiaSignal');
    print('🟡 symptomCount: $symptomCount');

    if (anaemiaSignal < 0.4) {
      // Healthy conjunctiva
      riskLevel = 'low';
      if (symptomCount == 0) {
        clinicalNote = t(
          'Conjunctiva appears healthy and pink. No significant anaemia indicators detected.',
          'कंजंक्टिवा स्वस्थ और गुलाबी दिखती है। रक्ताल्पता के कोई संकेत नहीं।',
        );
      } else if (symptomCount <= 2) {
        clinicalNote = t(
          'Conjunctiva looks normal. Minor symptoms present — maintain iron-rich diet and monitor.',
          'कंजंक्टिवा सामान्य दिखती है। हल्के लक्षण हैं — आयरन युक्त आहार लें।',
        );
      } else {
        riskLevel = 'borderline';
        clinicalNote = t(
          'Conjunctiva appears normal but multiple symptoms present. Blood test recommended to rule out early anaemia.',
          'कंजंक्टिवा सामान्य है लेकिन कई लक्षण हैं। प्रारंभिक रक्ताल्पता की जांच के लिए रक्त परीक्षण करें।',
        );
      }
    } else if (anaemiaSignal < 0.65) {
      // Moderate pallor
      riskLevel = 'moderate';
      if (symptomCount == 0) {
        clinicalNote = t(
          'Some conjunctival pallor observed. Blood test recommended within 48 hours — early anaemia can be asymptomatic.',
          'कुछ कंजंक्टिवल पीलापन देखा गया। 48 घंटे में रक्त परीक्षण करें — प्रारंभिक रक्ताल्पता बिना लक्षण के हो सकती है।',
        );
      } else if (symptomCount <= 3) {
        clinicalNote = t(
          'Conjunctival pallor observed with matching symptoms. Haemoglobin blood test recommended within 48 hours.',
          'कंजंक्टिवल पीलापन और लक्षण दोनों हैं। 48 घंटे में हीमोग्लोबिन परीक्षण करें।',
        );
      } else {
        riskLevel = 'high';
        clinicalNote = t(
          'Conjunctival pallor with several symptoms. Strong recommendation for blood test within 24 hours.',
          'कंजंक्टिवल पीलापन और कई लक्षण। 24 घंटे में रक्त परीक्षण अत्यावश्यक है।',
        );
      }
    } else {
      // Significant pallor
      riskLevel = 'high';
      if (symptomCount == 0) {
        clinicalNote = t(
          'Significant conjunctival pallor detected. Immediate blood test advised — severe anaemia can be asymptomatic.',
          'गंभीर कंजंक्टिवल पीलापन मिला। तुरंत रक्त परीक्षण करें — गंभीर रक्ताल्पता बिना लक्षण हो सकती है।',
        );
      } else if (symptomCount <= 2) {
        clinicalNote = t(
          'Clear conjunctival pallor with supporting symptoms. Immediate blood test and doctor consultation recommended.',
          'स्पष्ट कंजंक्टिवल पीलापन और लक्षण। तुरंत रक्त परीक्षण और डॉक्टर से परामर्श करें।',
        );
      } else {
        clinicalNote = t(
          'Significant conjunctival pallor with multiple symptoms. Immediate medical attention required.',
          'गंभीर कंजंक्टिवल पीलापन और कई लक्षण। तुरंत चिकित्सा सहायता आवश्यक है।',
        );
      }
    }

    print('🟢 riskLevel: $riskLevel');
    print('🟢 mlScore passed to ResultScreen: $mlScore');

    return {
      'score': mlScore,       // raw mlScore — ResultScreen handles final scoring
      'riskLevel': riskLevel,
      'clinicalNote': clinicalNote,
      'mlScore': mlScore,
      'symptomCount': symptomCount,
    };
  }

  Future<void> _captureImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image != null) {
      setState(() {
        _capturedImage = File(image.path);
        _invalidImage = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image != null) {
      setState(() {
        _capturedImage = File(image.path);
        _invalidImage = false;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_capturedImage == null) return;
    setState(() {
      _isAnalyzing = true;
      _invalidImage = false;
    });

    Map<String, dynamic> result = await _runInference(_capturedImage!);
    setState(() => _isAnalyzing = false);

    if (result['score'] == -1.0) {
      setState(() => _invalidImage = true);
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          userId: widget.userId,
          language: widget.language,
          patientName: widget.patientName,
          age: widget.age,
          reason: widget.reason,
          pregnancyWeeks: widget.pregnancyWeeks,
          riskScore: result['mlScore'],   // raw mlScore, saheliScore handles rest
          clinicalNote: result['clinicalNote'],
          mlScore: result['mlScore'],
          imagePath: _capturedImage!.path,
          fatigue: widget.fatigue,
          dizziness: widget.dizziness,
          paleSkin: widget.paleSkin,
          shortnessOfBreath: widget.shortnessOfBreath,
          heavyPeriods: widget.heavyPeriods,
          headache: widget.headache,
          userName: widget.userName,
          userType: widget.userType,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: Text(t('Eye Scan', 'आंख की जांच')),
        backgroundColor: const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFFE91E8C), size: 28),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'Gently pull down the lower eyelid to expose the inner pink lining (conjunctiva). Take the photo in good lighting.',
                      'निचली पलक को धीरे से नीचे खींचें ताकि अंदर की गुलाबी परत दिखे। अच्छी रोशनी में फोटो लें।',
                    ),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: _captureImage,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _invalidImage
                        ? Colors.red
                        : const Color(0xFFE91E8C),
                    width: 2,
                  ),
                ),
                child: _capturedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child:
                            Image.file(_capturedImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt,
                              size: 60, color: Color(0xFFE91E8C)),
                          const SizedBox(height: 12),
                          Text(
                            t(
                              'Tap to capture conjunctiva photo',
                              'पलक की फोटो लेने के लिए टैप करें',
                            ),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),

            if (_invalidImage) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t(
                          'This doesn\'t look like an eyelid photo. Please pull down your lower eyelid and retake in good lighting.',
                          'यह पलक की फोटो नहीं लगती। कृपया निचली पलक नीचे खींचकर अच्छी रोशनी में दोबारा लें।',
                        ),
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library,
                  color: Color(0xFFE91E8C)),
              label: Text(
                t('Use from gallery', 'गैलरी से चुनें'),
                style: const TextStyle(color: Color(0xFFE91E8C)),
              ),
            ),

            const Spacer(),

            if (_capturedImage != null)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _analyzeImage,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(
                    _isAnalyzing
                        ? t('Analyzing...', 'विश्लेषण हो रहा है...')
                        : t('Analyze for Anaemia',
                            'रक्ताल्पता की जांच करें'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E8C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
