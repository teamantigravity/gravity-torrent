class RssRule {
  final String name;
  final bool enabled;
  final int priority;
  final String mustContain;
  final String mustNotContain;
  final bool useRegex;
  final List<String> feedUrls;
  final DateTime? lastMatch;

  RssRule({
    required this.name,
    this.enabled = true,
    this.priority = 0,
    this.mustContain = '',
    this.mustNotContain = '',
    this.useRegex = false,
    required this.feedUrls,
    this.lastMatch,
  });

  factory RssRule.fromJson(Map<String, dynamic> json) {
    return RssRule(
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
      mustContain: json['mustContain'] as String? ?? '',
      mustNotContain: json['mustNotContain'] as String? ?? '',
      useRegex: json['useRegex'] as bool? ?? false,
      feedUrls: (json['feedUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      lastMatch: json['lastMatch'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['lastMatch'] as num).toInt() * 1000,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'enabled': enabled,
      'priority': priority,
      'mustContain': mustContain,
      'mustNotContain': mustNotContain,
      'useRegex': useRegex,
      'feedUrls': feedUrls,
      'lastMatch': lastMatch?.millisecondsSinceEpoch != null
          ? (lastMatch!.millisecondsSinceEpoch ~/ 1000)
          : null,
    };
  }

  RssRule copyWith({
    String? name,
    bool? enabled,
    int? priority,
    String? mustContain,
    String? mustNotContain,
    bool? useRegex,
    List<String>? feedUrls,
    DateTime? lastMatch,
  }) {
    return RssRule(
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      mustContain: mustContain ?? this.mustContain,
      mustNotContain: mustNotContain ?? this.mustNotContain,
      useRegex: useRegex ?? this.useRegex,
      feedUrls: feedUrls ?? this.feedUrls,
      lastMatch: lastMatch ?? this.lastMatch,
    );
  }
}
