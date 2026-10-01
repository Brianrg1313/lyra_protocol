/// Event names of `protocol-v1.md` §5 the engine emits so far. A client matches them exactly: a
/// misspelled event doesn't fail, it just never arrives.
abstract final class Events {
  /// A profile field or the logo changed: `{keys: [...]}` (`business.md`).
  static const businessChanged = "business/changed";

  /// A table's name, fields or records changed: `{id, what: "structure" | "records"}`
  /// (`inventory.md`).
  static const tableChanged = "table/changed";

  /// A product's balance after a movement: `{productId, table, onHand, reserved, available}`
  /// (`stock.md` ST-15).
  static const stockChanged = "stock/changed";
}
