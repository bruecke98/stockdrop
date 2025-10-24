/// Model for user settings in StockDrop app
class UserSettings {
  final int notificationThreshold;
  final String theme;
  final DateTime? updatedAt;

  UserSettings({
    required this.notificationThreshold,
    required this.theme,
    this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      notificationThreshold: json['notification_threshold'] ?? 5,
      theme: json['theme'] ?? 'system',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notification_threshold': notificationThreshold,
      'theme': theme,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'UserSettings(threshold: $notificationThreshold, theme: $theme)';
  }

  /// Create a copy of UserSettings with updated values
  UserSettings copyWith({
    int? notificationThreshold,
    String? theme,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      notificationThreshold:
          notificationThreshold ?? this.notificationThreshold,
      theme: theme ?? this.theme,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSettings &&
        other.notificationThreshold == notificationThreshold &&
        other.theme == theme;
  }

  @override
  int get hashCode {
    return notificationThreshold.hashCode ^ theme.hashCode;
  }
}
