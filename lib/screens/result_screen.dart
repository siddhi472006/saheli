import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:math';
import 'dashboard_screen.dart';
import 'package:flutter/services.dart';

class ResultScreen extends StatefulWidget {
  final String patientName;
  
  final int age;
  final String reason;
  final int? pregnancyWeeks;
  final double riskScore;
  final double mlScore;
  final String clinicalNote;
  final String imagePath;
  final bool fatigue;
  final bool dizziness;
  final bool paleSkin;
  final bool shortnessOfBreath;
  final bool heavyPeriods;
  final bool headache;
  final String language;
  final int userId;
  final String userName;
  final String userType;
  final String riskLevel; // ADD THIS

  const ResultScreen({
    super.key,
    required this.patientName,
    required this.age,
    required this.reason,
    this.pregnancyWeeks,
    required this.riskScore,
    required this.mlScore,
    required this.clinicalNote,
    required this.imagePath,
    required this.fatigue,
    required this.dizziness,
    required this.paleSkin,
    required this.shortnessOfBreath,
    required this.heavyPeriods,
    required this.headache,
    required this.language,
    required this.userId,
    required this.userName,
    required this.userType,
    required this.riskLevel,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _gaugeAnim;

  bool get isHindi => widget.language == 'Hindi';
  String t(String en, String hi) => isHindi ? hi : en;

  double get saheliScore {
  final symptomCount = [
    widget.fatigue, widget.dizziness, widget.paleSkin,
    widget.shortnessOfBreath, widget.heavyPeriods, widget.headache,
  ].where((s) => s).length;

  // NO INVERSION — high mlScore = more pale = more anemic
  final pallor  = widget.mlScore * 6.0;
  final symptom = (symptomCount / 6.0) * 2.5;
  double rf     = 0.0;
  if (widget.reason == 'Pregnancy') rf += 0.9;
  if (widget.age < 18 || widget.age > 45) rf += 0.6;

  return (pallor + symptom + rf).clamp(0.0, 10.0);
}
  String get hbRange {
    if (saheliScore >= 7.5) return '7.0 – 8.5 g/dL';
    if (saheliScore >= 5.5) return '8.5 – 10.0 g/dL';
    if (saheliScore >= 3.5) return '10.0 – 11.5 g/dL';
    return '11.5 – 13.0 g/dL';
  }

  Map<String, dynamic> get whoBadge {
  switch (widget.riskLevel) {
    case 'high':
      return {
        'label': t('High Risk Anaemia',  'उच्च जोखिम रक्ताल्पता'),
        'sub':   t('Hb likely < 8 g/dL', 'Hb संभवतः < 8 g/dL'),
        'color': Colors.red.shade700,
        'bg':    Colors.red.shade50,
        'emoji': '🔴',
      };
    case 'moderate':
      return {
        'label': t('Moderate Anaemia',     'मध्यम रक्ताल्पता'),
        'sub':   t('Hb likely 8–10 g/dL', 'Hb संभवतः 8–10 g/dL'),
        'color': Colors.orange.shade700,
        'bg':    Colors.orange.shade50,
        'emoji': '🟠',
      };
    case 'borderline':
      return {
        'label': t('Borderline',            'सीमारेखा'),
        'sub':   t('Hb likely 10–12 g/dL', 'Hb संभवतः 10–12 g/dL'),
        'color': Colors.amber.shade700,
        'bg':    Colors.amber.shade50,
        'emoji': '🟡',
      };
    default:
      return {
        'label': t('Normal',               'सामान्य'),
        'sub':   t('Hb likely > 12 g/dL', 'Hb संभवतः > 12 g/dL'),
        'color': Colors.green.shade700,
        'bg':    Colors.green.shade50,
        'emoji': '🟢',
      };
  }
}

  
Color get gaugeColor {
  switch (widget.riskLevel) {
    case 'high':       return Colors.red.shade600;
    case 'moderate':   return Colors.orange;
    case 'borderline': return Colors.amber;
    default:           return Colors.green;
  }
}
  String get _action {
    if (saheliScore >= 7.5) return t('Visit a doctor immediately. CBC blood test required.', 'तुरंत डॉक्टर से मिलें। CBC टेस्ट जरूरी है।');
    if (saheliScore >= 5.5) return t('Book a blood test within 24 hours.', '24 घंटे में रक्त परीक्षण कराएं।');
    if (saheliScore >= 3.5) return t('Get a haemoglobin test within 48 hours.', '48 घंटे में हीमोग्लोबिन टेस्ट कराएं।');
    return t('No action needed. Maintain iron-rich diet.', 'कोई कार्रवाई आवश्यक नहीं। आयरन युक्त आहार लें।');
  }

  List<String> get _symptomList => [
    if (widget.fatigue)           t('Fatigue',             'थकान'),
    if (widget.dizziness)         t('Dizziness',           'चक्कर'),
    if (widget.paleSkin)          t('Pale Skin',           'पीली त्वचा'),
    if (widget.shortnessOfBreath) t('Shortness of Breath', 'सांस की तकलीफ'),
    if (widget.heavyPeriods)      t('Heavy Periods',       'भारी माहवारी'),
    if (widget.headache)          t('Frequent Headaches',  'सिरदर्द'),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _gaugeAnim = Tween<double>(begin: 0, end: saheliScore / 10).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool _hasDevanagari(String text) {
  return text.runes.any((r) => r >= 0x0900 && r <= 0x097F);
}
  // ── Hindi-aware PDF ──────────────────────────────────────
  Future<String> _generatePDF() async {
  final pdf = pw.Document();

  // ── Load Hindi font if needed ──
  pw.Font? hindiFont;
  if (isHindi) {
    final fontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
    hindiFont = pw.Font.ttf(fontData);
  }

  // Helper: use Hindi font only when the string contains Devanagari characters
pw.TextStyle ts(double size, {bool bold = false, PdfColor? color, String? text}) {
  final bool needsHindiFont = isHindi && hindiFont != null && 
      (text == null || _hasDevanagari(text));
  return pw.TextStyle(
    font: needsHindiFont ? hindiFont : null,
    fontSize: size,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: color,
  );
}

  final syms   = _symptomList;
  final badge  = whoBadge;
  final now    = DateTime.now();
  final dateStr = '${now.day}/${now.month}/${now.year}  ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

  final lTitle      = t('Anaemia Screening Referral Slip', 'रक्ताल्पता जांच रेफरल स्लिप');
  final lDate       = t('Date', 'दिनांक');
  final lScore      = t('Saheli Score', 'सहेली स्कोर');
  final lEstHb      = t('Est. Hb', 'अनु. Hb');
  final lWho        = t('WHO Classification', 'WHO वर्गीकरण');
  final lPatient    = t('PATIENT DETAILS', 'मरीज की जानकारी');
  final lName       = t('Name', 'नाम');
  final lAge        = t('Age', 'आयु');
  final lYears      = t('years', 'वर्ष');
  final lReason     = t('Reason', 'कारण');
  final lPregWeek   = t('Pregnancy Week', 'गर्भावस्था सप्ताह');
  final lWeek       = t('Week', 'सप्ताह');
  final lSymptoms   = t('Symptoms', 'लक्षण');
  final lNone       = t('None', 'कोई नहीं');
  final lClinical   = t('CLINICAL ASSESSMENT', 'नैदानिक मूल्यांकन');
  final lAction     = t('RECOMMENDED ACTION', 'अनुशंसित कार्रवाई');
  final lDisclaimer = t(
    'DISCLAIMER: Generated by Saheli. Not a medical diagnosis. Consult a qualified healthcare professional.',
    'अस्वीकरण: सहेली द्वारा निर्मित। यह चिकित्सा निदान नहीं है। किसी योग्य स्वास्थ्य पेशेवर से परामर्श लें।',
  );

  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (pw.Context ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('E91E8C'),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('SAHELI', style: ts(28, bold: true, color: PdfColors.white,text: 'SAHELI')),
            pw.SizedBox(height: 4),
            pw.Text(lTitle, style: ts(14, color: PdfColors.white,text: lTitle)),
            pw.SizedBox(height: 4),
            pw.Text('$lDate: $dateStr', style: ts(11, color: PdfColors.white,text: '$lDate: $dateStr')),
          ]),
        ),
        pw.SizedBox(height: 20),
        pw.Row(children: [
          pw.Container(
            width: 140,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('E91E8C'), width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text(lScore, style: ts(10, color: PdfColors.grey700,text: lScore)),
              pw.SizedBox(height: 6),
              pw.Text('${saheliScore.toStringAsFixed(1)} / 10',
                  style: ts(22, bold: true, color: PdfColor.fromHex('E91E8C'),text: '${saheliScore.toStringAsFixed(1)} / 10')),
              pw.SizedBox(height: 6),
              pw.Text('$lEstHb:', style: ts(9, color: PdfColors.grey600,text: '$lEstHb:')),
              pw.Text(hbRange, style: ts(10, bold: true)),
            ]),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: saheliScore >= 7.5 ? PdfColors.red50
                    : saheliScore >= 5.5 ? PdfColors.orange50
                    : saheliScore >= 3.5 ? PdfColors.yellow50
                    : PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(lWho, style: ts(10, color: PdfColors.grey700,text: lWho)),
                pw.SizedBox(height: 6),
                pw.Text(badge['label'], style: ts(16, bold: true,text: badge['label'])),
                pw.SizedBox(height: 4),
                pw.Text(badge['sub'], style: ts(11, color: PdfColors.grey700,text: badge['sub'])),
              ]),
            ),
          ),
        ]),
        pw.SizedBox(height: 20),
        pw.Text(lPatient, style: ts(12, bold: true, color: PdfColors.grey800,text: lPatient)),
        pw.Divider(),
        pw.SizedBox(height: 8),
        _pdfRow(lName,    widget.patientName, ts),
        _pdfRow(lAge,     '${widget.age} $lYears', ts),
        _pdfRow(lReason,  widget.reason, ts),
        if (widget.reason == 'Pregnancy' && widget.pregnancyWeeks != null)
          _pdfRow(lPregWeek, '$lWeek ${widget.pregnancyWeeks}', ts),
        _pdfRow(lSymptoms, syms.isEmpty ? lNone : syms.join(', '), ts),
        pw.SizedBox(height: 20),
        pw.Text(lClinical, style: ts(12, bold: true, color: PdfColors.grey800,text: lClinical)),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(widget.clinicalNote, style: ts(12,text: widget.clinicalNote)),
        pw.SizedBox(height: 20),
        pw.Text(lAction, style: ts(12, bold: true, color: PdfColors.grey800,text: lAction)),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(_action, style: ts(13, bold: true,text: _action)),
        pw.Spacer(),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(lDisclaimer, style: ts(9, color: PdfColors.grey600,text: lDisclaimer)),
      ],
    ),
  ));

  final tempDir  = await getTemporaryDirectory();
  final fileName = 'Saheli_${widget.patientName.replaceAll(' ', '_')}_${now.millisecondsSinceEpoch}.pdf';
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(await pdf.save());
  return file.path;
}

  Future<String?> _getDownloadsPath() async {
    if (Platform.isAndroid) {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) return downloadsDir.path;
      var status = await Permission.storage.status;
      if (!status.isGranted) status = await Permission.storage.request();
      if (status.isGranted && await downloadsDir.exists()) {
        return downloadsDir.path;
      }
      var manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        manageStatus = await Permission.manageExternalStorage.request();
      }
      if (await downloadsDir.exists()) return downloadsDir.path;
      final ext = await getExternalStorageDirectory();
      return ext?.path;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
  }

  Future<void> _viewReport() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE91E8C))),
    );
    try {
      final pdfPath = await _generatePDF();
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PDFViewerScreen(
            pdfPath:          pdfPath,
            patientName:      widget.patientName,
            language:         widget.language,
            getDownloadsPath: _getDownloadsPath,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  
pw.Widget _pdfRow(String label, String value,
    pw.TextStyle Function(double, {bool bold, PdfColor? color, String? text}) ts) =>
  pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(
          width: 160,
          child: pw.Text(label, style: ts(11, color: PdfColors.grey700, text: label))),
      pw.Expanded(child: pw.Text(value, style: ts(11, bold: true, text: value))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final sw       = size.width;
    final sh       = size.height;
    final pad      = sw * 0.05;
    final symptoms = _symptomList;
    final badge    = whoBadge;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: Text(t('Screening Result', 'जांच परिणाम'),
            style:
                TextStyle(fontSize: 17 * (sw / 390).clamp(0.75, 1.35))),
        backgroundColor: const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.8),
          child: Column(
            children: [
              // ── Gauge ──────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(sw * 0.05),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: gaugeColor.withOpacity(0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(children: [
                  Text(
                    t('Saheli Anaemia Index', 'सहेली एनीमिया इंडेक्स'),
                    style: TextStyle(
                        fontSize: sw * 0.032,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8),
                  ),
                  SizedBox(height: sw * 0.04),
                  AnimatedBuilder(
                    animation: _gaugeAnim,
                    builder: (context, _) => SizedBox(
                      width: sw * 0.52,
                      height: sw * 0.32,
                      child: CustomPaint(
                        painter: _GaugePainter(
                            progress: _gaugeAnim.value,
                            color: gaugeColor),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: sw * 0.1),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (_gaugeAnim.value * 10)
                                        .toStringAsFixed(1),
                                    style: TextStyle(
                                        fontSize: sw * 0.1,
                                        fontWeight: FontWeight.bold,
                                        color: gaugeColor),
                                  ),
                                  Text('/10',
                                      style: TextStyle(
                                          color: Colors.black38,
                                          fontSize: sw * 0.035)),
                                ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: sw * 0.04),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: sw * 0.05, vertical: sw * 0.025),
                    decoration: BoxDecoration(
                      color: gaugeColor.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child:
                        Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bloodtype,
                          color: gaugeColor, size: sw * 0.05),
                      SizedBox(width: sw * 0.02),
                      Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('Estimated Hemoglobin',
                                  'अनुमानित हीमोग्लोबिन'),
                              style: TextStyle(
                                  fontSize: sw * 0.026,
                                  color: Colors.black54),
                            ),
                            Text(hbRange,
                                style: TextStyle(
                                    fontSize: sw * 0.046,
                                    fontWeight: FontWeight.bold,
                                    color: gaugeColor)),
                          ]),
                    ]),
                  ),
                ]),
              ),

              SizedBox(height: sh * 0.018),

              // ── WHO Badge ──────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(sw * 0.045),
                decoration: BoxDecoration(
                  color: badge['bg'],
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color:
                          (badge['color'] as Color).withOpacity(0.3),
                      width: 1.5),
                ),
                child: Row(children: [
                  Text(badge['emoji'],
                      style: TextStyle(fontSize: sw * 0.09)),
                  SizedBox(width: sw * 0.035),
                  Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Text(t('WHO Classification', 'WHO वर्गीकरण'),
                          style: TextStyle(
                              fontSize: sw * 0.028,
                              color: Colors.black45)),
                      Text(badge['label'],
                          style: TextStyle(
                              fontSize: sw * 0.05,
                              fontWeight: FontWeight.bold,
                              color: badge['color'])),
                      Text(badge['sub'],
                          style: TextStyle(
                              fontSize: sw * 0.032,
                              color: badge['color'])),
                    ]),
                  ),
                ]),
              ),

              SizedBox(height: sh * 0.018),

              // ── Score Breakdown ────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(sw * 0.04),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.pink.withOpacity(0.06),
                        blurRadius: 8)
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t('Score Breakdown', 'स्कोर विश्लेषण'),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: sw * 0.038)),
                  SizedBox(height: sw * 0.035),
                  _breakdownBar(
                    label: t('Conjunctiva Pallor (60%)',
                        'कंजंक्टिवा पीलापन (60%)'),
                    value: widget.mlScore,
                    color: const Color(0xFFE91E8C),
                    sw: sw,
                  ),
                  SizedBox(height: sw * 0.025),
                  _breakdownBar(
                    label: t('Symptoms (25%)', 'लक्षण (25%)'),
                    value: [
                              widget.fatigue,
                              widget.dizziness,
                              widget.paleSkin,
                              widget.shortnessOfBreath,
                              widget.heavyPeriods,
                              widget.headache
                            ].where((s) => s).length /
                        6,
                    color: Colors.purple,
                    sw: sw,
                  ),
                  SizedBox(height: sw * 0.025),
                  _breakdownBar(
                    label: t(
                        'Risk Factors (15%)', 'जोखिम कारक (15%)'),
                    value:
                        widget.reason == 'Pregnancy' ? 0.6 : 0.15,
                    color: Colors.blue,
                    sw: sw,
                  ),
                ]),
              ),

              SizedBox(height: sh * 0.018),

              // ── Action Card ────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(sw * 0.04),
                decoration: BoxDecoration(
                  color: gaugeColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: gaugeColor.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.bolt,
                      color: gaugeColor, size: sw * 0.07),
                  SizedBox(width: sw * 0.03),
                  Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                    Text(
                        t('Recommended Action',
                            'अनुशंसित कार्रवाई'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: gaugeColor,
                            fontSize: sw * 0.033)),
                    const SizedBox(height: 4),
                    Text(_action,
                        style: TextStyle(fontSize: sw * 0.033)),
                  ])),
                ]),
              ),

              SizedBox(height: sh * 0.018),

              // ── Patient Details ────────────────────────
              _infoCard(
                title: t('Patient Details', 'मरीज की जानकारी'),
                sw: sw,
                child: Column(children: [
                  _infoRow(t('Name', 'नाम'), widget.patientName, sw),
                  _infoRow(t('Age', 'आयु'),
                      '${widget.age} ${t('years', 'वर्ष')}', sw),
                  _infoRow(t('Reason', 'कारण'), widget.reason, sw),
                  if (widget.reason == 'Pregnancy' &&
                      widget.pregnancyWeeks != null)
                    _infoRow(t('Preg. Week', 'गर्भ सप्ताह'),
                        'Week ${widget.pregnancyWeeks}', sw),
                  _infoRow(
                      t('Symptoms', 'लक्षण'),
                      symptoms.isEmpty
                          ? t('None', 'कोई नहीं')
                          : symptoms.join(', '),
                      sw),
                ]),
              ),

              SizedBox(height: sh * 0.018),

              _infoCard(
                title:
                    t('Clinical Assessment', 'नैदानिक मूल्यांकन'),
                sw: sw,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.medical_services,
                      color: gaugeColor, size: sw * 0.055),
                  SizedBox(width: sw * 0.025),
                  Expanded(
                      child: Text(widget.clinicalNote,
                          style: TextStyle(
                              fontSize: sw * 0.033,
                              height: 1.5))),
                ]),
              ),

              SizedBox(height: sh * 0.018),

              Container(
                padding: EdgeInsets.all(sw * 0.03),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: sw * 0.038, color: Colors.grey),
                  SizedBox(width: sw * 0.02),
                  Expanded(
                      child: Text(
                    t(
                        'Screening tool only. Not a medical diagnosis.',
                        'केवल स्क्रीनिंग उपकरण। चिकित्सा निदान नहीं।'),
                    style: TextStyle(
                        fontSize: sw * 0.028, color: Colors.grey),
                  )),
                ]),
              ),

              SizedBox(height: sh * 0.025),

              // View Report
              SizedBox(
                width: double.infinity,
                height: sh * 0.065,
                child: ElevatedButton.icon(
                  onPressed: _viewReport,
                  icon: Icon(Icons.picture_as_pdf, size: sw * 0.05),
                  label: Text(t('View Report', 'रिपोर्ट देखें'),
                      style: TextStyle(
                          fontSize: sw * 0.04,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E8C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              SizedBox(height: sh * 0.012),

              // Back to Dashboard
              SizedBox(
                width: double.infinity,
                height: sh * 0.065,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DashboardScreen(
                        userId:   widget.userId,
                        userName: widget.userName,
                        userType: widget.userType,
                        language: widget.language,
                      ),
                    ),
                    (route) => false,
                  ),
                  icon: Icon(Icons.home,
                      color: const Color(0xFFE91E8C),
                      size: sw * 0.05),
                  label: Text(
                      t('Back to Dashboard', 'डैशबोर्ड पर जाएं'),
                      style: TextStyle(
                          fontSize: sw * 0.04,
                          color: const Color(0xFFE91E8C),
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFFE91E8C), width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              SizedBox(height: sh * 0.03),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdownBar({
    required String label,
    required double value,
    required Color color,
    required double sw,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style:
                TextStyle(fontSize: sw * 0.03, color: Colors.black54)),
        Text('${(value * 100).toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: sw * 0.03,
                fontWeight: FontWeight.bold,
                color: color)),
      ]),
      SizedBox(height: sw * 0.015),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade100,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: sw * 0.025,
        ),
      ),
    ]);
  }

  Widget _infoCard(
      {required String title,
      required Widget child,
      required double sw}) =>
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(sw * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.pink.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(title,
              style: TextStyle(
                  fontSize: sw * 0.038,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: sw * 0.025),
          child,
        ]),
      );

  Widget _infoRow(String label, String value, double sw) => Padding(
        padding: EdgeInsets.symmetric(vertical: sw * 0.008),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          SizedBox(
              width: sw * 0.28,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey, fontSize: sw * 0.032))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: sw * 0.032))),
        ]),
      );
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center     = Offset(size.width / 2, size.height);
    final radius     = size.width / 2 - 10;
    const startAngle = pi;
    const sweepAngle = pi;

    final bgPaint = Paint()
      ..color      = Colors.grey.shade100
      ..strokeWidth = 16
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, bgPaint);

    if (progress > 0) {
      final fgPaint = Paint()
        ..color      = color
        ..strokeWidth = 16
        ..style      = PaintingStyle.stroke
        ..strokeCap  = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, sweepAngle * progress, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}

