import 'package:flutter/material.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import 'trend_graph_screen.dart';
class HistoryScreen extends StatefulWidget {
  final int userId;
  final String language;

  const HistoryScreen({
    super.key,
    required this.userId,
    required this.language,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _screenings = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterLevel = 'All';

  bool get isHindi => widget.language == 'Hindi';
  String t(String english, String hindi) => isHindi ? hindi : english;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final data =
        await DatabaseHelper.instance.getScreeningsByUser(widget.userId);
    setState(() {
      _screenings = data;
      _filtered = data;
      _isLoading = false;
    });
  }

  void _applyFilter() {
    setState(() {
      _filtered = _screenings.where((s) {
        final matchesSearch = _searchQuery.isEmpty ||
            s['patientName']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
        final matchesLevel =
            _filterLevel == 'All' || s['riskLevel'] == _filterLevel;
        return matchesSearch && matchesLevel;
      }).toList();
    });
  }

  Future<void> _deleteScreening(int id) async {
    await DatabaseHelper.instance.deleteScreening(id);
    await _loadHistory();
  }

  // ── PDF Generation ────────────────────────────────────────

  double _saheliScore(Map<String, dynamic> s) {
    final stored = s['saheliScore'];
  if (stored != null && (stored as double) > 0) {
    return stored.clamp(0.0, 10.0);
  }
  // Fallback for old records only
  final symptomCount = [
    s['fatigue'], s['dizziness'], s['paleSkin'],
    s['shortnessOfBreath'], s['heavyPeriods'], s['headache'],
  ].where((v) => v == 1).length;
  final mlScore = s['mlScore'] as double;
  return ((mlScore * 6.0) + (symptomCount / 6.0) * 2.5).clamp(0.0, 10.0);
  }

  String _hbRange(double score) {
    if (score >= 7.5) return '7.0 – 8.5 g/dL';
    if (score >= 5.5) return '8.5 – 10.0 g/dL';
    if (score >= 3.5) return '10.0 – 11.5 g/dL';
    return '11.5 – 13.0 g/dL';
  }

  Map<String, String> _whoBadge(double score) {
    if (score >= 7.5) {
      return {
        'label': isHindi ? 'गंभीर रक्ताल्पता' : 'Severe Anaemia',
        'sub': isHindi ? 'Hb संभवतः < 8 g/dL' : 'Hb likely < 8 g/dL',
      };
    }
    if (score >= 5.5) {
      return {
        'label': isHindi ? 'मध्यम रक्ताल्पता' : 'Moderate Anaemia',
        'sub': isHindi ? 'Hb संभवतः 8–10 g/dL' : 'Hb likely 8–10 g/dL',
      };
    }
    if (score >= 3.5) {
      return {
        'label': isHindi ? 'हल्की रक्ताल्पता' : 'Mild Anaemia',
        'sub': isHindi ? 'Hb संभवतः 10–12 g/dL' : 'Hb likely 10–12 g/dL',
      };
    }
    return {
      'label': isHindi ? 'सामान्य' : 'Normal',
      'sub': isHindi ? 'Hb संभवतः > 12 g/dL' : 'Hb likely > 12 g/dL',
    };
  }

  String _action(double score) {
    if (score >= 7.5) {
      return isHindi
          ? 'तुरंत डॉक्टर से मिलें। CBC टेस्ट जरूरी है।'
          : 'Visit a doctor immediately. CBC blood test required.';
    }
    if (score >= 5.5) {
      return isHindi
          ? '24 घंटे में रक्त परीक्षण कराएं।'
          : 'Book a blood test within 24 hours.';
    }
    if (score >= 3.5) {
      return isHindi
          ? '48 घंटे में हीमोग्लोबिन टेस्ट कराएं।'
          : 'Get a haemoglobin test within 48 hours.';
    }
    return isHindi
        ? 'कोई कार्रवाई आवश्यक नहीं। आयरन युक्त आहार लें।'
        : 'No action needed. Maintain iron-rich diet.';
  }
  bool _hasDevanagari(String text) {
  return text.runes.any((r) => r >= 0x0900 && r <= 0x097F);
}

  Future<String> _generatePDF(Map<String, dynamic> s) async {
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

  final score  = _saheliScore(s);
  final badge  = _whoBadge(score);
  final hb     = _hbRange(score);
  final action = _action(score);
  final now    = DateTime.now();
  final dateStr = '${now.day}/${now.month}/${now.year}  ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

  final symptoms = <String>[
    if (s['fatigue'] == 1) t('Fatigue', 'थकान'),
    if (s['dizziness'] == 1) t('Dizziness', 'चक्कर'),
    if (s['paleSkin'] == 1) t('Pale Skin', 'पीली त्वचा'),
    if (s['shortnessOfBreath'] == 1) t('Breathlessness', 'सांस की कमी'),
    if (s['heavyPeriods'] == 1) t('Heavy Periods', 'भारी माहवारी'),
    if (s['headache'] == 1) t('Headache', 'सिरदर्द'),
  ];

  final headerLabel  = t('Saheli Referral Slip', 'सहेली रेफरल स्लिप');
  final patientLabel = t('PATIENT DETAILS', 'मरीज की जानकारी');
  final assessLabel  = t('CLINICAL ASSESSMENT', 'नैदानिक मूल्यांकन');
  final actionLabel  = t('RECOMMENDED ACTION', 'अनुशंसित कार्रवाई');
  final whoLabel     = t('WHO Classification', 'WHO वर्गीकरण');
  final scoreLabel   = t('Saheli Score', 'सहेली स्कोर');
  final hbLabel      = t('Est. Hb:', 'अनु. Hb:');
  final nameLabel    = t('Name', 'नाम');
  final ageLabel     = t('Age', 'आयु');
  final yearsLabel   = t('years', 'वर्ष');
  final reasonLabel  = t('Reason', 'कारण');
  final weekLabel    = t('Pregnancy Week', 'गर्भ सप्ताह');
  final sympLabel    = t('Symptoms', 'लक्षण');
  final noneLabel    = t('None', 'कोई नहीं');
  final dateLabel    = t('Date:', 'दिनांक:');
  final disclaimer   = t(
    'DISCLAIMER: Generated by Saheli. Not a medical diagnosis. Consult a qualified healthcare professional.',
    'अस्वीकरण: सहेली द्वारा निर्मित। चिकित्सा निदान नहीं। योग्य स्वास्थ्य पेशेवर से परामर्श लें।',
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
            pw.Text('SAHELI', style: ts(28, bold: true, color: PdfColors.white, text: 'SAHELI')),
            pw.SizedBox(height: 4),
            pw.Text(headerLabel, style: ts(14, color: PdfColors.white, text: headerLabel)),
            pw.SizedBox(height: 4),
            pw.Text('$dateLabel $dateStr', style: ts(11, color: PdfColors.white,text: '$dateLabel $dateStr')),
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
              pw.Text(scoreLabel, style: ts(10, color: PdfColors.grey700, text: scoreLabel)),
              pw.SizedBox(height: 6),
              pw.Text('${score.toStringAsFixed(1)} / 10',
                  style: ts(22, bold: true, color: PdfColor.fromHex('E91E8C'),text: '${score.toStringAsFixed(1)} / 10')),
              pw.SizedBox(height: 6),
              pw.Text(hbLabel, style: ts(9, color: PdfColors.grey600,text: hbLabel)),
              pw.Text(hb, style: ts(10, bold: true,text: hb)),
            ]),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: score >= 7.5 ? PdfColors.red50
                    : score >= 5.5 ? PdfColors.orange50
                    : score >= 3.5 ? PdfColors.yellow50
                    : PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(whoLabel, style: ts(10, color: PdfColors.grey700,text: whoLabel)),
                pw.SizedBox(height: 6),
                pw.Text(badge['label']!, style: ts(16, bold: true,text: badge['label']!)),
                pw.SizedBox(height: 4),
                pw.Text(badge['sub']!, style: ts(11, color: PdfColors.grey700,text: badge['sub']!)),
              ]),
            ),
          ),
        ]),
        pw.SizedBox(height: 20),
        pw.Text(patientLabel, style: ts(12, bold: true, color: PdfColors.grey800,text: patientLabel)),
        pw.Divider(),
        pw.SizedBox(height: 8),
        _pdfRow(nameLabel,   s['patientName'], ts),
        _pdfRow(ageLabel,    '${s['age']} $yearsLabel', ts),
        _pdfRow(reasonLabel, s['reason'], ts),
        if (s['reason'] == 'Pregnancy' && s['pregnancyWeeks'] != null)
          _pdfRow(weekLabel, 'Week ${s['pregnancyWeeks']}', ts),
        _pdfRow(sympLabel, symptoms.isEmpty ? noneLabel : symptoms.join(', '), ts),
        pw.SizedBox(height: 20),
        pw.Text(assessLabel, style: ts(12, bold: true, color: PdfColors.grey800,text: assessLabel)),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(s['clinicalNote'], style: ts(12,text: s['clinicalNote'])),
        pw.SizedBox(height: 20),
        pw.Text(actionLabel, style: ts(12, bold: true, color: PdfColors.grey800,text: actionLabel)),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(action, style: ts(13, bold: true,text: action)),
        pw.Spacer(),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(disclaimer, style: ts(9, color: PdfColors.grey600,text: disclaimer)),
      ],
    ),
  ));

  final tempDir  = await getTemporaryDirectory();
  final fileName = 'Saheli_${s['patientName'].toString().replaceAll(' ', '_')}_${now.millisecondsSinceEpoch}.pdf';
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(await pdf.save());
  return file.path;
}

