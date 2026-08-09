import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/prediction_record.dart';
import '../services/history_service.dart';
import '../theme/lab_theme.dart';
import '../widgets/dashed_circle_painter.dart';
import 'guide_screen.dart';
import 'history_screen.dart';
import 'live_camera_screen.dart';
import 'roi_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomNavIndex = 0;
  List<PredictionRecord> _recentRecords = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadRecentRecords());
  }

  Future<void> _loadRecentRecords() async {
    try {
      final records = await HistoryService.getAllRecords();
      if (mounted) {
        setState(() {
          _recentRecords = records;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recentRecords = [];
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null && context.mounted) {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ROISelector(imagePath: image.path),
          ),
        );
        if (result == true) {
          _loadRecentRecords();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showScanOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Scan Dye Paper',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose how you want to capture your pH dye paper strip',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context)
                        .push(
                      MaterialPageRoute(
                          builder: (_) => const LiveCameraScreen()),
                    )
                        .then((_) => _loadRecentRecords());
                  },
                  icon: const Icon(Icons.videocam_rounded, size: 22),
                  label: const Text('Use Live Camera',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImage(context, ImageSource.camera);
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 22),
                  label: const Text('Take Quick Photo',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImage(context, ImageSource.gallery);
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 22),
                  label: const Text('Choose from Photo Gallery',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.settings_outlined,
                          color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'App Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const ListTile(
                  leading: Icon(Icons.memory, color: Color(0xFF2563EB)),
                  title: Text('Edge Analysis Engine'),
                  subtitle: Text('Local Natural Cubic Spline over CIELAB space'),
                ),
                const ListTile(
                  leading: Icon(Icons.security, color: Color(0xFF2563EB)),
                  title: Text('Privacy First'),
                  subtitle: Text('100% Offline processing. Zero cloud image uploads.'),
                ),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                  title: Text('pH Lens Version'),
                  subtitle: Text('1.0.0 (Build 1)'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildHeaderBar(context),
                      const SizedBox(height: 24),
                      _buildMainTitle(),
                      const SizedBox(height: 12),
                      _buildCameraReadyStatus(),
                      const SizedBox(height: 20),
                      _buildHeroScanCard(context),
                      const SizedBox(height: 28),
                      _buildRecentMeasurementsHeader(context),
                      const SizedBox(height: 16),
                      _buildRecentMeasurementsList(),
                      const SizedBox(height: 100), // Spacing above bottom bar
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            // Flask / Beaker Icon
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Image.asset(
                'assets/logo.png',
                width: 38,
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.science, size: 36, color: Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'pH ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D1D41),
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextSpan(
                        text: 'Lens',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Digital Colorimetric Analysis',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Settings Gear Action Button
        InkWell(
          onTap: () => _showSettingsModal(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.settings_outlined,
              size: 22,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainTitle() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
          height: 1.25,
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(text: 'Measure '),
          TextSpan(
            text: 'pH',
            style: TextStyle(color: Color(0xFF2563EB)),
          ),
          TextSpan(text: ' from\ndye paper in seconds'),
        ],
      ),
    );
  }

  Widget _buildCameraReadyStatus() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Camera ready',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroScanCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEFF6FF),
            Color(0xFFF8FAFC),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Concentric Camera Scan Button
          GestureDetector(
            onTap: () => _showScanOptionsModal(context),
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer dashed circle
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: DashedCirclePainter(
                      color: const Color(0xFFCBD5E1),
                      strokeWidth: 1.5,
                      dashCount: 40,
                      gapRatio: 0.45,
                    ),
                  ),
                  // Middle translucent ring
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Center gradient action button
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF3B82F6),
                          Color(0xFF7C3AED),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Scan Dye Paper',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap to open camera',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),

          // 3-Step Workflow Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildWorkflowStep(
                  stepNumber: '1',
                  badgeColor: const Color(0xFFDCFCE7),
                  iconColor: const Color(0xFF16A34A),
                  icon: Icons.center_focus_weak,
                  title: '1. Place',
                  description: 'Place the dye paper\nin good lighting',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _buildDottedLineConnector(),
              ),
              Expanded(
                child: _buildWorkflowStep(
                  stepNumber: '2',
                  badgeColor: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF2563EB),
                  icon: Icons.camera_alt_outlined,
                  title: '2. Capture',
                  description: 'Take a clear photo\nwithin the frame',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _buildDottedLineConnector(),
              ),
              Expanded(
                child: _buildWorkflowStep(
                  stepNumber: '3',
                  badgeColor: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF9333EA),
                  icon: Icons.science_outlined,
                  title: '3. Get pH',
                  description: 'Instant pH result\nwith confidence',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep({
    required String stepNumber,
    required Color badgeColor,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDottedLineConnector() {
    return SizedBox(
      width: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          4,
          (index) => Container(
            width: 3,
            height: 1.5,
            color: const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentMeasurementsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Recent Measurements',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context)
                .push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            )
                .then((_) => _loadRecentRecords());
          },
          child: const Row(
            children: [
              Text(
                'See all',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFF2563EB),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentMeasurementsList() {
    if (_isLoadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_recentRecords.isNotEmpty) {
      return Column(
        children: _recentRecords.take(3).map((record) {
          final String category = LabTheme.getPhCategory(record.phValue);
          final Color categoryColor = LabTheme.getPhColor(record.phValue);
          final String timeAgo = _formatRelativeTime(record.timestamp);

          return _buildMeasurementCard(
            phValue: record.phValue,
            statusLabel: category,
            statusColor: categoryColor,
            timeAgo: timeAgo,
            confidence: 94,
            imagePath: record.imagePath,
            onTap: () {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              )
                  .then((_) => _loadRecentRecords());
            },
          );
        }).toList(),
      );
    }

    // Empty state when history has no saved predictions
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 28,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start capturing to see recents',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  Widget _buildMeasurementCard({
    required double phValue,
    required String statusLabel,
    required Color statusColor,
    required String timeAgo,
    required int confidence,
    String? imagePath,
    required VoidCallback onTap,
  }) {
    final bool isGreenSample = phValue >= 6.5 && phValue <= 8.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sample Image Circle
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.15),
                ),
                clipBehavior: Clip.antiAlias,
                child: imagePath != null && File(imagePath).existsSync()
                    ? Image.file(File(imagePath), fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: isGreenSample
                                ? [
                                    const Color(0xFF86EFAC),
                                    const Color(0xFF65A30D),
                                    const Color(0xFF4D7C0F),
                                  ]
                                : [
                                    const Color(0xFFFDE047),
                                    const Color(0xFFF97316),
                                    const Color(0xFFC2410C),
                                  ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),

              // Center pH details & spectrum bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'pH ${phValue.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Spectrum bar with indicator
                    _buildSpectrumBar(phValue),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Right timestamp & confidence pill
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: confidence >= 92
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$confidence%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: confidence >= 92
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEA580C),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Confidence',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpectrumBar(double phValue) {
    final double fraction = (phValue / 14.0).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(
          height: 14,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double barWidth = constraints.maxWidth;
              final double pointerX = (barWidth * fraction).clamp(4.0, barWidth - 4.0);

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // Gradient Bar
                  Container(
                    height: 5,
                    width: barWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFEF4444), // 0 Red
                          Color(0xFFF97316), // 3 Orange
                          Color(0xFFEAB308), // 5 Yellow
                          Color(0xFF22C55E), // 7 Green
                          Color(0xFF06B6D4), // 9 Cyan
                          Color(0xFF3B82F6), // 12 Blue
                          Color(0xFFA855F7), // 14 Purple
                        ],
                      ),
                    ),
                  ),

                  // Pointer Arrow ▼
                  Positioned(
                    left: pointerX - 4,
                    top: -4,
                    child: const Icon(
                      Icons.arrow_drop_down,
                      size: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Scale Labels below bar
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('3', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('6', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('7', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('9', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('12', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('14', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Measure',
                isActive: _currentBottomNavIndex == 0,
                onTap: () {
                  setState(() {
                    _currentBottomNavIndex = 0;
                  });
                },
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.access_time_rounded,
                label: 'History',
                isActive: _currentBottomNavIndex == 1,
                onTap: () {
                  Navigator.of(context)
                      .push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  )
                      .then((_) => _loadRecentRecords());
                },
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.menu_book_outlined,
                label: 'Guide',
                isActive: _currentBottomNavIndex == 2,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuideScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
