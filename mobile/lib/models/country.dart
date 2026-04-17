class Country {
  final String code;
  final String name;
  final String? flagEmoji;
  final String? dialCode;
  final String? phoneExample;
  final int? phoneMinDigits;
  final int? phoneMaxDigits;
  final bool supportsMobileMoney;
  final bool isPopular;
  final String currencyCode;
  final String currencySymbol;

  const Country({
    required this.code,
    required this.name,
    this.flagEmoji,
    this.dialCode,
    this.phoneExample,
    this.phoneMinDigits,
    this.phoneMaxDigits,
    this.supportsMobileMoney = false,
    this.isPopular = false,
    this.currencyCode = 'XAF',
    this.currencySymbol = 'FCFA',
  });

  factory Country.fromJson(Map<String, dynamic> json) => Country(
        code: json['code'] as String,
        name: json['name'] as String,
        flagEmoji: json['flag_emoji'] as String?,
        dialCode: json['dial_code'] as String?,
        phoneExample: json['phone_example'] as String?,
        phoneMinDigits: json['phone_min_digits'] as int?,
        phoneMaxDigits: json['phone_max_digits'] as int?,
        supportsMobileMoney: json['supports_mobile_money'] as bool? ?? false,
        isPopular: json['is_popular'] as bool? ?? false,
        currencyCode: json['currency_code'] as String? ?? 'XAF',
        currencySymbol: json['currency_symbol'] as String? ?? 'FCFA',
      );

  String get displayLabel =>
      flagEmoji != null ? '$flagEmoji  $name' : name;

  String get shortLabel =>
      flagEmoji != null ? '$flagEmoji ${dialCode ?? ''}' : (dialCode ?? name);
}