pw.Widget _pdfRow(String label, String value,
    pw.TextStyle Function(double, {bool bold, PdfColor? color, String? text}) ts) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
            width: 160,
            child: pw.Text(label, style: ts(11, color: PdfColors.grey700, text: label))),
        pw.Expanded(
            child: pw.Text(value, style: ts(11, bold: true, text: value))),
      ]),
    );

  Future<void> _viewSlip(
      BuildContext context, Map<String, dynamic> s) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child:
              CircularProgressIndicator(color: Color(0xFFE91E8C))),
    );
    try {
      final pdfPath = await _generatePDF(s);
      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PDFViewerScreen(
            pdfPath: pdfPath,
            patientName: s['patientName'],
            language: widget.language,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── UI helpers ────────────────────────────────────────────

  Color _riskColor(String level) {
    switch (level) {
      case 'high':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'borderline':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  String _riskLabel(String level) {
    switch (level) {
      case 'high':
        return t('High Risk', 'उच्च जोखिम');
      case 'moderate':
        return t('Moderate', 'मध्यम जोखिम');
      case 'borderline':
        return t('Borderline', 'सीमारेखा');
      default:
        return t('Low Risk', 'कम जोखिम');
    }
  }

  IconData _riskIcon(String level) {
    switch (level) {
      case 'high':
        return Icons.error;
      case 'moderate':
        return Icons.warning_amber;
      case 'borderline':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }

  String _formatDate(String isoDate) {
    final dt = DateTime.parse(isoDate);
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: Text(t('Screening History', 'जांच इतिहास')),
        backgroundColor: const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFE91E8C)))
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (val) {
                          _searchQuery = val;
                          _applyFilter();
                        },
                        decoration: InputDecoration(
                          hintText: t('Search by patient name...',
                              'नाम से खोजें...'),
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFFE91E8C)),
                          filled: true,
                          fillColor: const Color(0xFFFFF0F5),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('All', t('All', 'सभी')),
                            const SizedBox(width: 8),
                            _filterChip('high',
                                t('High Risk', 'उच्च जोखिम')),
                            const SizedBox(width: 8),
                            _filterChip('moderate',
                                t('Moderate', 'मध्यम जोखिम')),
                            const SizedBox(width: 8),
                            _filterChip(
                                'low', t('Low Risk', 'कम जोखिम')),
                            const SizedBox(width: 8),
                            _filterChip('borderline',
                                t('Borderline', 'सीमारेखा')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${_filtered.length} ${t('records', 'रिकॉर्ड')}',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 56,
                                  color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                t('No records found.',
                                    'कोई रिकॉर्ड नहीं मिला।'),
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              16, 0, 16, 20),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final s = _filtered[index];
                            return _screeningCard(s);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String value, String label) {
    final isSelected = _filterLevel == value;
    return GestureDetector(
      onTap: () {
        _filterLevel = value;
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE91E8C)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _screeningCard(Map<String, dynamic> s) {
    final level = s['riskLevel'] as String;
    final color = _riskColor(level);
    final symptoms = <String>[
      if (s['fatigue'] == 1) t('Fatigue', 'थकान'),
      if (s['dizziness'] == 1) t('Dizziness', 'चक्कर'),
      if (s['paleSkin'] == 1) t('Pale Skin', 'पीली त्वचा'),
      if (s['shortnessOfBreath'] == 1)
        t('Breathlessness', 'सांस की कमी'),
      if (s['heavyPeriods'] == 1) t('Heavy Periods', 'भारी माहवारी'),
      if (s['headache'] == 1) t('Headache', 'सिरदर्द'),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_riskIcon(level), color: color, size: 22),
          ),
          title: Text(
            s['patientName'],
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text(
            '${s['age']} ${t('yrs', 'वर्ष')}  •  ${_formatDate(s['screenedAt'])}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _riskLabel(level),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
              ),
              const Icon(Icons.expand_more, color: Colors.grey),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 6),
                  _detailRow(t('Reason', 'कारण'), s['reason']),
                  if (s['pregnancyWeeks'] != null)
                    _detailRow(
                        t('Pregnancy Week', 'गर्भावस्था सप्ताह'),
                        'Week ${s['pregnancyWeeks']}'),
                  _detailRow(
                    t('Pallor Score', 'पीलापन स्कोर'),
                    '${((s['mlScore'] as num) * 100).toStringAsFixed(1)}%',
                  ),
                  _detailRow(
                    t('Risk Score', 'जोखिम स्कोर'),
                    '${((s['riskScore'] as num) * 100).toStringAsFixed(1)}%',
                  ),
                  if (symptoms.isNotEmpty)
                    _detailRow(t('Symptoms', 'लक्षण'),
                        symptoms.join(', ')),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Text(
                      s['clinicalNote'],
                      style:
                          const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Action buttons ──────────────────────
                  Column(
  children: [
    // Trend Graph — full width
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrendGraphScreen(
              userId: widget.userId,
              patientName: s['patientName'],
              language: widget.language,
            ),
          ),
        ),
        icon: const Icon(Icons.show_chart,
            size: 18, color: Color(0xFF7C3AED)),
        label: Text(
          t('View Risk Trend', 'जोखिम ट्रेंड देखें'),
          style: const TextStyle(
              color: Color(0xFF7C3AED), fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF7C3AED)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
    const SizedBox(height: 8),
    // View Slip + Delete
    Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _viewSlip(context, s),
            icon: const Icon(Icons.picture_as_pdf,
                size: 18, color: Color(0xFFE91E8C)),
            label: Text(
              t('View Slip', 'स्लिप देखें'),
              style: const TextStyle(
                  color: Color(0xFFE91E8C), fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE91E8C)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(t('Delete Record', 'रिकॉर्ड हटाएं')),
                content: Text(t(
                    'Are you sure you want to delete this screening?',
                    'क्या आप यह रिकॉर्ड हटाना चाहते हैं?')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('Cancel', 'रद्द करें')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteScreening(s['id']);
                    },
                    child: Text(t('Delete', 'हटाएं'),
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Colors.red),
            label: Text(t('Delete', 'हटाएं'),
                style:
                    const TextStyle(color: Colors.red, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    ),
  ],
),
    ]),
        )],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── PDF Viewer + Download ─────────────────────────────────────

class _PDFViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String patientName;
  final String language;

  const _PDFViewerScreen({
    required this.pdfPath,
    required this.patientName,
    required this.language,
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
                  tooltip: t('Save to Downloads',
                      'डाउनलोड में सेव करें'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('PDF Error: $error'),
                  backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }
}