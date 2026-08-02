import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show Rect;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'ph_analyzer.dart';
import 'robust_extractor.dart';

class ExportService {
  /// Generates a PDF report inside an Isolate and triggers the OS share sheet.
  static Future<void> sharePhReport({
    required String imagePath,
    required Rect dyeRect,
    Rect? bgRect,
    required double phValue,
    String? note,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final String tempDirPath = tempDir.path;

    final String pdfPath = await Isolate.run(() async {
      final image = PHAnalyzer.loadAndNormalizeImage(imagePath);

      // Crop safely to extract exact RGB values
      final int dyeL = dyeRect.left.floor().clamp(0, image.width - 1);
      final int dyeT = dyeRect.top.floor().clamp(0, image.height - 1);
      final int dyeW = (dyeRect.right.ceil() - dyeL).clamp(1, image.width - dyeL);
      final int dyeH = (dyeRect.bottom.ceil() - dyeT).clamp(1, image.height - dyeT);

      final dyePatch = img.copyCrop(image, x: dyeL, y: dyeT, width: dyeW, height: dyeH);
      final dyeRgb = RobustColorExtractor.extract(dyePatch);

      List<int> bgRgb;
      if (bgRect != null) {
        final int bgL = bgRect.left.floor().clamp(0, image.width - 1);
        final int bgT = bgRect.top.floor().clamp(0, image.height - 1);
        final int bgW = (bgRect.right.ceil() - bgL).clamp(1, image.width - bgL);
        final int bgH = (bgRect.bottom.ceil() - bgT).clamp(1, image.height - bgT);
        final bgPatch = img.copyCrop(image, x: bgL, y: bgT, width: bgW, height: bgH);
        bgRgb = RobustColorExtractor.extract(bgPatch);
      } else {
        bgRgb = const [245, 245, 240];
      }

      // Draw thick colored rectangles over a copy of the image for visual verification in the PDF
      final annotatedImage = image.clone();
      final redColor = img.ColorRgb8(255, 30, 30);
      final blueColor = img.ColorRgb8(30, 144, 255);

      for (int w = 0; w < 4; w++) {
        img.drawRect(
          annotatedImage,
          x1: (dyeL - w).clamp(0, annotatedImage.width - 1),
          y1: (dyeT - w).clamp(0, annotatedImage.height - 1),
          x2: (dyeL + dyeW + w).clamp(0, annotatedImage.width - 1),
          y2: (dyeT + dyeH + w).clamp(0, annotatedImage.height - 1),
          color: redColor,
        );
        if (bgRect != null) {
          final int bgL = bgRect.left.floor().clamp(0, image.width - 1);
          final int bgT = bgRect.top.floor().clamp(0, image.height - 1);
          final int bgW = (bgRect.right.ceil() - bgL).clamp(1, image.width - bgL);
          final int bgH = (bgRect.bottom.ceil() - bgT).clamp(1, image.height - bgT);
          img.drawRect(
            annotatedImage,
            x1: (bgL - w).clamp(0, annotatedImage.width - 1),
            y1: (bgT - w).clamp(0, annotatedImage.height - 1),
            x2: (bgL + bgW + w).clamp(0, annotatedImage.width - 1),
            y2: (bgH + bgT + w).clamp(0, annotatedImage.height - 1),
            color: blueColor,
          );
        }
      }

      final jpgBytes = img.encodeJpg(annotatedImage, quality: 88);
      final pdfImage = pw.MemoryImage(jpgBytes);

      final doc = pw.Document();
      final String category = _getCategory(phValue);
      final PdfColor phColor = _getPdfColor(phValue);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'pH Analysis Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                    ),
                    pw.Text(
                      DateTime.now().toString().split('.').first,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.teal800),
                pw.SizedBox(height: 16),

                // Main Result Callout Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                    border: pw.Border.all(color: phColor, width: 2),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PREDICTED pH VALUE',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            phValue.toStringAsFixed(2),
                            style: pw.TextStyle(
                              fontSize: 42,
                              fontWeight: pw.FontWeight.bold,
                              color: phColor,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: pw.BoxDecoration(
                          color: phColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                        ),
                        child: pw.Text(
                          category.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Note section if present
                if (note != null && note.isNotEmpty) ...[
                  pw.Text(
                    'Notes / Observations:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber50,
                      border: pw.Border.all(color: PdfColors.amber300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Text(note, style: const pw.TextStyle(fontSize: 12)),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // Annotated Image & Color Extraction Table
                pw.Text(
                  'ROI Analysis & Color Verification',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Annotated Image
                    pw.Expanded(
                      flex: 5,
                      child: pw.Container(
                        height: 260,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                        ),
                        child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                      ),
                    ),
                    pw.SizedBox(width: 16),

                    // Details table & color swatches
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildColorRow('Dye Pad (Red ROI)', dyeRgb),
                          pw.SizedBox(height: 12),
                          _buildColorRow(
                            bgRect != null
                                ? 'Reference (Blue ROI)'
                                : 'Reference White (Constant)',
                            bgRgb,
                          ),
                          pw.SizedBox(height: 16),
                          pw.Divider(color: PdfColors.grey300),
                          pw.SizedBox(height: 8),
                          _buildDetailItem('Method', 'Edge Natural Cubic Spline'),
                          _buildDetailItem('Color Space', 'CIELAB (D65 Illuminant)'),
                          _buildDetailItem('Dye ROI', '($dyeL, $dyeT) ${dyeW}x$dyeH'),
                          _buildDetailItem(
                            'Bg Reference',
                            bgRect != null
                                ? '(${bgRect.left.toInt()}, ${bgRect.top.toInt()}) ${bgRect.width.toInt()}x${bgRect.height.toInt()}'
                                : 'Constant [245, 245, 240]',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),

                // Footer
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Generated locally on-device via pH Analyzer',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'Zero-Cloud Edge Computing',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final String targetPdfPath = '$tempDirPath/pH_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(targetPdfPath);
      await file.writeAsBytes(await doc.save());
      return targetPdfPath;
    });

    await Share.shareXFiles(
      [XFile(pdfPath)],
      text: 'On-Device pH Analysis Report: pH ${phValue.toStringAsFixed(2)}',
    );
  }

  static pw.Widget _buildColorRow(String title, List<int> rgb) {
    final pdfRgb = PdfColor.fromInt((0xFF << 24) | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Container(
              width: 24,
              height: 24,
              decoration: pw.BoxDecoration(
                color: pdfRgb,
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: PdfColors.grey600, width: 1),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'RGB(${rgb[0]}, ${rgb[1]}, ${rgb[2]})',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDetailItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static String _getCategory(double ph) {
    if (ph < 3.0) return 'Strongly Acidic';
    if (ph < 6.5) return 'Acidic';
    if (ph <= 7.5) return 'Neutral';
    if (ph < 11.5) return 'Basic / Alkaline';
    return 'Strongly Basic';
  }

  static PdfColor _getPdfColor(double ph) {
    if (ph < 3.0) return PdfColor.fromHex('#E53935'); // Red
    if (ph < 5.0) return PdfColor.fromHex('#FB8C00'); // Orange
    if (ph < 6.5) return PdfColor.fromHex('#FDD835'); // Yellow
    if (ph <= 7.5) return PdfColor.fromHex('#43A047'); // Green
    if (ph < 10.0) return PdfColor.fromHex('#1E88E5'); // Blue
    if (ph < 12.0) return PdfColor.fromHex('#3949AB'); // Indigo
    return PdfColor.fromHex('#8E24AA'); // Purple
  }
}
