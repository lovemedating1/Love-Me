/// Flag emoji lookup by country name, for Explore's country grid.
///
/// This is purely decorative (an emoji next to a name) and intentionally
/// separate from `profiles.country`'s free-text value — it does not gate or
/// validate anything. Unknown country names fall back to a globe emoji
/// rather than guessing.
class CountryFlags {
  CountryFlags._();

  static const Map<String, String> _flags = {
    'Kenya': '🇰🇪',
    'Nigeria': '🇳🇬',
    'Ghana': '🇬🇭',
    'South Africa': '🇿🇦',
    'Egypt': '🇪🇬',
    'India': '🇮🇳',
    'United States': '🇺🇸',
    'United Kingdom': '🇬🇧',
    'Canada': '🇨🇦',
    'Australia': '🇦🇺',
    'Germany': '🇩🇪',
    'France': '🇫🇷',
    'Brazil': '🇧🇷',
    'Mexico': '🇲🇽',
    'Philippines': '🇵🇭',
    'Pakistan': '🇵🇰',
    'Bangladesh': '🇧🇩',
    'Indonesia': '🇮🇩',
    'United Arab Emirates': '🇦🇪',
    'Saudi Arabia': '🇸🇦',
    'Tanzania': '🇹🇿',
    'Uganda': '🇺🇬',
    'Zimbabwe': '🇿🇼',
    'Ethiopia': '🇪🇹',
    'Cameroon': '🇨🇲',
  };

  static String forCountry(String name) => _flags[name] ?? '🌍';
}
