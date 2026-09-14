class PersonalReminderSettings {
  final String cohortId;
  final bool isEnabled;
  final String reminderFrequency; // 'daily', 'weekly', 'monthly'
  final String frequencyUnit; // 'hours' | 'days'
  final int frequencyHours; // 2, 4, 6, 8, 12, 24
  final int frequencyDays; // 1, 2, 3, 5, 7
  final String reminderTime; // e.g. "18:00"
  final bool notifyStaleItems;
  final double? settlementThreshold;

  const PersonalReminderSettings({
    required this.cohortId,
    this.isEnabled = true,
    this.reminderFrequency = 'weekly',
    this.frequencyUnit = 'hours',
    this.frequencyHours = 6,
    this.frequencyDays = 1,
    this.reminderTime = '18:00',
    this.notifyStaleItems = true,
    this.settlementThreshold,
  });

  factory PersonalReminderSettings.fromJson(Map<String, dynamic> json) {
    return PersonalReminderSettings(
      cohortId: json['cohort_id'] as String? ?? json['cohortId'] as String? ?? '',
      isEnabled: json['is_enabled'] as bool? ??
          json['isEnabled'] as bool? ??
          json['enabled'] as bool? ??
          true,
      reminderFrequency: json['reminder_frequency'] as String? ??
          json['reminderFrequency'] as String? ??
          'weekly',
      frequencyUnit: json['frequency_unit'] as String? ??
          json['frequencyUnit'] as String? ??
          'hours',
      frequencyHours: (json['frequency_hours'] as num?)?.toInt() ??
          (json['frequencyHours'] as num?)?.toInt() ??
          6,
      frequencyDays: (json['frequency_days'] as num?)?.toInt() ??
          (json['frequencyDays'] as num?)?.toInt() ??
          1,
      reminderTime: json['reminder_time'] as String? ??
          json['reminderTime'] as String? ??
          '18:00',
      notifyStaleItems: json['notify_stale_items'] as bool? ??
          json['notifyStaleItems'] as bool? ??
          true,
      settlementThreshold: (json['settlement_threshold'] as num?)?.toDouble() ??
          (json['settlementThreshold'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cohort_id': cohortId,
      'is_enabled': isEnabled,
      'reminder_frequency': reminderFrequency,
      'frequency_unit': frequencyUnit,
      'frequency_hours': frequencyHours,
      'frequency_days': frequencyDays,
      'reminder_time': reminderTime,
      'notify_stale_items': notifyStaleItems,
      if (settlementThreshold != null) 'settlement_threshold': settlementThreshold,
    };
  }

  PersonalReminderSettings copyWith({
    String? cohortId,
    bool? isEnabled,
    String? reminderFrequency,
    String? frequencyUnit,
    int? frequencyHours,
    int? frequencyDays,
    String? reminderTime,
    bool? notifyStaleItems,
    double? settlementThreshold,
  }) {
    return PersonalReminderSettings(
      cohortId: cohortId ?? this.cohortId,
      isEnabled: isEnabled ?? this.isEnabled,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
      frequencyUnit: frequencyUnit ?? this.frequencyUnit,
      frequencyHours: frequencyHours ?? this.frequencyHours,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      reminderTime: reminderTime ?? this.reminderTime,
      notifyStaleItems: notifyStaleItems ?? this.notifyStaleItems,
      settlementThreshold: settlementThreshold ?? this.settlementThreshold,
    );
  }
}
