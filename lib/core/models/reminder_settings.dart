class PersonalReminderSettings {
  final String cohortId;
  final bool isEnabled;
  final String reminderFrequency; // 'daily', 'weekly', 'monthly'
  final String reminderTime; // e.g. "09:00"
  final double? settlementThreshold;

  const PersonalReminderSettings({
    required this.cohortId,
    this.isEnabled = false,
    this.reminderFrequency = 'weekly',
    this.reminderTime = '09:00',
    this.settlementThreshold,
  });

  factory PersonalReminderSettings.fromJson(Map<String, dynamic> json) {
    return PersonalReminderSettings(
      cohortId: json['cohort_id'] as String? ?? json['cohortId'] as String? ?? '',
      isEnabled: json['is_enabled'] as bool? ?? json['isEnabled'] as bool? ?? false,
      reminderFrequency: json['reminder_frequency'] as String? ??
          json['reminderFrequency'] as String? ??
          'weekly',
      reminderTime: json['reminder_time'] as String? ??
          json['reminderTime'] as String? ??
          '09:00',
      settlementThreshold: (json['settlement_threshold'] as num?)?.toDouble() ??
          (json['settlementThreshold'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cohort_id': cohortId,
      'is_enabled': isEnabled,
      'reminder_frequency': reminderFrequency,
      'reminder_time': reminderTime,
      if (settlementThreshold != null) 'settlement_threshold': settlementThreshold,
    };
  }

  PersonalReminderSettings copyWith({
    String? cohortId,
    bool? isEnabled,
    String? reminderFrequency,
    String? reminderTime,
    double? settlementThreshold,
  }) {
    return PersonalReminderSettings(
      cohortId: cohortId ?? this.cohortId,
      isEnabled: isEnabled ?? this.isEnabled,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
      reminderTime: reminderTime ?? this.reminderTime,
      settlementThreshold: settlementThreshold ?? this.settlementThreshold,
    );
  }
}
