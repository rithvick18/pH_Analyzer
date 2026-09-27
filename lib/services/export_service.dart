import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/measurement.dart';
import 'image_geometry.dart';
import 'ph_analyzer.dart';

class ExportService {
  /// Render notes using the device's fonts to preserve Unicode without a network font fetch.
  static Future<Uint8List?> _renderNote(String? note) async {
    if (note == null || note.trim().isEmpty) return null;
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontSize: 24,
              textDirection: ui.TextDirection.ltr,
            ),
          )
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF222222)))
          ..addText(note);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 1000));
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    canvas.drawParagraph(paragraph, ui.Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      1000,
      paragraph.height.ceil().clamp(1, 16000),
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
      paragraph.dispose();
    }
  }

  static Future<void> sharePhReport({
    required String imagePath,
    required ui.Rect dyeRect,
    ui.Rect? bgRect,
    required double phValue,
    String? note,
    Measurement? measurement,
    DateTime? measuredAt,
    ui.Rect? sharePositionOrigin,
  }) async {
    final noteImage = await _renderNote(note);
    final generatedAt = DateTime.now();
    final bytes = await Isolate.run(
      () => createReport(
        imagePath: imagePath,
        dyeRect: dyeRect,
        bgRect: bgRect,
        phValue: phValue,
        measurement: measurement,
        measuredAt: measuredAt,
        generatedAt: generatedAt,
        noteImage: noteImage,
      ),
    );
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/ph_reports',
    );
    await directory.create(recursive: true);
    // Share extensions may read after the share future returns. Retain recent PDFs.
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File &&
          generatedAt.difference(await entry.lastModified()).inHours >= 24) {
        try {
          await entry.delete();
        } on FileSystemException {
          /* Retry on a later export. */
        }
      }
    }
    final file = File('${directory.path}/pH_Report_${const Uuid().v4()}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      text:
          '${measurement?.isDemo == true ? "DEMO - " : ""}Unvalidated pH estimate: ${phValue.toStringAsFixed(1)}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Pure report generation, shared by export and regression tests.
  static Future<Uint8List> createReport({
    required String imagePath,
    required ui.Rect dyeRect,
    ui.Rect? bgRect,
    required double phValue,
    Measurement? measurement,
    DateTime? measuredAt,
    required DateTime generatedAt,
    Uint8List? noteImage,
  }) async {
    if (measurement != null && measurement.ph != phValue) {
      throw ArgumentError('Report and measurement values differ.');
    }
    var image = PHAnalyzer.loadAndNormalizeImage(imagePath);
    // Older records used forced portrait normalization. Preserve their stored ROI coordinate system.
    if (measurement == null && image.width > image.height) {
      image = img.copyRotate(image, angle: 90);
    }
    final dye = ImageGeometry.pixelBounds(image, dyeRect);
    final bg = bgRect == null ? null : ImageGeometry.pixelBounds(image, bgRect);
    for (final item in [
      (dye, img.ColorRgb8(220, 30, 30)),
      (bg, img.ColorRgb8(30, 110, 220)),
    ]) {
      if (item.$1 == null) continue;
      final r = item.$1!;
      img.drawRect(
        image,
        x1: r.left.toInt(),
        y1: r.top.toInt(),
        x2: r.right.toInt() - 1,
        y2: r.bottom.toInt() - 1,
        color: item.$2,
        thickness: 4,
      );
    }
    if (image.width > 1200 || image.height > 1200) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? 1200 : null,
        height: image.height > image.width ? 1200 : null,
      );
    }
    final pdfImage = pw.MemoryImage(img.encodeJpg(image, quality: 85));
    final doc = pw.Document(
      title: 'Unvalidated pH estimate',
      author: 'pH Analyzer',
    );
    pw.Widget line(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text('$label: $value', style: const pw.TextStyle(fontSize: 10)),
    );
    final warnings =
        measurement?.warnings ??
        [
          'Legacy record: calibration, algorithm and validation status were not recorded.',
        ];
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Text(
          'Computed on this device. Unvalidated estimate. Page ${context.pageNumber}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        build: (_) => [
          pw.Text(
            measurement?.isDemo == true
                ? 'DEMO - pH Estimate'
                : 'pH Estimate Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Estimated pH ${phValue.toStringAsFixed(1)}',
            style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'UNVALIDATED ESTIMATE - Strip identity and measurement accuracy are not independently validated.',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.deepOrange900,
            ),
          ),
          pw.SizedBox(height: 12),
          line(
            'Measured',
            (measurement?.measuredAt ?? measuredAt)
                    ?.toUtc()
                    .toIso8601String() ??
                'Not recorded',
          ),
          line('Report generated', generatedAt.toUtc().toIso8601String()),
          line('Source', measurement?.source ?? 'Legacy / unknown'),
          if (measurement != null) ...[
            line('Validation status', measurement.validationStatus),
            line('Calibration', measurement.calibrationId),
            line('Calibration SHA-256', measurement.calibrationHash),
            line('Algorithm', measurement.algorithmVersion),
            line('Dye RGB', measurement.dyeRgb.join(', ')),
            line('Reference RGB', measurement.backgroundRgb.join(', ')),
            line(
              'Delta Lab',
              measurement.deltaLab.map((v) => v.toStringAsFixed(2)).join(', '),
            ),
            line(
              'Color distance (not confidence)',
              measurement.colorDistance.toStringAsFixed(2),
            ),
          ],
          for (final warning in warnings)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Text(warning, style: const pw.TextStyle(fontSize: 10)),
            ),
          pw.SizedBox(height: 12),
          pw.Image(pdfImage, height: 210, fit: pw.BoxFit.contain),
          pw.SizedBox(height: 10),
          line(
            'Dye ROI pixels',
            '${dye.left.toInt()}, ${dye.top.toInt()}, ${dye.width.toInt()} x ${dye.height.toInt()}',
          ),
          line(
            'Reference ROI pixels',
            bg == null
                ? 'Fixed reference assumed'
                : '${bg.left.toInt()}, ${bg.top.toInt()}, ${bg.width.toInt()} x ${bg.height.toInt()}',
          ),
          if (noteImage != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Notes',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Image(pw.MemoryImage(noteImage)),
          ],
        ],
      ),
    );
    return doc.save();
  }
}
