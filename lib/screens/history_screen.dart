import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/prediction_record.dart';
import '../services/export_service.dart';
import '../services/history_service.dart';
import '../services/ph_analyzer.dart';

Map<String, int> _readImageDimensionsHistory(String path) {
  final img = PHAnalyzer.loadAndNormalizeImage(path);
  return {'w': img.width, 'h': img.height};
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<PredictionRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final records = await HistoryService.getAllRecords();
    if (mounted) {
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Record'),
            content: const Text('Are you sure you want to delete this pH analysis record?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Color _getPhColor(double ph) {
    if (ph < 3.0) return const Color(0xFFE53935);
    if (ph < 5.0) return const Color(0xFFFB8C00);
    if (ph < 6.5) return const Color(0xFFFDD835);
    if (ph <= 7.5) return const Color(0xFF43A047);
    if (ph < 10.0) return const Color(0xFF1E88E5);
    if (ph < 12.0) return const Color(0xFF3949AB);
    return const Color(0xFF8E24AA);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis History'),
        centerTitle: true,
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear All History',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All History'),
                    content: const Text('This will permanently delete all saved pH records and images from local storage.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await HistoryService.clearAll();
                  _loadHistory();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 72, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No saved predictions yet',
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Saved edge-computing readings will appear here.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final phColor = _getPhColor(record.phValue);
                    final file = File(record.imagePath);

                    return Dismissible(
                      key: ValueKey(record.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(context),
                      onDismissed: (_) async {
                        await HistoryService.deleteRecord(record);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Record deleted')),
                        );
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _RecordDetailScreen(record: record),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: theme.colorScheme.surfaceContainerHighest,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: file.existsSync()
                                      ? Image.file(file, fit: BoxFit.cover)
                                      : const Icon(Icons.image_not_supported, color: Colors.grey),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: phColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: phColor, width: 1.5),
                                            ),
                                            child: Text(
                                              'pH ${record.phValue.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: phColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${record.timestamp.month}/${record.timestamp.day}/${record.timestamp.year}',
                                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        record.note != null && record.note!.isNotEmpty
                                            ? record.note!
                                            : 'No additional notes',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: record.note != null && record.note!.isNotEmpty
                                              ? theme.colorScheme.onSurface
                                              : Colors.grey,
                                          fontStyle: record.note != null && record.note!.isNotEmpty
                                              ? FontStyle.normal
                                              : FontStyle.italic,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _RecordDetailScreen extends StatefulWidget {
  final PredictionRecord record;

  const _RecordDetailScreen({required this.record});

  @override
  State<_RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<_RecordDetailScreen> {
  int _imgWidth = 0;
  int _imgHeight = 0;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    final file = File(widget.record.imagePath);
    if (!file.existsSync()) return;
    try {
      final dims = await compute(_readImageDimensionsHistory, file.path);
      if (mounted) {
        setState(() {
          _imgWidth = dims['w'] as int;
          _imgHeight = dims['h'] as int;
        });
      }
    } catch (_) {}
  }

  Color _getPhColor(double ph) {
    if (ph < 3.0) return const Color(0xFFE53935);
    if (ph < 5.0) return const Color(0xFFFB8C00);
    if (ph < 6.5) return const Color(0xFFFDD835);
    if (ph <= 7.5) return const Color(0xFF43A047);
    if (ph < 10.0) return const Color(0xFF1E88E5);
    if (ph < 12.0) return const Color(0xFF3949AB);
    return const Color(0xFF8E24AA);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = widget.record;
    final phColor = _getPhColor(record.phValue);
    final file = File(record.imagePath);

    final bool hasOverlays = record.dyeLeft != null &&
        record.dyeTop != null &&
        record.dyeWidth != null &&
        record.dyeHeight != null &&
        record.bgLeft != null &&
        record.bgTop != null &&
        record.bgWidth != null &&
        record.bgHeight != null;

    final Rect? dyeRect = hasOverlays
        ? Rect.fromLTWH(record.dyeLeft!, record.dyeTop!, record.dyeWidth!, record.dyeHeight!)
        : null;
    final Rect? bgRect = hasOverlays
        ? Rect.fromLTWH(record.bgLeft!, record.bgTop!, record.bgWidth!, record.bgHeight!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prediction Detail'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: phColor, width: 2),
                boxShadow: [
                  BoxShadow(color: phColor.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  Text('STORED pH READING', style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 6),
                  Text(
                    record.phValue.toStringAsFixed(2),
                    style: TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: phColor, height: 1.0),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Recorded on ${record.timestamp}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (record.note != null && record.note!.isNotEmpty) ...[
              Text('Notes / Observations', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(record.note!, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 24),
            ],
            Text('Captured Strip Image & Overlays', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              height: 340,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: !file.existsSync()
                  ? const Center(child: Text('Image file not found on local device'))
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(file, fit: BoxFit.contain),
                        if (hasOverlays && _imgWidth > 0 && _imgHeight > 0)
                          CustomPaint(
                            painter: _StoredROIPainter(
                              dyeRect: dyeRect!,
                              bgRect: bgRect!,
                              imgWidth: _imgWidth,
                              imgHeight: _imgHeight,
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () async {
                if (!file.existsSync() || dyeRect == null || bgRect == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot export report without image and ROI overlay data.')),
                  );
                  return;
                }
                await ExportService.sharePhReport(
                  imagePath: record.imagePath,
                  dyeRect: dyeRect,
                  bgRect: bgRect,
                  phValue: record.phValue,
                  note: record.note,
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export & Share PDF Report', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoredROIPainter extends CustomPainter {
  final Rect dyeRect;
  final Rect bgRect;
  final int imgWidth;
  final int imgHeight;

  _StoredROIPainter({
    required this.dyeRect,
    required this.bgRect,
    required this.imgWidth,
    required this.imgHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imgWidth <= 0 || imgHeight <= 0 || size.width <= 0 || size.height <= 0) return;

    final double scaleX = size.width / imgWidth;
    final double scaleY = size.height / imgHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double displayedWidth = imgWidth * scale;
    final double displayedHeight = imgHeight * scale;
    final double offsetX = (size.width - displayedWidth) / 2.0;
    final double offsetY = (size.height - displayedHeight) / 2.0;

    final mappedDye = Rect.fromLTRB(
      dyeRect.left * scale + offsetX,
      dyeRect.top * scale + offsetY,
      dyeRect.right * scale + offsetX,
      dyeRect.bottom * scale + offsetY,
    );

    final mappedBg = Rect.fromLTRB(
      bgRect.left * scale + offsetX,
      bgRect.top * scale + offsetY,
      bgRect.right * scale + offsetX,
      bgRect.bottom * scale + offsetY,
    );

    final redBorder = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(mappedDye, redBorder);

    final blueBorder = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(mappedBg, blueBorder);
  }

  @override
  bool shouldRepaint(covariant _StoredROIPainter oldDelegate) => false;
}
