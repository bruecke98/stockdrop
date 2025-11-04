/// Model representing ESG (Environmental, Social, Governance) scores
class EsgScore {
  final double environment;
  final double social;
  final double governance;
  final double total;
  final String rating;
  final String ratingColor;

  const EsgScore({
    required this.environment,
    required this.social,
    required this.governance,
    required this.total,
    required this.rating,
    required this.ratingColor,
  });

  /// Create EsgScore from JSON data
  factory EsgScore.fromJson(Map<String, dynamic> json) {
    return EsgScore(
      environment: (json['environment'] ?? 0).toDouble(),
      social: (json['social'] ?? 0).toDouble(),
      governance: (json['governance'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      rating: json['rating'] ?? 'N/A',
      ratingColor: json['ratingColor'] ?? '#999999',
    );
  }

  /// Convert EsgScore to JSON
  Map<String, dynamic> toJson() {
    return {
      'environment': environment,
      'social': social,
      'governance': governance,
      'total': total,
      'rating': rating,
      'ratingColor': ratingColor,
    };
  }

  @override
  String toString() {
    return 'EsgScore(total: $total, rating: $rating)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EsgScore &&
        other.environment == environment &&
        other.social == social &&
        other.governance == governance &&
        other.total == total &&
        other.rating == rating &&
        other.ratingColor == ratingColor;
  }

  @override
  int get hashCode {
    return Object.hash(
      environment,
      social,
      governance,
      total,
      rating,
      ratingColor,
    );
  }
}
