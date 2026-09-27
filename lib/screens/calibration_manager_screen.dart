import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/calibration_data.dart';
import '../models/calibration_profile.dart';
import '../services/calibration_profile_service.dart';
import 'roi_selector.dart';

class CalibrationManagerScreen extends StatefulWidget {
  const CalibrationManagerScreen({super.key});
  @override
  State<CalibrationManagerScreen> createState() =>
      _CalibrationManagerScreenState();
}

class _CalibrationManagerScreenState extends State<CalibrationManagerScreen> {
  List<CalibrationProfile> profiles = [];
  String activeId = CalibrationProfileService.bundledId;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await CalibrationProfileService.getAll();
      final selected = await CalibrationProfileService.activeId();
      if (mounted) {
        setState(() {
          profiles = list;
          activeId = selected;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> edit(
    CalibrationProfile? profile, {
    bool duplicate = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalibrationProfileEditor(
          profile: duplicate ? null : profile,
          copyFrom: duplicate ? profile : null,
        ),
      ),
    );
    if (mounted) refresh();
  }

  Future<void> remove(CalibrationProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete calibration profile?'),
        content: Text(
          'Delete ${profile.name}? Saved measurements keep their original calibration ID, version, and hash. If this is active, the bundled experimental calibration will become active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await CalibrationProfileService.delete(profile.id);
      await refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile deleted. Prior measurements were kept.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> select(String id) async {
    try {
      await CalibrationProfileService.select(id);
      if (mounted) {
        setState(() {
          activeId = id;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calibration Manager')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(null),
      icon: const Icon(Icons.add),
      label: const Text('New profile'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Use known pH reference solutions measured by a reliable pH meter or certified buffer. Capture each dye patch under the same lighting and camera settings. Calibration quality depends on the reference method, dye, strip lot, lighting, phone camera, and selected image regions. Every result remains an experimental, unvalidated estimate.',
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(error!),
                          TextButton(
                            onPressed: refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ListTile(
                  title: const Text('Bundled experimental'),
                  subtitle: const Text(
                    'Default calibration · cannot be edited',
                  ),
                  leading: Icon(
                    activeId == CalibrationProfileService.bundledId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () => select(CalibrationProfileService.bundledId),
                ),
                if (profiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No custom profiles yet. Add one with at least two known pH points.',
                    ),
                  ),
                for (final profile in profiles)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(profile.name),
                          subtitle: Text(
                            '${profile.brand} ${profile.product} · pH ${profile.lowerPh}–${profile.upperPh} · v${profile.version}',
                          ),
                          leading: Icon(
                            activeId == profile.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          onTap: () => select(profile.id),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => edit(profile),
                              child: const Text('Edit / rename'),
                            ),
                            TextButton(
                              onPressed: () => edit(profile, duplicate: true),
                              child: const Text('Duplicate'),
                            ),
                            TextButton(
                              onPressed: () => remove(profile),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
  );
}

class CalibrationProfileEditor extends StatefulWidget {
  final CalibrationProfile? profile;
  final CalibrationProfile? copyFrom;
  const CalibrationProfileEditor({super.key, this.profile, this.copyFrom});
  @override
  State<CalibrationProfileEditor> createState() =>
      _CalibrationProfileEditorState();
}

class _CalibrationProfileEditorState extends State<CalibrationProfileEditor> {
  late final TextEditingController name;
  late final TextEditingController brand;
  late final TextEditingController product;
  late final TextEditingController lot;
  late final TextEditingController notes;
  late final TextEditingController lower;
  late final TextEditingController upper;
  late List<CalibrationAnchor> points;
  String? error;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile ?? widget.copyFrom;
    name = TextEditingController(
      text: widget.copyFrom == null ? p?.name : '${p!.name} copy',
    );
    brand = TextEditingController(text: p?.brand);
    product = TextEditingController(text: p?.product);
    lot = TextEditingController(text: p?.lot);
    notes = TextEditingController(text: p?.notes);
    lower = TextEditingController(text: p?.lowerPh.toString());
    upper = TextEditingController(text: p?.upperPh.toString());
    points = [...?p?.calibration.anchors];
  }

  @override
  void dispose() {
    for (final c in [name, brand, product, lot, notes, lower, upper]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> editPoint([int? index]) async {
    final anchor = await showDialog<CalibrationAnchor>(
      context: context,
      builder: (_) =>
          CalibrationPointDialog(initial: index == null ? null : points[index]),
    );
    if (anchor == null) return;
    setState(() {
      if (index == null) {
        points.add(anchor);
      } else {
        points[index] = anchor;
      }
      points.sort((a, b) => a.ph.compareTo(b.ph));
      error = null;
    });
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final profile = CalibrationProfile(
        id: widget.profile?.id ?? CalibrationProfileService.newId(),
        version: (widget.profile?.version ?? 0) + 1,
        name: name.text.trim(),
        brand: brand.text.trim(),
        product: product.text.trim(),
        lot: lot.text.trim(),
        notes: notes.text.trim(),
        lowerPh: double.parse(lower.text.trim()),
        upperPh: double.parse(upper.text.trim()),
        anchors: points,
      );
      await CalibrationProfileService.save(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calibration profile saved.')),
        );
        Navigator.pop(context, profile.id);
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not save profile: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.profile == null
            ? 'New calibration profile'
            : 'Edit calibration profile',
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Profile name *'),
          ),
          TextField(
            controller: brand,
            decoration: const InputDecoration(labelText: 'Brand'),
          ),
          TextField(
            controller: product,
            decoration: const InputDecoration(
              labelText: 'Dye or strip product',
            ),
          ),
          TextField(
            controller: lot,
            decoration: const InputDecoration(labelText: 'Lot'),
          ),
          TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 3,
          ),
          TextField(
            controller: lower,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Lowest supported pH *',
            ),
          ),
          TextField(
            controller: upper,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Highest supported pH *',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Calibration points',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Add at least two distinct, ascending known pH points. The first and last points must match the supported range. Measure reference paper for each photo when possible; otherwise the fixed reference RGB 245, 245, 240 is used.',
          ),
          for (var i = 0; i < points.length; i++)
            Card(
              child: ListTile(
                title: Text(
                  'pH ${points[i].ph} · dye ${points[i].dyeRgb.join(", ")}',
                ),
                subtitle: Text('Reference ${points[i].bgRgb.join(", ")}'),
                onTap: () => editPoint(i),
                trailing: IconButton(
                  tooltip: 'Delete point at pH ${points[i].ph}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => points.removeAt(i)),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => editPoint(),
            icon: const Icon(Icons.add),
            label: const Text('Add point'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving…' : 'Save profile'),
          ),
          const SizedBox(height: 48),
        ],
      ),
    ),
  );
}

class CalibrationPointDialog extends StatefulWidget {
  final CalibrationAnchor? initial;
  const CalibrationPointDialog({super.key, this.initial});
  @override
  State<CalibrationPointDialog> createState() => _CalibrationPointDialogState();
}

class _CalibrationPointDialogState extends State<CalibrationPointDialog> {
  late final TextEditingController ph;
  late final List<TextEditingController> dye;
  late final List<TextEditingController> reference;
  String? error;
  bool importing = false;

  @override
  void initState() {
    super.initState();
    ph = TextEditingController(text: widget.initial?.ph.toString());
    dye = List.generate(
      3,
      (i) => TextEditingController(text: widget.initial?.dyeRgb[i].toString()),
    );
    reference = List.generate(
      3,
      (i) => TextEditingController(
        text: (widget.initial?.bgRgb[i] ?? [245, 245, 240][i]).toString(),
      ),
    );
  }

  @override
  void dispose() {
    ph.dispose();
    for (final c in [...dye, ...reference]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> importPhoto(ImageSource source) async {
    setState(() {
      importing = true;
      error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null || !mounted) return;
      final colors = await Navigator.of(context).push<(List<int>, List<int>)>(
        MaterialPageRoute(
          builder: (_) =>
              ROISelector(imagePath: picked.path, calibrationPoint: true),
        ),
      );
      if (colors != null && mounted) {
        setState(() {
          for (var i = 0; i < 3; i++) {
            dye[i].text = colors.$1[i].toString();
            reference[i].text = colors.$2[i].toString();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Photo import failed: $e');
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  void submit() {
    try {
      final anchor = CalibrationAnchor(
        ph: double.parse(ph.text.trim()),
        dyeRgb: dye.map((c) => int.parse(c.text.trim())).toList(),
        bgRgb: reference.map((c) => int.parse(c.text.trim())).toList(),
      );
      Navigator.pop(context, anchor);
    } catch (e) {
      setState(
        () =>
            error = 'Enter pH from 0 to 14 and RGB channels from 0 to 255. $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null
          ? 'Add calibration point'
          : 'Edit calibration point',
    ),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ph,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Known pH *'),
            ),
            const SizedBox(height: 12),
            const Text('Dye RGB'),
            for (var i = 0; i < 3; i++)
              TextField(
                controller: dye[i],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ['Red', 'Green', 'Blue'][i],
                ),
              ),
            const SizedBox(height: 12),
            const Text('Reference paper RGB'),
            for (var i = 0; i < 3; i++)
              TextField(
                controller: reference[i],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ['Red', 'Green', 'Blue'][i],
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: importing
                  ? null
                  : () => importPhoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(
                importing ? 'Importing…' : 'Capture dye pad and select regions',
              ),
            ),
            OutlinedButton.icon(
              onPressed: importing
                  ? null
                  : () => importPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                importing ? 'Importing…' : 'Import photo and select regions',
              ),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Use point')),
    ],
  );
}
