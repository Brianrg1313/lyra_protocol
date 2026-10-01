/// The business domain's vocabulary (`business.md`): which keys its edits take, and its event.
///
/// Keys are the spec's field names. The app's LAN source maps its request keys onto them; the
/// engine refuses any other (`invalid_field`).
abstract final class BusinessFields {
  /// What `business.edit` takes, one key at a time (B-2). `currency` is not here: it is fixed
  /// after setup (B-5). `name` can't be cleared.
  static const Set<String> editable = {
    "name", "legalName", "nickname", "caption", "activity", "taxId", "country", "language",
    "phone", "website", "incorporationDate", "timezone",
  };

  /// What `business.site.edit` takes: only the changed keys (B-10). `country` is the company's
  /// (B-12).
  static const Set<String> site = {
    "name", "legalName", "taxId", "phone", "address", "landmark", "city", "region", "postalCode",
    "country", "latitude", "longitude", "storefront", "online",
  };
}
