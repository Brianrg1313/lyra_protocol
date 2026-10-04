/// Event names of `protocol-v1.md` §5 the engine emits so far. A client matches them exactly: a
/// misspelled event doesn't fail, it just never arrives.
abstract final class Events {
  /// A profile field or the logo changed: `{keys: [...]}` (`business.md`).
  static const businessChanged = "business/changed";

  /// This session's person's permissions or access changed: `{accountId}`, only to their own
  /// sessions, which re-read the bootstrap (`session.md` P-8).
  static const permissionsChanged = "permissions/changed";

  /// A table's name, fields or records changed: `{id, what: "structure" | "records"}`
  /// (`inventory.md`).
  static const tableChanged = "table/changed";

  /// An import's table started being typed: `{id, normalize, ai}` (`inventory.md` I-42).
  static const tableNormalizing = "table/normalizing";

  /// An import's table is typed and waits for its rows: `{id, ok, normalized, retyped, summarized,
  /// image}` (`inventory.md` I-45).
  static const tableReady = "table/ready";

  /// A product's balance after a movement: `{productId, table, onHand, reserved, available}`
  /// (`stock.md` ST-15).
  static const stockChanged = "stock/changed";

  /// A POS ticket was opened, a line written on it, charged or cancelled: `{id, ticket, units,
  /// total}`, the thin payload every till reads its own ticket back from (`pos.md`, events).
  static const invoiceOpened = "invoice/opened";
  static const invoiceUpdated = "invoice/updated";
  static const invoiceClosed = "invoice/closed";
  static const invoiceCancelled = "invoice/cancelled";

  /// A sale's stage or section changed (`sales.md`, events): the app's `SaleProgressModel`, every
  /// key present, `section: null` when the row left both lists.
  static const saleProgress = "sale/progress";
}
