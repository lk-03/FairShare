import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/reminder_settings.dart';
import '../../../../data/providers/needs_provider.dart';

class NeedsReminderSettingsSheet extends ConsumerStatefulWidget {
  final String cohortId;

  const NeedsReminderSettingsSheet({
    super.key,
    required this.cohortId,
  });

  static Future<void> show(BuildContext context, String cohortId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NeedsReminderSettingsSheet(cohortId: cohortId),
    );
  }

  @override
  ConsumerState<NeedsReminderSettingsSheet> createState() =>
      _NeedsReminderSettingsSheetState();
}

class _NeedsReminderSettingsSheetState
    extends ConsumerState<NeedsReminderSettingsSheet> {
  late bool _enabled;
  late String _unit; // 'hours' | 'days'
  late int _freqHours;
  late int _freqDays;
  late String _reminderTime;
  late bool _notifyStale;

  final List<int> _hourOptions = const [2, 4, 6, 8, 12, 24];
  final List<int> _dayOptions = const [1, 2, 3, 5, 7];
  final List<({String label, String value})> _timeOptions = const [
    (label: 'Morning (9 AM)', value: '09:00'),
    (label: 'Noon (1 PM)', value: '13:00'),
    (label: 'Evening (6 PM)', value: '18:00'),
    (label: 'Night (9 PM)', value: '21:00'),
  ];

  @override
  void initState() {
    super.initState();
    final repo = ref.read(needsRepositoryProvider);
    final settings = repo.getReminderSettings(widget.cohortId);

    _enabled = settings.isEnabled;
    _unit = settings.frequencyUnit;
    _freqHours = settings.frequencyHours;
    _freqDays = settings.frequencyDays;
    _reminderTime = settings.reminderTime;
    _notifyStale = settings.notifyStaleItems;
  }

  Future<void> _handleSave() async {
    final updated = PersonalReminderSettings(
      cohortId: widget.cohortId,
      isEnabled: _enabled,
      frequencyUnit: _unit,
      frequencyHours: _freqHours,
      frequencyDays: _freqDays,
      reminderTime: _reminderTime,
      notifyStaleItems: _notifyStale,
    );

    final repo = ref.read(needsRepositoryProvider);
    await repo.saveReminderSettings(updated);

    if (mounted) {
      Navigator.of(context).pop();
      final msg = !_enabled
          ? 'You will not receive shopping reminders for this house cart.'
          : _unit == 'hours'
              ? 'You will be reminded every $_freqHours hour(s) before grocery runs.'
              : 'You will be reminded every $_freqDays day(s) at $_reminderTime.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: colors.border, width: 1),
      ),
      margin: const EdgeInsets.only(top: 8),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: mediaQuery.viewInsets.bottom +
            mediaQuery.padding.bottom +
            20,
      ),
      constraints: BoxConstraints(
        maxHeight: availableHeight * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notification & Reminder Settings',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: colors.textMain,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Configure personal reminders so you check the house cart before Blinkiting, Instamarting, or grocery shopping.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable Settings List
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Master Switch
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accentPill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable Reminders',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _enabled
                                    ? 'Active notification schedule'
                                    : 'Muted for this cohort',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enabled,
                          onChanged: (val) => setState(() => _enabled = val),
                          activeThumbColor: colors.cyan,
                        ),
                      ],
                    ),
                  ),

                  if (_enabled) ...[
                    const SizedBox(height: 18),

                    // Frequency Unit Selector
                    Text(
                      'FREQUENCY TYPE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFrequencyTypeButton(
                            label: 'Every X Hours',
                            isSelected: _unit == 'hours',
                            onTap: () => setState(() => _unit = 'hours'),
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFrequencyTypeButton(
                            label: 'Every X Days',
                            isSelected: _unit == 'days',
                            onTap: () => setState(() => _unit = 'days'),
                            colors: colors,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Hours Selector
                    if (_unit == 'hours') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'REPEAT EVERY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            'Default: 6 Hours',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.cyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _hourOptions.map((h) {
                          final isSelected = _freqHours == h;
                          return InkWell(
                            onTap: () => setState(() => _freqHours = h),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 52,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.cyan
                                    : colors.accentPill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? colors.cyan : colors.border,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${h}h',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : colors.textMain,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // Days Selector & Time of Day
                    if (_unit == 'days') ...[
                      Text(
                        'INTERVAL IN DAYS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _dayOptions.map((d) {
                          final isSelected = _freqDays == d;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () => setState(() => _freqDays = d),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.cyan
                                        : colors.accentPill,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.cyan
                                          : colors.border,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${d}d',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white
                                          : colors.textMain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Notification Time
                      Text(
                        'NOTIFICATION TIME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _timeOptions.map((t) {
                          final isSelected = _reminderTime == t.value;
                          return InkWell(
                            onTap: () => setState(() => _reminderTime = t.value),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.cyan
                                    : colors.accentPill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? colors.cyan : colors.border,
                                ),
                              ),
                              child: Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : colors.textMain,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // 3+ Days Stale Item Alert
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accentPill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '3+ Days Unbought Alert',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Alert when items sit unchecked for 3+ days',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _notifyStale,
                            onChanged: (val) =>
                                setState(() => _notifyStale = val),
                            activeThumbColor: colors.cyan,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Save Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.cyan,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            onPressed: _handleSave,
            child: const Text(
              'Save Preferences',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyTypeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppThemeColors colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.cyan : colors.accentPill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.cyan : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
