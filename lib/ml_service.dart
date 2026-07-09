import 'dart:io';
import 'package:image/image.dart' as img;

class MLService {

  // ── Main entry point ─────────────────────────────────────────────────
  // Returns {'score': double 0.0–1.0, 'valid': bool}
  // score: 0.0 = perfectly healthy pink, 1.0 = severely pale/anemic
  static Future<Map<String, dynamic>> analyzeEyelid(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return {'score': 0.5, 'valid': false};

      // Resize to standard size
      final resized = img.copyResize(image, width: 300, height: 300);

      // Check if it looks like an eyelid at all
      if (!_isEyelidPhoto(resized)) {
        return {'score': 0.5, 'valid': false};
      }

      final score = _computePallorScore(resized);
      return {'score': score, 'valid': true};

    } catch (e) {
      return {'score': 0.5, 'valid': true};
    }
  }

  // ── Core pallor detection ─────────────────────────────────────────────
  // Scans the image and measures how pale/washed-out the tissue is.
  // Anemic conjunctiva: r ≈ g ≈ b (pale pink or white)
  // Healthy conjunctiva: r >> g, r >> b (deep red/pink)
  static double _computePallorScore(img.Image image) {
    final w = image.width;
    final h = image.height;

    // We scan multiple horizontal strips across the image
    // to find the conjunctiva region (usually a horizontal band)
    final List<double> stripScores = [];

    // Scan 5 horizontal strips
    for (int strip = 1; strip <= 5; strip++) {
      final yCenter = (h * strip / 6).toInt();
      final yStart  = (yCenter - h * 0.06).toInt().clamp(0, h - 1);
      final yEnd    = (yCenter + h * 0.06).toInt().clamp(0, h - 1);

      final List<double> rednessValues = [];

      for (int y = yStart; y < yEnd; y++) {
        for (int x = (w * 0.1).toInt(); x < (w * 0.9).toInt(); x++) {
          final p    = image.getPixel(x, y);
          final r    = p.r / 255.0;
          final g    = p.g / 255.0;
          final b    = p.b / 255.0;
          final lum  = (r + g + b) / 3.0;

          // Skip very dark (shadows) and near-white specular highlights
          if (lum < 0.20 || lum > 0.96) continue;

          // Redness = excess red over the average of other channels
          // High redness = healthy pink tissue
          // Low/negative redness = pale anemic tissue
          final redness = r - (g + b) / 2.0;
          rednessValues.add(redness);
        }
      }

      if (rednessValues.isEmpty) continue;

      rednessValues.sort();
      // Use 25th–75th percentile to ignore outliers
      final p25 = rednessValues[(rednessValues.length * 0.25).toInt()];
      final p75 = rednessValues[(rednessValues.length * 0.75).toInt()];
      final iqrMean = (p25 + p75) / 2.0;
      stripScores.add(iqrMean);
    }

    if (stripScores.isEmpty) return 0.5;

    // Find the strip with LOWEST redness — that's the conjunctiva
    // (it's the palest/most tissue-like strip in an eyelid photo)
    stripScores.sort();
    // Use the average of the bottom 2 strips (most conjunctiva-like)
    final count = stripScores.length < 2 ? stripScores.length : 2;
    final conjunctivaRedness = stripScores
        .sublist(0, count)
        .reduce((a, b) => a + b) / count;

    // Map redness → pallor score
    // Observed ranges from real eyelid photos:
    //   Deep red healthy: redness ≈ 0.25–0.45 → pallor should be 0.0–0.25
    //   Pale anemic:      redness ≈ 0.00–0.10 → pallor should be 0.70–1.00
    //   Borderline:       redness ≈ 0.10–0.25 → pallor should be 0.25–0.70
    //
    // Formula: pallor = 1 - clamp((redness - 0.00) / 0.35, 0, 1)
    final pallor = (1.0 - (conjunctivaRedness / 0.35)).clamp(0.0, 1.0);

    return pallor;
  }

  // ── Eyelid validator ──────────────────────────────────────────────────
  // Returns true if the image has tissue-like pixels (not a random photo)
  static bool _isEyelidPhoto(img.Image image) {
  final w = image.width;
  final h = image.height;
  int tissuePixels = 0;
  int skinPixels   = 0;
  int total        = 0;

  for (int y = (h * 0.2).toInt(); y < (h * 0.8).toInt(); y++) {
    for (int x = (w * 0.1).toInt(); x < (w * 0.9).toInt(); x++) {
      final p   = image.getPixel(x, y);
      final r   = p.r / 255.0;
      final g   = p.g / 255.0;
      final b   = p.b / 255.0;
      final lum = (r + g + b) / 3.0;

      if (lum < 0.20 || lum > 0.95) { total++; continue; }

      // Strict tissue: red MUST dominate both green AND blue
      final isRedDominant = r > g + 0.04 && r > b + 0.04;

      // Skin-tone range: pinkish-red hues only
      // Rejects blue sky, green trees, yellow food etc.
      final isSkinTone = r > 0.35 &&
                         r > g * 1.08 &&
                         b < 0.72 &&
                         (r - b) > 0.05;

      if (isRedDominant && lum > 0.25 && lum < 0.92) tissuePixels++;
      if (isSkinTone) skinPixels++;
      total++;
    }
  }

  if (total == 0) return false;

  final tissueRatio = tissuePixels / total;
  final skinRatio   = skinPixels   / total;

  // BOTH conditions must pass:
  // 1. Enough red-dominant tissue pixels (conjunctiva / eyelid tissue)
  // 2. Enough skin-tone pixels (surrounding eyelid skin)
  return tissueRatio > 0.18 && skinRatio > 0.20;
}

  // ── Risk calculator ───────────────────────────────────────────────────
  // mlScore: 0.0 = healthy, 1.0 = anemic
  // This is the SINGLE source of truth — called only from patient_form_screen
  static Map<String, dynamic> calculateRisk({
    required double mlScore,
    required int    age,
    required String reason,
    required int?   pregnancyWeeks,
    required Map<String, bool> symptoms,
  }) {
    final symptomCount = symptoms.values.where((v) => v).length;
    String riskLevel;
    String clinicalNote;
    double finalScore = mlScore;

    if (mlScore < 0.30) {
      // Healthy conjunctiva
      if (symptomCount == 0) {
        riskLevel    = 'low';
        clinicalNote = 'Conjunctiva appears healthy and well-perfused. No significant anaemia indicators detected.';
      } else if (symptomCount <= 2) {
        finalScore  += symptomCount * 0.03;
        riskLevel    = 'low';
        clinicalNote = 'Conjunctiva looks normal. Minor symptoms noted — maintain an iron-rich diet.';
      } else {
        finalScore   = 0.38;
        riskLevel    = 'borderline';
        clinicalNote = 'Conjunctiva appears normal but multiple symptoms present. A haemoglobin test is recommended.';
      }
    } else if (mlScore < 0.50) {
      // Mild pallor
      if (symptomCount == 0) {
        riskLevel    = 'borderline';
        clinicalNote = 'Mild conjunctival pallor observed. Haemoglobin test advised within 48–72 hours.';
      } else if (symptomCount <= 2) {
        finalScore  += 0.07;
        riskLevel    = 'moderate';
        clinicalNote = 'Mild pallor with supporting symptoms. Haemoglobin test recommended within 48 hours.';
      } else {
        finalScore  += 0.13;
        riskLevel    = 'moderate';
        clinicalNote = 'Mild pallor with several symptoms. Blood test strongly recommended within 24 hours.';
      }
    } else if (mlScore < 0.70) {
      // Moderate pallor
      if (symptomCount == 0) {
        riskLevel    = 'moderate';
        clinicalNote = 'Moderate conjunctival pallor detected. Blood test recommended within 24 hours.';
      } else if (symptomCount <= 3) {
        finalScore  += symptomCount * 0.04;
        riskLevel    = 'moderate';
        clinicalNote = 'Moderate pallor with matching symptoms. Haemoglobin test within 24 hours strongly advised.';
      } else {
        finalScore  += 0.12;
        riskLevel    = 'high';
        clinicalNote = 'Moderate pallor with many symptoms. Doctor consultation advised today.';
      }
    } else {
      // Significant pallor — clearly anemic
      if (symptomCount == 0) {
        finalScore   = 0.72;
        riskLevel    = 'high';
        clinicalNote = 'Significant conjunctival pallor detected. Immediate blood test strongly advised.';
      } else if (symptomCount <= 2) {
        riskLevel    = 'high';
        clinicalNote = 'Significant pallor with supporting symptoms. Immediate blood test and doctor consultation required.';
      } else {
        finalScore  += symptomCount * 0.012;
        riskLevel    = 'high';
        clinicalNote = 'Significant pallor with multiple symptoms. Seek immediate medical attention.';
      }
    }

    if (reason == 'Pregnancy') {
      finalScore += 0.06;
      if (riskLevel == 'low') riskLevel = 'borderline';
    }

    return {
      'score': finalScore.clamp(0.0, 0.95),
      'level': riskLevel,
      'note':  clinicalNote,
    };
  }
}