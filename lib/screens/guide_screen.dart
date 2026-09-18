import 'package:flutter/material.dart';
import 'live_camera_screen.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'pH Lens Guide',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderBanner(),
                    const SizedBox(height: 24),
                    const Text(
                      'Step-by-Step Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildStepCard(
                      stepNumber: '01',
                      title: 'Prepare Reference Paper & Dye Strip',
                      badgeColor: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF16A34A),
                      icon: Icons.grid_view_rounded,
                      description:
                          'Place your wet pH dye strip directly onto the clean white reference background paper. Ensure ambient lighting is uniform and free from harsh glares or heavy shadows.',
                    ),
                    const SizedBox(height: 12),
                    _buildStepCard(
                      stepNumber: '02',
                      title: 'Capture a Clear Image',
                      badgeColor: const Color(0xFFDBEAFE),
                      iconColor: const Color(0xFF2563EB),
                      icon: Icons.camera_alt_rounded,
                      description:
                          'Hold your device flat directly above the test strip. Use the Live Camera or select a photo from your gallery. Ensure both the dye pad and surrounding white reference paper are visible.',
                    ),
                    const SizedBox(height: 12),
                    _buildStepCard(
                      stepNumber: '03',
                      title: 'Select Regions of Interest (ROI)',
                      badgeColor: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF9333EA),
                      icon: Icons.crop_free_rounded,
                      description:
                          'Draw a Red bounding box around the active dye pad and a Blue bounding box around the white reference paper. Outlier pixels like specular highlights are automatically filtered out.',
                    ),
                    const SizedBox(height: 12),
                    _buildStepCard(
                      stepNumber: '04',
                      title: 'Edge-Computing pH Calculation',
                      badgeColor: const Color(0xFFFFEDD5),
                      iconColor: const Color(0xFFEA580C),
                      icon: Icons.memory_rounded,
                      description:
                          'Zero server latency! The app converts RGB to CIELAB color space, applies illuminant white balance compensation, and evaluates natural cubic spline curves to calculate fractional pH (0.00 – 14.00).',
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Best Practices for High Accuracy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildTipsCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LiveCameraScreen()),
                  );
                },
                icon: const Icon(Icons.camera_alt_outlined, size: 22),
                label: const Text(
                  'Start pH Analysis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.science_outlined,
              color: Color(0xFF2563EB),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Digital Colorimetric Guide',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Learn how to capture, calibrate, and measure estimated pH levels using edge computing.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required Color badgeColor,
    required Color iconColor,
    required IconData icon,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stepNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        children: [
          _buildTipRow(
            isDo: true,
            text:
                'Read dye paper within 30 to 60 seconds after dipping in solution.',
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildTipRow(
            isDo: true,
            text:
                'Place reference paper on a flat, non-reflective surface under steady light.',
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildTipRow(
            isDo: false,
            text:
                'Avoid capturing images under direct colored lighting or severe shadows.',
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildTipRow(
            isDo: false,
            text:
                'Do not allow dye chemical bleeding to touch the white reference box.',
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow({required bool isDo, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDo ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDo ? Icons.check : Icons.close,
            size: 14,
            color: isDo ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334155),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
