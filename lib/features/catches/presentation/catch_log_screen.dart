import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// "Hero" catch logging screen — media-first per spec section 4A.
/// Visuals only at this stage; persistence wires up in the next milestone.
class CatchLogScreen extends ConsumerStatefulWidget {
  const CatchLogScreen({super.key});

  @override
  ConsumerState<CatchLogScreen> createState() => _CatchLogScreenState();
}

class _CatchLogScreenState extends ConsumerState<CatchLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _speciesCtl = TextEditingController();
  final _lengthCtl = TextEditingController();
  final _weightCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  XFile? _photo;
  bool _secretSpot = false;

  @override
  void dispose() {
    _speciesCtl.dispose();
    _lengthCtl.dispose();
    _weightCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (file != null) {
      await HapticFeedback.lightImpact();
      setState(() => _photo = file);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo of your catch first')),
      );
      return;
    }
    await HapticFeedback.heavyImpact();
    // TODO(catches): upload to Supabase Storage, insert catches row.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Catch logged (persistence wiring pending)')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log a catch'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _PhotoHero(
              photo: _photo,
              onTakePhoto: () => _pickPhoto(ImageSource.camera),
              onPickPhoto: () => _pickPhoto(ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _speciesCtl,
              decoration: const InputDecoration(
                labelText: 'Species',
                prefixIcon: Icon(Icons.set_meal_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lengthCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Length (in)',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _weightCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Weight (lb)',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _notesCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: SwitchListTile(
                value: _secretSpot,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _secretSpot = v);
                },
                title: const Text('Secret spot'),
                subtitle: const Text('Hide GPS location from friends'),
                secondary: const Icon(Icons.location_off_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save catch'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoHero extends StatelessWidget {
  const _PhotoHero({
    required this.photo,
    required this.onTakePhoto,
    required this.onPickPhoto,
  });

  final XFile? photo;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: photo == null ? AppColors.mist : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              Image.network(
                photo!.path,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Colors.black12),
              )
            else
              const Center(
                child: Icon(Icons.add_a_photo,
                    color: Colors.white, size: 64),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onTakePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton.tonalIcon(
                      onPressed: onPickPhoto,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
