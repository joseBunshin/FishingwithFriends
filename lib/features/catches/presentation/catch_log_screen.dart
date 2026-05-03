import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/application/location_service.dart';
import 'package:fishing_with_friends/features/catches/application/save_catch_controller.dart';
import 'package:fishing_with_friends/features/catches/domain/catch_input.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/additional_details_section.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/photo_drop_target.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/unit_toggle_field.dart';
import 'package:fishing_with_friends/features/storytelling/data/storytelling_repository_provider.dart';
import 'package:fishing_with_friends/features/trips/data/trips_repository_provider.dart';
import 'package:fishing_with_friends/features/trips/presentation/active_trip_banner.dart';
import 'package:fishing_with_friends/features/trips/presentation/start_trip_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// "Hero" catch logging screen — media-first per spec.
class CatchLogScreen extends ConsumerStatefulWidget {
  const CatchLogScreen({super.key});

  @override
  ConsumerState<CatchLogScreen> createState() => _CatchLogScreenState();
}

class _CatchLogScreenState extends ConsumerState<CatchLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtl = TextEditingController();
  final _rigCtl = TextEditingController();
  final _locationCtl = TextEditingController();

  final List<XFile> _photos = [];
  String? _species;
  double? _weightKg;
  double? _lengthCm;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _catchAndRelease = false;
  bool _secretSpot = false;
  double? _latitude;
  double? _longitude;
  bool _resolvingLocation = false;

  @override
  void dispose() {
    _notesCtl.dispose();
    _rigCtl.dispose();
    _locationCtl.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();

    // Chrome desktop ignores the file-input `capture` attribute, so the
    // camera option falls through to the standard file picker anyway.
    // Skip the source sheet on web and go straight to gallery — the user
    // experience is identical and they don't get the misleading "Take a
    // photo" tile.
    final ImageSource? source;
    if (kIsWeb) {
      source = ImageSource.gallery;
    } else {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (_) => const _SourcePicker(),
      );
      if (source == null) return;
    }

    final file = await picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (file != null && mounted) {
      await HapticFeedback.lightImpact();
      setState(() => _photos.add(file));
    }
  }

  void _removePhoto(int i) {
    setState(() => _photos.removeAt(i));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _useMyLocation() async {
    setState(() => _resolvingLocation = true);
    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    setState(() {
      _resolvingLocation = false;
      if (result != null) {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _locationCtl.text =
            '${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}';
      }
    });
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location not available — fill in manually or check permissions.',
          ),
        ),
      );
    }
  }

  DateTime get _caughtAt => DateTime(
    _date.year,
    _date.month,
    _date.day,
    _time.hour,
    _time.minute,
  ).toUtc();

  CatchInput _buildInput() {
    return CatchInput(
      photos: List<XFile>.unmodifiable(_photos),
      caughtAt: _caughtAt,
      secretSpot: _secretSpot,
      catchAndRelease: _catchAndRelease,
      speciesLabel: _species,
      weightKg: _weightKg,
      lengthCm: _lengthCm,
      latitude: _latitude,
      longitude: _longitude,
      locationLabel: _locationCtl.text.trim().isEmpty
          ? null
          : _locationCtl.text.trim(),
      notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      rig: _rigCtl.text.trim().isEmpty ? null : _rigCtl.text.trim(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo of your catch first.')),
      );
      return;
    }

    final controller = ref.read(saveCatchControllerProvider.notifier);
    if (ref.read(saveCatchControllerProvider).isLoading) {
      return; // double-tap guard
    }

    final saved = await controller.submit(_buildInput());
    if (!mounted) return;

    if (saved != null) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;

      // Best-effort: read the trigger's storytelling output and route to
      // the celebration screen when something celebratory landed. Any
      // error here degrades to the catch detail.
      try {
        final outcome = await ref.read(saveOutcomeProvider(saved.id).future);
        if (!mounted) return;
        if (outcome.isCelebratory) {
          // pushReplacement (not go) so the underlying shell route is
          // preserved as the pop target — without this, /celebrate sits
          // on an empty stack and the back affordance traps the user.
          context.pushReplacement('/celebrate/${saved.id}');
          return;
        }
      } on Object {
        // Any failure here degrades to the catch detail — celebration is
        // best-effort, never blocks the success path.
      }
      // Same reasoning as the celebrate branch above.
      context.pushReplacement('/catches/${saved.id}');
      return;
    }

    final error = ref.read(saveCatchControllerProvider).error;
    if (error is AuthFailure) {
      // Auth went stale mid-submit; route the user back to sign-in.
      context.go(AppRoutes.signIn);
      return;
    }
    final message = error is AppException ? error.message : 'Save failed.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Retry', onPressed: _save),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(saveCatchControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log a Catch'),
        leading: IconButton(
          // iOS-style back chevron — visually reads as "back" to users.
          // Previously was Icons.close (X) which the user kept reporting
          // as "back arrow doesn't work" — it worked, but the icon
          // didn't match their mental model of "go back."
          icon: const Icon(Icons.arrow_back_ios_new),
          // canPop + Home fallback covers the cold-launch / deep-link
          // edge case where the route stack is empty.
          onPressed: saving
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.home);
                  }
                },
        ),
      ),
      body: AbsorbPointer(
        absorbing: saving,
        child: Stack(
          children: [
            // Tap-outside-to-dismiss for the keyboard. iOS numeric
            // keyboards (weight, length) have no Done key and multi-line
            // notes treats Return as newline, so the user had no way to
            // close the keyboard once it opened. Translucent hit-test so
            // taps still pass through to fields, buttons, etc.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _TripAffordance(),
                    const SizedBox(height: AppSpacing.md),
                    PhotoDropTarget(
                      photos: _photos,
                      onAdd: _addPhoto,
                      onRemove: _removePhoto,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionLabel('Species *'),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<String>(
                      initialValue: _species,
                      decoration: const InputDecoration(
                        hintText: 'Select species',
                        prefixIcon: Icon(Icons.set_meal_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Largemouth Bass',
                          child: Text('Largemouth Bass'),
                        ),
                        DropdownMenuItem(
                          value: 'Rainbow Trout',
                          child: Text('Rainbow Trout'),
                        ),
                        DropdownMenuItem(
                          value: 'Walleye',
                          child: Text('Walleye'),
                        ),
                        DropdownMenuItem(value: 'Snook', child: Text('Snook')),
                        DropdownMenuItem(
                          value: 'Redfish',
                          child: Text('Redfish'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _species = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: WeightToggleField(
                            label: 'Weight *',
                            onMetricChanged: (kg) => _weightKg = kg,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: LengthToggleField(
                            label: 'Length *',
                            onMetricChanged: (cm) => _lengthCm = cm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _DateTimeField(
                            label: 'Date',
                            icon: Icons.calendar_today_outlined,
                            text: DateFormat.yMd().format(_date),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _DateTimeField(
                            label: 'Time',
                            icon: Icons.access_time,
                            text: _time.format(context),
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel('Location'),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _locationCtl,
                            decoration: const InputDecoration(
                              hintText: 'Lake, river, or city',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton.filledTonal(
                          onPressed: _resolvingLocation ? null : _useMyLocation,
                          icon: _resolvingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                          tooltip: 'Use my location',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AdditionalDetailsSection(
                      notesController: _notesCtl,
                      rigController: _rigCtl,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _catchAndRelease,
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              setState(() => _catchAndRelease = v);
                            },
                            secondary: const Icon(Icons.water_drop_outlined),
                            title: const Text('Catch & Release'),
                            subtitle: const Text('I released this fish back.'),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: _secretSpot,
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              setState(() => _secretSpot = v);
                            },
                            secondary: const Icon(Icons.lock_outline),
                            title: const Text('Secret Spot'),
                            subtitle: const Text(
                              'Hide GPS location from friends.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: saving ? null : _save,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        saving ? 'Saving…' : 'Save Catch',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            if (saving)
              const Positioned.fill(
                child: ColoredBox(color: Color(0x1F0E1116)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InputDecorator(
            decoration: InputDecoration(prefixIcon: Icon(icon)),
            child: Text(text),
          ),
        ),
      ],
    );
  }
}

class _TripAffordance extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTrip = ref.watch(activeTripProvider).valueOrNull;
    if (activeTrip != null) return const ActiveTripBanner();
    return OutlinedButton.icon(
      onPressed: () => StartTripSheet.show(context),
      icon: const Icon(Icons.directions_boat_outlined, size: 18),
      label: const Text('Start a trip'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
    );
  }
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pick from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}
