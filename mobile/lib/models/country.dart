class Country {
  final String code;
  final String name;
  final String? flagEmoji;
  final bool isPopular;

  const Country({
    required this.code,
    required this.name,
    this.flagEmoji,
    this.isPopular = false,
  });

  factory Country.fromJson(Map<String, dynamic> json) => Country(
        code: json['code'] as String,
        name: json['name'] as String,
        flagEmoji: json['flag_emoji'] as String?,
        isPopular: json['is_popular'] as bool? ?? false,
      );

  String get displayLabel =>
      flagEmoji != null ? '$flagEmoji  $name' : name;
}
