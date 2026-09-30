/// The catalogues a master serves (`business.md`, catalogues and vocabularies; plan §7.5): product
/// data, snapshotted with each release. The engine answers `catalog.get` and the bootstrap from
/// here, and the app reads the same snapshot before any master exists (the setup form picks the
/// company's country and currency from it).
///
/// Rows have the shape the app's models already read from the cloud (B-20), so both sources share
/// the parsing. `flag` is always null: flags are cloud files, and a country without one is shown
/// by its name.
abstract final class Catalogs {
  /// The release that built this snapshot (B-21). Shown by the diagnostics screen.
  static const version = "2026.09.30";

  static const countries = "countries";
  static const currencies = "currencies";

  /// The names `catalog.get` answers. The other catalogues of `business.md` arrive with the
  /// domain that reads them (money, sales, stock, deliveries).
  static const Set<String> names = {countries, currencies};

  /// [name]'s rows, or null when this release has no such catalogue.
  static List<Map<String, Object?>>? named(String name) => switch (name) {
    countries => countryRows,
    currencies => currencyRows,
    _ => null,
  };

  /// Countries where Lyra is offered, by name. `timezone` is the zone a company in that country
  /// starts with when it sets none (B-9); where a country spans several, the most populated one.
  static const List<Map<String, Object?>> countryRows = [
    {"code": "AR", "name": "Argentina", "phone": "54", "currency": "ARS", "timezone": "America/Argentina/Buenos_Aires", "flag": null},
    {"code": "CA", "name": "Canada", "phone": "1", "currency": "CAD", "timezone": "America/Toronto", "flag": null},
    {"code": "CL", "name": "Chile", "phone": "56", "currency": "CLP", "timezone": "America/Santiago", "flag": null},
    {"code": "CO", "name": "Colombia", "phone": "57", "currency": "COP", "timezone": "America/Bogota", "flag": null},
    {"code": "SV", "name": "El Salvador", "phone": "503", "currency": "USD", "timezone": "America/El_Salvador", "flag": null},
    {"code": "MX", "name": "México", "phone": "52", "currency": "MXN", "timezone": "America/Mexico_City", "flag": null},
    {"code": "PA", "name": "Panamá", "phone": "507", "currency": "USD", "timezone": "America/Panama", "flag": null},
    {"code": "US", "name": "United States", "phone": "1", "currency": "USD", "timezone": "America/New_York", "flag": null},
    {"code": "VE", "name": "Venezuela", "phone": "58", "currency": "VES", "timezone": "America/Caracas", "flag": null},
  ];

  /// Currencies a price can be written in: fiat first, then crypto. `decimals` is how many a
  /// price is shown and rounded with (minor units, README money).
  static const List<Map<String, Object?>> currencyRows = [
    {"code": "ARS", "name": "Peso argentino", "symbol": r"$", "position": "left", "locale": "es-AR", "space": 1, "decimals": 2, "type": "fiat"},
    {"code": "CAD", "name": "Canadian Dollar", "symbol": r"$", "position": "left", "locale": "en-CA", "space": 0, "decimals": 2, "type": "fiat"},
    {"code": "CLP", "name": "Peso chileno", "symbol": r"$", "position": "left", "locale": "es-CL", "space": 0, "decimals": 0, "type": "fiat"},
    {"code": "COP", "name": "Peso colombiano", "symbol": r"$", "position": "left", "locale": "es-CO", "space": 0, "decimals": 0, "type": "fiat"},
    {"code": "EUR", "name": "Euro", "symbol": "€", "position": "right", "locale": "de-DE", "space": 1, "decimals": 2, "type": "fiat"},
    {"code": "MXN", "name": "Peso mexicano", "symbol": r"$", "position": "left", "locale": "es-MX", "space": 0, "decimals": 2, "type": "fiat"},
    {"code": "USD", "name": "US Dollar", "symbol": r"$", "position": "left", "locale": "en-US", "space": 0, "decimals": 2, "type": "fiat"},
    {"code": "VES", "name": "Bolívar", "symbol": "Bs.", "position": "left", "locale": "es-VE", "space": 1, "decimals": 2, "type": "fiat"},
    {"code": "BTC", "name": "Bitcoin", "symbol": "₿", "position": "left", "locale": "en-US", "space": 0, "decimals": 8, "type": "crypto"},
    {"code": "USDT", "name": "Tether", "symbol": "₮", "position": "left", "locale": "en-US", "space": 0, "decimals": 2, "type": "crypto"},
  ];

  /// The languages a company can operate in (the app's `BusinessLanguage`).
  static const Set<String> languages = {"es", "en", "pt", "fr", "it", "de"};

  /// The sectors a company can declare (the app's `BusinessActivity`, upper case as stored).
  static const Set<String> activities = {
    "RETAIL", "WHOLESALE", "FOOD", "HOSPITALITY", "SERVICES", "TECHNOLOGY", "HEALTH", "BEAUTY",
    "EDUCATION", "MANUFACTURING", "CONSTRUCTION", "AGRICULTURE", "TRANSPORT", "AUTOMOTIVE",
    "ENTERTAINMENT", "FINANCE", "REAL_ESTATE", "LEGAL", "NONPROFIT", "OTHER",
  };

  /// The row of country [code], or null.
  static Map<String, Object?>? country(String code) {
    for (final row in countryRows) {
      if (row["code"] == code) return row;
    }

    return null;
  }

  static bool hasCurrency(String code) => currencyRows.any((row) => row["code"] == code);
}
