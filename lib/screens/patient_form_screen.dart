import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../database_helper.dart';
import '../ml_service.dart';
import 'result_screen.dart';
import 'package:image/image.dart' as img;

class PatientFormScreen extends StatefulWidget {
  final int userId;
  final String language;
  final String userType;
  final String userName;

  const PatientFormScreen({
    super.key,
    required this.userId,
    required this.language,
    required this.userType,
    required this.userName,
  });

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _nameController  = TextEditingController();
  final _ageController   = TextEditingController();
  final _weeksController = TextEditingController();

  String _reason      = 'Routine';
  File?  _eyelidImage;
  bool   _isAnalyzing = false;

  bool _fatigue          = false;
  bool _dizziness        = false;
  bool _paleSkin         = false;
  bool _shortnessOfBreath = false;
  bool _heavyPeriods     = false;
  bool _headache         = false;

  bool   get isHindi => widget.language == 'Hindi';
  String t(String en, String hi) => isHindi ? hi : en;

  final _reasons = ['Routine', 'Pregnancy', 'Post-Delivery', 'Follow-up', 'Other'];

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked != null) {
      setState(() => _eyelidImage = File(picked.path));
    }
  }

  Future<void> _analyze() async {
    final name = _nameController.text.trim();
    final age  = int.tryParse(_ageController.text.trim());

    if (name.isEmpty) {
      _showError(t('Please enter patient name.', 'कृपया मरीज का नाम दर्ज करें।'));
      return;
    }
    if (age == null || age < 1 || age > 120) {
      _showError(t('Please enter a valid age.', 'कृपया सही आयु दर्ज करें।'));
      return;
    }
    if (_eyelidImage == null) {
      _showError(t('Please capture an eyelid photo.', 'कृपया पलक की फोटो लें।'));
      return;
    }


    setState(() => _isAnalyzing = true);
    // TEMP DEBUG — remove after testing
final bytes = await _eyelidImage!.readAsBytes();
final img2  = img.decodeImage(bytes);
if (img2 != null) {
  final resized = img.copyResize(img2, width: 224, height: 224);
  int redCount = 0, paleCount = 0, total = 0;
  for (int y = 44; y < 180; y++) {
    for (int x = 44; x < 180; x++) {
      final p = resized.getPixel(x, y);
      final r = p.r / 255.0;
      final g = p.g / 255.0;
      final b = p.b / 255.0;
      if (r > 0.4 && r > g * 1.1 && r > b * 1.1) redCount++;
      if ((r + g + b) / 3 > 0.6 && (r - g).abs() < 0.15) paleCount++;
      total++;
    }
  }
  print('=== DEBUG ===');
  print('Red pixels: ${(redCount/total*100).toStringAsFixed(1)}%');
  print('Pale pixels: ${(paleCount/total*100).toStringAsFixed(1)}%');
  print('=============');
}


    try {
      // Run ML
      final mlResult = await MLService.analyzeEyelid(_eyelidImage!);
      print('ML Result: $mlResult');

      // If image invalid show warning but still allow — 
      // don't block the whole flow during demo
      if (mlResult['valid'] == false) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(t('Image Warning', 'छवि चेतावनी')),
            content: Text(t(
              'This may not be a clear eyelid photo. Proceed anyway?',
              'यह स्पष्ट पलक की फोटो नहीं हो सकती। फिर भी जारी रखें?',
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t('Retake', 'दोबारा लें')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(t('Proceed', 'जारी रखें'),
                    style: const TextStyle(color: Color(0xFFE91E8C))),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _isAnalyzing = false);
          return;
        }
      }

      final symptoms = {
        'fatigue':           _fatigue,
        'dizziness':         _dizziness,
        'paleSkin':          _paleSkin,
        'shortnessOfBreath': _shortnessOfBreath,
        'heavyPeriods':      _heavyPeriods,
        'headache':          _headache,
      };

      final mlScore = mlResult['score'] ?? 0.5;

      final riskResult = MLService.calculateRisk(
        mlScore:        mlScore,
        age:            age,
        reason:         _reason,
        pregnancyWeeks: int.tryParse(_weeksController.text.trim()),
        symptoms:       symptoms,
      );

      // Compute saheliScore ONCE here — same formula as result_screen.dart
      final symptomCount = symptoms.values.where((v) => v).length;
      final saheliScore = ((mlScore * 6.0) +
          (symptomCount / 6.0) * 2.5 +
          (_reason == 'Pregnancy' ? 0.9 : 0.0) +
          (age < 18 || age > 45 ? 0.6 : 0.0))
          .clamp(0.0, 10.0);

      print('mlScore: $mlScore | saheliScore: $saheliScore | risk: ${riskResult['level']}');

      await DatabaseHelper.instance.saveScreening(
        userId:         widget.userId,
        patientName:    name,
        age:            age,
        reason:         _reason,
        pregnancyWeeks: int.tryParse(_weeksController.text.trim()),
        mlScore:        mlScore,
        riskScore:      riskResult['score'],
        saheliScore:    saheliScore,   // ← saves it directly
        riskLevel:      riskResult['level'],
        clinicalNote:   riskResult['note'],
        imagePath:      _eyelidImage!.path,
        symptoms:       symptoms,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            patientName:       name,
            age:               age,
            reason:            _reason,
            pregnancyWeeks:    int.tryParse(_weeksController.text.trim()),
            riskScore:         riskResult['score'],
            mlScore:           mlScore,
            clinicalNote:      riskResult['note'],
            imagePath:         _eyelidImage!.path,
            language:          widget.language,
            userId:            widget.userId,
            userName:          widget.userName,
            userType:          widget.userType,
            fatigue:           _fatigue,
            dizziness:         _dizziness,
            paleSkin:          _paleSkin,
            riskLevel:         riskResult['level'],
            shortnessOfBreath: _shortnessOfBreath,
            heavyPeriods:      _heavyPeriods,
            headache:          _headache,
          ),
        ),
      );
    } catch (e, stack) {
      print('Analysis error: $e');
      print('Stack: $stack');
      if (mounted) {
        _showError(t(
          'Analysis failed: $e',
          'विश्लेषण विफल: $e',
        ));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw  = MediaQuery.of(context).size.width;
    final sh  = MediaQuery.of(context).size.height;
    final pad = sw * 0.05;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: Text(t('New Screening', 'नई जांच'),
            style: TextStyle(fontSize: sw * 0.045)),
        backgroundColor: const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(t('Patient Information', 'मरीज की जानकारी'), sw),
            SizedBox(height: sh * 0.015),

            _label(t('Full Name', 'पूरा नाम'), sw),
            SizedBox(height: sh * 0.008),
            _field(
              controller: _nameController,
              hint: t('Enter name', 'नाम दर्ज करें'),
              icon: Icons.person_outline,
              sw: sw,
            ),

            SizedBox(height: sh * 0.018),

            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label(t('Age', 'आयु'), sw),
                SizedBox(height: sh * 0.008),
                _field(
                  controller: _ageController,
                  hint: t('Years', 'वर्ष'),
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  sw: sw,
                ),
              ])),
              SizedBox(width: sw * 0.03),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label(t('Reason', 'कारण'), sw),
                SizedBox(height: sh * 0.008),
                _dropdownField(sw),
              ])),
            ]),

            if (_reason == 'Pregnancy') ...[
              SizedBox(height: sh * 0.018),
              _label(t('Pregnancy Week', 'गर्भावस्था सप्ताह'), sw),
              SizedBox(height: sh * 0.008),
              _field(
                controller: _weeksController,
                hint: t('e.g. 24', 'जैसे 24'),
                icon: Icons.pregnant_woman,
                keyboardType: TextInputType.number,
                sw: sw,
              ),
            ],

            SizedBox(height: sh * 0.025),
            _sectionTitle(t('Symptoms (optional)', 'लक्षण (वैकल्पिक)'), sw),
            SizedBox(height: sh * 0.012),
            Wrap(
              spacing: sw * 0.02,
              runSpacing: sw * 0.02,
              children: [
                _symptomChip(t('Fatigue',        'थकान'),          _fatigue,           (v) => setState(() => _fatigue           = v), sw),
                _symptomChip(t('Dizziness',      'चक्कर'),         _dizziness,         (v) => setState(() => _dizziness         = v), sw),
                _symptomChip(t('Pale Skin',      'पीली त्वचा'),    _paleSkin,          (v) => setState(() => _paleSkin          = v), sw),
                _symptomChip(t('Breathlessness', 'सांस की तकलीफ'), _shortnessOfBreath, (v) => setState(() => _shortnessOfBreath = v), sw),
                _symptomChip(t('Heavy Periods',  'भारी माहवारी'),  _heavyPeriods,      (v) => setState(() => _heavyPeriods      = v), sw),
                _symptomChip(t('Headache',       'सिरदर्द'),       _headache,          (v) => setState(() => _headache          = v), sw),
              ],
            ),

            SizedBox(height: sh * 0.025),
            _sectionTitle(t('Eyelid Photo', 'पलक की फोटो'), sw),
            SizedBox(height: sh * 0.008),
            Text(
              t('Pull down the lower eyelid and take a clear photo.',
                'निचली पलक को नीचे खींचें और साफ फोटो लें।'),
              style: TextStyle(fontSize: sw * 0.032, color: Colors.black54),
            ),
            SizedBox(height: sh * 0.012),

            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width:  double.infinity,
                height: sh * 0.25,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _eyelidImage != null
                        ? const Color(0xFFE91E8C)
                        : Colors.grey.shade300,
                    width: _eyelidImage != null ? 2 : 1,
                  ),
                ),
                child: _eyelidImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_eyelidImage!, fit: BoxFit.cover),
                      )
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_a_photo, size: sw * 0.12, color: Colors.grey.shade300),
                        SizedBox(height: sh * 0.01),
                        Text(t('Tap to capture photo', 'फोटो लेने के लिए टैप करें'),
                            style: TextStyle(color: Colors.grey.shade400, fontSize: sw * 0.035)),
                      ]),
              ),
            ),

            SizedBox(height: sh * 0.012),

            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: Icon(Icons.camera_alt, color: const Color(0xFFE91E8C), size: sw * 0.05),
                label: Text(t('Camera', 'कैमरा'),
                    style: TextStyle(color: const Color(0xFFE91E8C), fontSize: sw * 0.035)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE91E8C)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )),
              SizedBox(width: sw * 0.03),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: Icon(Icons.photo_library, color: const Color(0xFFE91E8C), size: sw * 0.05),
                label: Text(t('Gallery', 'गैलरी'),
                    style: TextStyle(color: const Color(0xFFE91E8C), fontSize: sw * 0.035)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE91E8C)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )),
            ]),

            SizedBox(height: sh * 0.035),

            SizedBox(
              width:  double.infinity,
              height: sh * 0.07,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyze,
                icon: _isAnalyzing
                    ? SizedBox(
                        width: sw * 0.05, height: sw * 0.05,
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.biotech, size: sw * 0.06),
                label: Text(
                  _isAnalyzing
                      ? t('Analyzing...', 'विश्लेषण हो रहा है...')
                      : t('Analyze Now',  'अभी विश्लेषण करें'),
                  style: TextStyle(fontSize: sw * 0.042, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E8C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            SizedBox(height: sh * 0.03),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Color(0xFFE91E8C)),
            title: Text(t('Take Photo', 'फोटो लें')),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera);  },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Color(0xFFE91E8C)),
            title: Text(t('Choose from Gallery', 'गैलरी से चुनें')),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text, double sw) => Text(text,
      style: TextStyle(fontSize: sw * 0.042, fontWeight: FontWeight.bold, color: Colors.black87));

  Widget _label(String text, double sw) => Text(text,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: sw * 0.034));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required double sw,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: sw * 0.037),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: sw * 0.035),
        prefixIcon: Icon(icon, color: const Color(0xFFE91E8C), size: sw * 0.05),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: sw * 0.04, vertical: sw * 0.035),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE91E8C), width: 2)),
      ),
    );
  }

  Widget _dropdownField(double sw) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.03),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _reason,
          isExpanded: true,
          style: TextStyle(fontSize: sw * 0.034, color: Colors.black87),
          items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setState(() => _reason = v!),
        ),
      ),
    );
  }

  Widget _symptomChip(String label, bool selected, ValueChanged<bool> onChanged, double sw) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: sw * 0.035, vertical: sw * 0.02),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE91E8C).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFE91E8C) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: sw * 0.032,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFFE91E8C) : Colors.black54,
            )),
      ),
    );
  }
}