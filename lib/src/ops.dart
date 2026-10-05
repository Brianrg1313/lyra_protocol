/// How an op is carried and replayed.
enum OpKind {
  /// Answers data and changes nothing. Never carries a `commandId`.
  read,

  /// Changes the company's data. **Requires a `commandId`** (UUIDv7), is applied once however
  /// many times it is sent, and appends to the oplog.
  write,

  /// Handshake, sign in, token and subscription management. Bound to one connection, never in
  /// the oplog, never replayed, so it carries no `commandId` either.
  session,
}

/// One op of the catalogue (`protocol-v1.md` §9). Names are domain verbs, deliberately not the
/// backend's REST paths (plan principle 1).
final class Op {
  const Op._(this.name, this.kind);

  final String name;
  final OpKind kind;

  bool get needsCommandId => kind == OpKind.write;

  @override
  String toString() => name;
}

/// The v1 op catalogue. Arguments, answers and errors of each op are in its spec
/// (`docs/offline/specs/<domain>.md`) until phase 4 moves them into typed DTOs here.
abstract final class Ops {
  // protocol
  static const hello = Op._("hello", OpKind.session);
  static const engineUnlock = Op._("engine.unlock", OpKind.session);
  static const sessionBind = Op._("session.bind", OpKind.session);
  static const deviceProve = Op._("device.prove", OpKind.session);
  static const eventsSubscribe = Op._("events.subscribe", OpKind.session);
  static const eventsUnsubscribe = Op._("events.unsubscribe", OpKind.session);

  // session
  static const authIdentify = Op._("auth.identify", OpKind.session);
  static const authSignIn = Op._("auth.signIn", OpKind.session);
  static const authSignInPin = Op._("auth.signInPin", OpKind.session);
  static const authActivate = Op._("auth.activate", OpKind.session);
  static const authGrant = Op._("auth.grant", OpKind.session);
  static const authUnseal = Op._("auth.unseal", OpKind.session);
  static const authRefresh = Op._("auth.refresh", OpKind.session);
  static const authSignOut = Op._("auth.signOut", OpKind.session);
  static const accountChangePassword = Op._("account.changePassword", OpKind.write);
  static const accountSetPin = Op._("account.setPin", OpKind.write);
  static const sessionBootstrap = Op._("session.bootstrap", OpKind.read);
  static const permissionsGet = Op._("permissions.get", OpKind.read);
  static const permissionsTemplatesList = Op._("permissions.templates.list", OpKind.read);
  static const permissionsTemplatesCreate = Op._("permissions.templates.create", OpKind.write);
  static const permissionsTemplatesEdit = Op._("permissions.templates.edit", OpKind.write);
  static const permissionsTemplatesRemove = Op._("permissions.templates.remove", OpKind.write);
  static const permissionsMembersList = Op._("permissions.members.list", OpKind.read);
  static const permissionsMembersDetail = Op._("permissions.members.detail", OpKind.read);
  static const permissionsMembersAssign = Op._("permissions.members.assign", OpKind.write);
  static const permissionsMembersRevoke = Op._("permissions.members.revoke", OpKind.write);
  static const permissionsRequestsList = Op._("permissions.requests.list", OpKind.read);
  static const permissionsRequestsCreate = Op._("permissions.requests.create", OpKind.write);
  static const devicesList = Op._("devices.list", OpKind.read);
  static const devicesRename = Op._("devices.rename", OpKind.write);
  static const devicesRevoke = Op._("devices.revoke", OpKind.write);
  static const pairingStart = Op._("pairing.start", OpKind.session);
  static const devicesBrowserCa = Op._("devices.browserCa", OpKind.read);

  // business
  static const businessCreate = Op._("business.create", OpKind.write);
  static const businessProfile = Op._("business.profile", OpKind.read);
  static const businessEdit = Op._("business.edit", OpKind.write);
  static const businessSetLogo = Op._("business.setLogo", OpKind.write);
  static const businessLink = Op._("business.link", OpKind.write);
  static const businessSiteGet = Op._("business.site.get", OpKind.read);
  static const businessSiteEdit = Op._("business.site.edit", OpKind.write);
  static const catalogGet = Op._("catalog.get", OpKind.read);
  static const syncPrepare = Op._("sync.prepare", OpKind.write);
  static const syncEnroll = Op._("sync.enroll", OpKind.write);
  static const syncStatus = Op._("sync.status", OpKind.read);

