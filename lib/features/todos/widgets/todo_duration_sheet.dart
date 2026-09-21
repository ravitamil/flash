import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/utils/responsive.dart';
import 'package:streak/features/todos/widgets/todo_labels.dart';

Future<int?> showCustomDurationSheet(
  BuildContext context, {
  int? initialMinutes,
}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: phoneWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _CustomDurationSheet(
        initialMinutes: initialMinutes,
      ),
    );

class _CustomDurationSheet extends StatefulWidget {
  const _CustomDurationSheet({this.initialMinutes});

  final int? initialMinutes;

  @override
  State<_CustomDurationSheet> createState() => _CustomDurationSheetState();
}

class _CustomDurationSheetState extends State<_CustomDurationSheet> {
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    final init = widget.initialMinutes ?? 30;
    _hours = (init ~/ 60).clamp(0, 24);
    _minutes = (init % 60).clamp(0, 59);
  }

  int get _totalMinutes => _hours * 60 + _minutes;

  void _addMinutes(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final total = (_totalMinutes + delta).clamp(0, 24 * 60);
      _hours = total ~/ 60;
      _minutes = total % 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.hourglass,
                  size: 19,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Duration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Set hours and minutes for this task',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.clock, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  _totalMinutes == 0
                      ? 'No duration set'
                      : formatTodoDuration(_totalMinutes),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),
                if (_totalMinutes > 0 &&
                    _totalMinutes >= 60 &&
                    _totalMinutes % 60 != 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '($_totalMinutes min)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StepperCard(
                  label: 'Hours',
                  value: _hours,
                  unit: 'h',
                  onMinus: _hours > 0 ? () => _addMinutes(-60) : null,
                  onPlus: _hours < 24 ? () => _addMinutes(60) : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StepperCard(
                  label: 'Minutes',
                  value: _minutes,
                  unit: 'm',
                  onMinus: _totalMinutes > 0
                      ? () =>
                          _addMinutes(-(_minutes % 5 == 0 ? 5 : _minutes % 5))
                      : null,
                  onPlus: _totalMinutes < 24 * 60
                      ? () => _addMinutes(5 - (_minutes % 5))
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _QuickChip(label: '+15m', onTap: () => _addMinutes(15)),
              _QuickChip(label: '+30m', onTap: () => _addMinutes(30)),
              _QuickChip(label: '+1h', onTap: () => _addMinutes(60)),
              _QuickChip(label: '+2h', onTap: () => _addMinutes(120)),
              _QuickChip(
                label: 'Clear',
                color: context.tokens.danger,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _hours = 0;
                    _minutes = 0;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(context.l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context)
                        .pop(_totalMinutes > 0 ? _totalMinutes : null);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Set Duration'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperCard extends StatelessWidget {
  const _StepperCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final String unit;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepBtn(icon: LucideIcons.minus, onTap: onMinus),
              Text(
                '$value $unit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              _StepBtn(icon: LucideIcons.plus, onTap: onPlus),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Material(
      color:
          onTap != null ? scheme.surfaceContainerHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: onTap != null
                ? scheme.onSurface
                : context.tokens.muted.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final c = color ?? scheme.primary;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      backgroundColor: c.withValues(alpha: 0.1),
      side: BorderSide(color: c.withValues(alpha: 0.25)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: onTap,
    );
  }
}
