/// The inventory and stock domains' vocabulary (`inventory.md`, `stock.md`): field types, what
/// each one accepts, the stock operations and their reasons, and the table templates.
///
/// Codes are the ones the app already sends (`TableFieldType.value`, `StockReason.key`), so both
/// sources share them.
abstract final class FieldTypes {
  static const text = "TEXT";
  static const textarea = "TEXTAREA";
  static const title = "TITLE";
  static const description = "DESCRIPTION";
  static const sku = "SKU";
  static const barcode = "BARCODE";
  static const number = "NUMBER";
  static const decimal = "DECIMAL";
  static const price = "PRICE";
  static const currency = "CURRENCY";
  static const discount = "DISCOUNT";
  static const percentage = "PERCENTAGE";
  static const measure = "MEASURE";
  static const counter = "COUNTER";
  static const boolean = "BOOLEAN";
  static const date = "DATE";
  static const datetime = "DATETIME";
  static const email = "EMAIL";
  static const phone = "PHONE";
  static const url = "URL";
  static const options = "OPTIONS";
  static const categories = "CATEGORIES";
  static const image = "IMAGE";
  static const stock = "STOCK";

  static const Set<String> all = {
    text, textarea, title, description, sku, barcode, number, decimal, price, currency, discount,
    percentage, measure, counter, boolean, date, datetime, email, phone, url, options, categories,
    image, stock,
  };

  /// Never written by hand (I-10); a table has at most one of each.
  static const Set<String> readOnly = {counter, stock};

  /// What `match` searches (I-26).
  static const Set<String> searchable = {text, textarea, title, description, sku, barcode, options, categories};

  /// Fields with a list of options (I-15).
  static const Set<String> listed = {options, categories};

  /// Fields with a unit (a currency code or a magnitude).
  static const Set<String> withUnit = {price, currency, measure};

  /// The long texts (I-21: up to 10 000 characters instead of 1000).
  static const Set<String> long = {textarea, description};

  /// The app's spelling of [raw] (`TableFieldType.from`): `SELECT` is the old name of
  /// `OPTIONS`. Null for a code that doesn't exist.
  static String? from(Object? raw) {
    final code = raw is String ? raw.trim().toUpperCase() : null;
    if (code == "SELECT") return options;

    return all.contains(code) ? code : null;
  }
}

/// How a field is seen by the cloud's agents (`visibility`): kept for hybrid, no local effect.
abstract final class FieldVisibility {
  static const Set<String> all = {"visible", "declared", "hidden"};
}

/// The five ledger operations and the reasons each one takes (`stock.md` ST-11, ST-12). A reason
/// is checked as the pair (operation, reason): `correction` and `expiration` exist in two.
abstract final class StockOperations {
  static const add = "add";
  static const remove = "remove";
  static const reserve = "reserve";
  static const unreserve = "unreserve";
  static const receiveReturn = "return";

  static const Map<String, List<String>> reasons = {
    add: ["restock", "return", "correction"],
    remove: ["sale", "damage", "loss", "expiration", "theft", "correction"],
    reserve: [],
    unreserve: ["reintegration", "expiration", "cancelled"],
    receiveReturn: ["customer", "defective", "wrong_item", "warranty"],
  };

  /// The reason an omitted one becomes (ST-12). A reserve has none.
  static const Map<String, String> defaults = {
    add: "restock",
    remove: "correction",
    unreserve: "reintegration",
    receiveReturn: "customer",
  };

  /// What caused a movement.
  static const Set<String> sources = {"manual", "pos", "import", "outbox", "sync"};
}

/// A table's starting fields per template (I-1): what `inventory.tables.create {template}` adds.
/// The app's `TableTemplate` names the codes; the columns are decided here, once, for every
/// master. Names come in the company's language, English when it has none of its own here.
abstract final class TableTemplates {
  static const blank = "BLANK";

  /// Code → fields in order: `(type, {language: name}, unit?)`.
  static const Map<String, List<(String, Map<String, String>, String?)>> fields = {
    "CLOTHING": [..._product, (FieldTypes.options, _size, null), (FieldTypes.options, _color, null), (FieldTypes.categories, _category, null)],
    "SHOES": [..._product, (FieldTypes.options, _size, null), (FieldTypes.options, _color, null), (FieldTypes.text, _brand, null)],
    "ELECTRONICS": [..._product, (FieldTypes.text, _brand, null), (FieldTypes.text, _model, null), (FieldTypes.barcode, _barcode, null), (FieldTypes.number, _warranty, null)],
    "APPLIANCES": [..._product, (FieldTypes.text, _brand, null), (FieldTypes.text, _model, null), (FieldTypes.barcode, _barcode, null), (FieldTypes.number, _warranty, null)],
    "HOME": [..._product, (FieldTypes.categories, _category, null), (FieldTypes.text, _material, null), (FieldTypes.measure, _weight, "kg")],
    "HEALTH": [..._product, (FieldTypes.text, _brand, null), (FieldTypes.barcode, _barcode, null), (FieldTypes.date, _expiration, null)],
    "BEAUTY": [..._product, (FieldTypes.text, _brand, null), (FieldTypes.barcode, _barcode, null), (FieldTypes.measure, _volume, "ml"), (FieldTypes.date, _expiration, null)],
    "FOOD": [..._product, (FieldTypes.categories, _category, null), (FieldTypes.barcode, _barcode, null), (FieldTypes.measure, _weight, "g"), (FieldTypes.date, _expiration, null)],
    "ACCESSORIES": [..._product, (FieldTypes.categories, _category, null), (FieldTypes.options, _color, null), (FieldTypes.text, _material, null)],
  };

  /// Whether [code] is a template (or [blank], which adds nothing).
  static bool exists(String code) => code == blank || fields.containsKey(code);

  /// [name] in [language], or in English.
  static String name(Map<String, String> name, String language) => name[language] ?? name["en"]!;

  static const _product = [
    (FieldTypes.title, {"en": "Name", "es": "Nombre", "pt": "Nome"}, null),
    (FieldTypes.sku, {"en": "SKU", "es": "SKU", "pt": "SKU"}, null),
    (FieldTypes.price, {"en": "Price", "es": "Precio", "pt": "Preço"}, null),
    (FieldTypes.stock, {"en": "Stock", "es": "Existencia", "pt": "Estoque"}, null),
    (FieldTypes.image, {"en": "Photos", "es": "Fotos", "pt": "Fotos"}, null),
  ];

  static const _size = {"en": "Size", "es": "Talla", "pt": "Tamanho"};
  static const _color = {"en": "Color", "es": "Color", "pt": "Cor"};
  static const _category = {"en": "Category", "es": "Categoría", "pt": "Categoria"};
  static const _brand = {"en": "Brand", "es": "Marca", "pt": "Marca"};
  static const _model = {"en": "Model", "es": "Modelo", "pt": "Modelo"};
  static const _barcode = {"en": "Barcode", "es": "Código de barras", "pt": "Código de barras"};
  static const _warranty = {"en": "Warranty (months)", "es": "Garantía (meses)", "pt": "Garantia (meses)"};
  static const _material = {"en": "Material", "es": "Material", "pt": "Material"};
  static const _weight = {"en": "Weight", "es": "Peso", "pt": "Peso"};
  static const _volume = {"en": "Volume", "es": "Volumen", "pt": "Volume"};
  static const _expiration = {"en": "Expiration", "es": "Vencimiento", "pt": "Validade"};
}