  // inventory
  static const inventoryTablesList = Op._("inventory.tables.list", OpKind.read);
  static const inventoryTablesCreate = Op._("inventory.tables.create", OpKind.write);
  static const inventoryTablesEdit = Op._("inventory.tables.edit", OpKind.write);
  static const inventoryTablesDelete = Op._("inventory.tables.delete", OpKind.write);
  static const inventoryTablesStructure = Op._("inventory.tables.structure", OpKind.read);
  static const inventoryTablesDetails = Op._("inventory.tables.details", OpKind.read);
  static const inventoryTablesNormalize = Op._("inventory.tables.normalize", OpKind.write);
  static const inventoryFieldsCreate = Op._("inventory.fields.create", OpKind.write);
  static const inventoryFieldsEdit = Op._("inventory.fields.edit", OpKind.write);
  static const inventoryFieldsDelete = Op._("inventory.fields.delete", OpKind.write);
  static const inventoryRecordsList = Op._("inventory.records.list", OpKind.read);
  static const inventoryRecordsCreate = Op._("inventory.records.create", OpKind.write);
  static const inventoryRecordsEdit = Op._("inventory.records.edit", OpKind.write);
  static const inventoryRecordsDelete = Op._("inventory.records.delete", OpKind.write);
  static const inventoryImagesAdd = Op._("inventory.images.add", OpKind.write);
  static const inventoryImagesRemove = Op._("inventory.images.remove", OpKind.write);
  static const inventoryImportStructure = Op._("inventory.import.structure", OpKind.write);
  static const inventoryImportRecords = Op._("inventory.import.records", OpKind.write);

  // stock
  static const stockMove = Op._("stock.move", OpKind.write);
  static const stockHistory = Op._("stock.history", OpKind.read);
  static const stockSummary = Op._("stock.summary", OpKind.read);

  // pos
  static const posSummary = Op._("pos.summary", OpKind.read);
  static const posCatalog = Op._("pos.catalog", OpKind.read);
  static const posMethods = Op._("pos.methods", OpKind.read);
  static const posInvoicesOpen = Op._("pos.invoices.open", OpKind.write);
  static const posInvoicesLine = Op._("pos.invoices.line", OpKind.write);
  static const posInvoicesClose = Op._("pos.invoices.close", OpKind.write);
  static const posInvoicesCancel = Op._("pos.invoices.cancel", OpKind.write);
  static const posInvoicesList = Op._("pos.invoices.list", OpKind.read);
  static const posOutboxSale = Op._("pos.outbox.sale", OpKind.write);
  static const posSnapshot = Op._("pos.snapshot", OpKind.read);

  // sales
  static const salesList = Op._("sales.list", OpKind.read);
  static const salesCatalog = Op._("sales.catalog", OpKind.read);
  static const salesDetail = Op._("sales.detail", OpKind.read);
  static const salesFulfil = Op._("sales.fulfil", OpKind.write);

  // money
  static const moneyCatalog = Op._("money.catalog", OpKind.read);
  static const moneySummary = Op._("money.summary", OpKind.read);
  static const moneyPaymentsRecord = Op._("money.payments.record", OpKind.write);
  static const moneyPaymentsVoid = Op._("money.payments.void", OpKind.write);
  static const moneyPaymentsSearch = Op._("money.payments.search", OpKind.read);
  static const moneyReceivables = Op._("money.receivables", OpKind.read);
  static const moneyMethodsList = Op._("money.methods.list", OpKind.read);
  static const moneyMethodsRails = Op._("money.methods.rails", OpKind.read);
  static const moneyMethodsCreate = Op._("money.methods.create", OpKind.write);
  static const moneyMethodsEdit = Op._("money.methods.edit", OpKind.write);
  static const moneyMethodsRemove = Op._("money.methods.remove", OpKind.write);
  static const moneyCurrenciesGet = Op._("money.currencies.get", OpKind.read);
  static const moneyCurrenciesSave = Op._("money.currencies.save", OpKind.write);
  static const moneyCurrenciesRemove = Op._("money.currencies.remove", OpKind.write);

  /// Changes nothing in the company's data; the export itself goes to the audit log
  /// (`money.md` M-60).
  static const exportAccounting = Op._("export.accounting", OpKind.read);