class _PDFViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String patientName;
  final String language;
  final Future<String?> Function() getDownloadsPath;

  const _PDFViewerScreen({
    required this.pdfPath,
    required this.patientName,
    required this.language,
    required this.getDownloadsPath,
  });

  @override
  State<_PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<_PDFViewerScreen> {
  bool _isDownloading = false;

  bool get isHindi => widget.language == 'Hindi';
  String t(String en, String hi) => isHindi ? hi : en;

  // ✅ FIXED _downloadPDF for Android
Future<void> _downloadPDF() async {
  setState(() => _isDownloading = true);
  try {
    final now = DateTime.now();
    final fileName = 'Saheli_${widget.patientName.replaceAll(' ', '_')}_${now.day}${now.month}${now.year}.pdf';
    final bytes = await File(widget.pdfPath).readAsBytes();

    if (Platform.isAndroid) {
      // Android 10+ (API 29+): no permission needed for Downloads
      // Android 9 and below: request permission
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        // Proceed anyway — Downloads folder may still be writable
      }
      
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final savedPath = '${downloadsDir.path}/$fileName';
      await File(savedPath).writeAsBytes(bytes);
      await _mediaScan(savedPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ ${t('Saved to Downloads', 'Downloads में सेव हुआ')}: $fileName'),
          backgroundColor: const Color(0xFFE91E8C),
          duration: const Duration(seconds: 5),
        ));
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
    }
  } finally {
    setState(() => _isDownloading = false);
  }
}

  Future<void> _mediaScan(String filePath) async {
    const platform =
        MethodChannel('com.example.saheli/media_scanner');
    try {
      await platform.invokeMethod('scanFile', {'path': filePath});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text(t('Referral Slip', 'रेफरल स्लिप'),
            style: TextStyle(fontSize: sw * 0.045)),
        backgroundColor: const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
        actions: [
          _isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)))
              : IconButton(
                  onPressed: _downloadPDF,
                  icon: const Icon(Icons.download),
                  tooltip:
                      t('Save to Downloads', 'डाउनलोड में सेव करें'),
                ),
        ],
      ),
      body: PDFView(
        filePath: widget.pdfPath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        fitPolicy: FitPolicy.BOTH,
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('PDF Error: $error'),
                backgroundColor: Colors.red));
          }
        },
      ),
    );
  }
}