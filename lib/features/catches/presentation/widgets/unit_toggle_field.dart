import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/units/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pair label + numeric input + small inline unit toggle (lbs/kg or in/cm).
/// Persistence stays canonical metric — this widget exposes both the entered
/// imperial display value and the converted metric value via [onMetricChanged].
class WeightToggleField extends StatefulWidget {
  const WeightToggleField({
    required this.label,
    required this.onMetricChanged,
    this.initialUnit = WeightUnit.lb,
    super.key,
  });

  final String label;
  final ValueChanged<double?> onMetricChanged;
  final WeightUnit initialUnit;

  @override
  State<WeightToggleField> createState() => _WeightToggleFieldState();
}

class _WeightToggleFieldState extends State<WeightToggleField> {
  late WeightUnit _unit = widget.initialUnit;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit() {
    final raw = double.tryParse(_controller.text);
    if (raw == null) {
      widget.onMetricChanged(null);
      return;
    }
    widget.onMetricChanged(_unit == WeightUnit.kg ? raw : Units.lbToKg(raw));
  }

  void _flip(WeightUnit next) {
    if (next == _unit) return;
    final raw = double.tryParse(_controller.text);
    if (raw != null) {
      final converted = next == WeightUnit.lb
          ? Units.kgToLb(raw)
          : Units.lbToKg(raw);
      _controller.text = converted.toStringAsFixed(1);
    }
    setState(() => _unit = next);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return _ToggleField(
      label: widget.label,
      controller: _controller,
      onChanged: (_) => _emit(),
      trailing: _UnitToggle<WeightUnit>(
        values: const [WeightUnit.lb, WeightUnit.kg],
        labels: const ['lbs', 'kg'],
        selected: _unit,
        onChanged: _flip,
      ),
    );
  }
}

class LengthToggleField extends StatefulWidget {
  const LengthToggleField({
    required this.label,
    required this.onMetricChanged,
    this.initialUnit = LengthUnit.inch,
    super.key,
  });

  final String label;
  final ValueChanged<double?> onMetricChanged;
  final LengthUnit initialUnit;

  @override
  State<LengthToggleField> createState() => _LengthToggleFieldState();
}

class _LengthToggleFieldState extends State<LengthToggleField> {
  late LengthUnit _unit = widget.initialUnit;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit() {
    final raw = double.tryParse(_controller.text);
    if (raw == null) {
      widget.onMetricChanged(null);
      return;
    }
    widget.onMetricChanged(
      _unit == LengthUnit.cm ? raw : Units.inToCm(raw),
    );
  }

  void _flip(LengthUnit next) {
    if (next == _unit) return;
    final raw = double.tryParse(_controller.text);
    if (raw != null) {
      final converted = next == LengthUnit.inch
          ? Units.cmToIn(raw)
          : Units.inToCm(raw);
      _controller.text = converted.toStringAsFixed(1);
    }
    setState(() => _unit = next);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return _ToggleField(
      label: widget.label,
      controller: _controller,
      onChanged: (_) => _emit(),
      trailing: _UnitToggle<LengthUnit>(
        values: const [LengthUnit.inch, LengthUnit.cm],
        labels: const ['in', 'cm'],
        selected: _unit,
        onChanged: _flip,
      ),
    );
  }
}

class _ToggleField extends StatelessWidget {
  const _ToggleField({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
          ],
          onChanged: onChanged,
          decoration: const InputDecoration(hintText: '0.0'),
        ),
      ],
    );
  }
}

class _UnitToggle<T> extends StatelessWidget {
  const _UnitToggle({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < values.length; i++)
            GestureDetector(
              onTap: () => onChanged(values[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: values[i] == selected
                      ? scheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 2),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: values[i] == selected
                        ? scheme.onPrimary
                        : scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