  // employees
  static const employeesList = Op._("employees.list", OpKind.read);
  static const employeesFormer = Op._("employees.former", OpKind.read);
  static const employeesDetail = Op._("employees.detail", OpKind.read);
  static const employeesInvite = Op._("employees.invite", OpKind.write);
  static const employeesReissueActivation = Op._("employees.reissueActivation", OpKind.write);
  static const employeesEdit = Op._("employees.edit", OpKind.write);
  static const employeesAccept = Op._("employees.accept", OpKind.write);
  static const profileEdit = Op._("profile.edit", OpKind.write);

  // deliveries
  static const deliveryGet = Op._("delivery.get", OpKind.read);
  static const deliverySet = Op._("delivery.set", OpKind.write);
  static const deliveryOptionsCreate = Op._("delivery.options.create", OpKind.write);
  static const deliveryOptionsEdit = Op._("delivery.options.edit", OpKind.write);
  static const deliveryOptionsRemove = Op._("delivery.options.remove", OpKind.write);
  static const deliveryProviders = Op._("delivery.providers", OpKind.read);
  static const deliveryAreasList = Op._("delivery.areas.list", OpKind.read);
  static const deliveryAreasCreate = Op._("delivery.areas.create", OpKind.write);
  static const deliveryAreasEdit = Op._("delivery.areas.edit", OpKind.write);
  static const deliveryAreasRemove = Op._("delivery.areas.remove", OpKind.write);

  static const List<Op> all = [
    hello, engineUnlock, sessionBind, deviceProve, eventsSubscribe, eventsUnsubscribe,
    authIdentify, authSignIn, authSignInPin, authActivate, authGrant, authUnseal, authRefresh, authSignOut,
    accountChangePassword, accountSetPin, sessionBootstrap, permissionsGet,
    permissionsTemplatesList, permissionsTemplatesCreate, permissionsTemplatesEdit, permissionsTemplatesRemove,
    permissionsMembersList, permissionsMembersDetail, permissionsMembersAssign, permissionsMembersRevoke,
    permissionsRequestsList, permissionsRequestsCreate, devicesList, devicesRename, devicesRevoke, pairingStart,
    devicesBrowserCa,
    businessCreate, businessProfile, businessEdit, businessSetLogo, businessLink, businessSiteGet, businessSiteEdit,
    catalogGet, syncPrepare, syncEnroll, syncStatus,
    inventoryTablesList, inventoryTablesCreate, inventoryTablesEdit, inventoryTablesDelete,
    inventoryTablesStructure, inventoryTablesDetails, inventoryTablesNormalize,
    inventoryFieldsCreate, inventoryFieldsEdit, inventoryFieldsDelete, inventoryRecordsList,
    inventoryRecordsCreate, inventoryRecordsEdit, inventoryRecordsDelete, inventoryImagesAdd,
    inventoryImagesRemove, inventoryImportStructure, inventoryImportRecords,
    stockMove, stockHistory, stockSummary,
    posSummary, posCatalog, posMethods, posInvoicesOpen, posInvoicesLine, posInvoicesClose,
    posInvoicesCancel, posInvoicesList, posOutboxSale, posSnapshot,
    salesList, salesCatalog, salesDetail, salesFulfil,
    moneyCatalog, moneySummary, moneyPaymentsRecord, moneyPaymentsVoid, moneyPaymentsSearch,
    moneyReceivables, moneyMethodsList, moneyMethodsRails, moneyMethodsCreate, moneyMethodsEdit,
    moneyMethodsRemove, moneyCurrenciesGet, moneyCurrenciesSave, moneyCurrenciesRemove,
    exportAccounting,
    employeesList, employeesFormer, employeesDetail, employeesInvite, employeesReissueActivation,
    employeesEdit, employeesAccept, profileEdit,
    deliveryGet, deliverySet, deliveryOptionsCreate, deliveryOptionsEdit, deliveryOptionsRemove,
    deliveryProviders, deliveryAreasList, deliveryAreasCreate, deliveryAreasEdit,
    deliveryAreasRemove,
  ];

  static final Map<String, Op> _byName = {for (final op in all) op.name: op};

  /// The op called [name], or null when this protocol version has none (`unknown_op`).
  static Op? byName(String name) => _byName[name];
}
