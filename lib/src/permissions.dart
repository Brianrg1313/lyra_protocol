/// A permission structure: one entry per section of [PermissionCatalog], where `access` is the
/// section itself and every other key one of its actions.
/// `{inventory: {access: true, restock: true, remove: false, …}, money: {access: false, …}}`
typedef PermissionSections = Map<String, Map<String, bool>>;

/// **What a permission is**: the backend's `lib/models/permissions/catalog.js`, the one vocabulary
/// of permissions online and on a master (`session.md` P-1). A key is `<section>` (entering it) or
/// `<section>.<action>` (one thing inside it), and an action is only ever granted together with
/// its section: `grants(s, "money.void")` is `money.access && money.void`.
///
/// This is a copy, not a design: changing a line starts in the backend, and
/// `test/permissions_test.dart` compares the copy against its exported snapshot
/// (`pnpm permissions:export`). `server` and `money.export` are a master's alone: no cloud route
/// serves them, but they are in the cloud's catalog so a person holds one set online and offline.
abstract final class PermissionCatalog {
  /// Section → its actions, in the backend's order.
  static const Map<String, List<String>> sections = {
    "inventory": ["restock", "remove", "return", "hold", "configure", "pictures"],
    "reservations": ["create", "manage"],
    "pos": ["sell", "cancel"],
    "sales": ["fulfill"],
    "money": ["charge", "void", "accounts", "export"],
    "employees": ["manage"],
    "permissions": ["assign", "templates"],
    "products": ["create", "edit", "delete", "import", "structure"],
    "chats": ["reply", "manage", "assign", "bot"],
    "channels": ["create", "edit", "delete", "connect"],
    "appointments": ["book", "configure"],
    "knowledge": ["create", "edit", "delete"],
    "branches": ["create", "edit", "delete"],
    "delivery": ["create", "edit", "delete"],
    "business": ["edit", "emails"],
    "server": ["devices", "backups", "stop"],
  };

  /// The flag a section's own key is stored under.
  static const access = "access";

  /// Every grantable key, each section before its actions: what `all` expands to.
  static List<String> keys() => [
    for (final MapEntry(key: section, value: actions) in sections.entries) ...[
      section,
      for (final action in actions) "$section.$action",
    ],
  ];

  /// Whether [key] names something in the catalog.
  static bool known(String key) {
    final parts = key.split(".");
    final actions = sections[parts.first];

    return actions != null && parts.length <= 2 && (parts.length == 1 || actions.contains(parts[1]));
  }

  /// The whole catalog with every flag [value]: `true` is what `all` reads as, `false` a person
  /// with nothing.
  static PermissionSections filled(bool value) => {
    for (final MapEntry(key: section, value: actions) in sections.entries)
      section: {access: value, for (final action in actions) action: value},
  };

  /// Brings any stored structure to the catalog's exact shape: every flag present and a bool,
  /// anything the catalog no longer knows dropped. An action added after [stored] was written
  /// reads `false`; with [all], everything reads `true`.
  static PermissionSections normalize(Object? stored, {bool all = false}) {
    final result = filled(all);
    if (all || stored is! Map) return result;

    for (final MapEntry(key: section, value: flags) in result.entries) {
      final source = stored[section];
      if (source is! Map) continue;

      for (final flag in flags.keys.toList()) {
        flags[flag] = source[flag] == true;
      }
    }

    return result;
  }

  /// A structure from a list of keys (how presets are written). An action named without its
  /// section is stored and grants nothing until the section is given. Unknown keys are dropped.
  static PermissionSections fromKeys(Iterable<String> keys) {
    final result = filled(false);

    for (final key in keys.where(known)) {
      final parts = key.split(".");
      result[parts.first]![parts.length == 1 ? access : parts[1]] = true;
    }

    return result;
  }

  /// Whether [sections] grant [key].
  static bool grants(PermissionSections sections, String key) {
    final parts = key.split(".");
    final flags = sections[parts.first];

    return flags?[access] == true && (parts.length == 1 || flags?[parts[1]] == true);
  }

  /// The keys whose stored value differs between two structures: what an assignment changes, so
  /// what the person assigning must hold.
  static List<String> changes(PermissionSections before, PermissionSections after) =>
    keys().where((key) => _flag(before, key) != _flag(after, key)).toList();

  /// Reads a partial structure a client sent (`{<section>: {access?, <action>?: bool}}`). Only
  /// what is sent comes back, to be laid over another one ([merge]). An unknown key is refused,
  /// never dropped: a typo that grants nothing is a permission a manager believes they gave.
  /// Answers the offending key as [PermissionsRead.invalid].
  static PermissionsRead read(Object? input) {
    if (input is! Map) return const PermissionsRead.invalid("permissions");

    final result = <String, Map<String, bool>>{};

    for (final MapEntry(:key, :value) in input.entries) {
      final section = "$key";
      final actions = sections[section];
      if (actions == null || value is! Map) return PermissionsRead.invalid(section);

      final flags = result[section] = {};
      for (final MapEntry(key: flag, value: raw) in value.entries) {
        final bool? on = switch (raw) {
          true || 1 || "1" || "true" => true,
          false || 0 || "0" || "false" => false,
          _ => null,
        };
        if ((flag != access && !actions.contains(flag)) || on == null) return PermissionsRead.invalid("$section.$flag");

        flags["$flag"] = on;
      }
    }

    return PermissionsRead._(result);
  }

  /// Lays [partial] ([read]'s) over [base], normalized.
  static PermissionSections merge(PermissionSections base, Map<String, Map<String, bool>> partial) {
    final result = normalize(base);

    for (final MapEntry(key: section, value: flags) in partial.entries) {
      result[section]?.addAll(flags);
    }

    return result;
  }

  /// The catalog as the editor draws it, in order.
  static List<Map<String, Object>> describe() => [
    for (final MapEntry(key: section, value: actions) in sections.entries) {"key": section, "actions": [...actions]},
  ];

  /// The stored flag of [key] without the `access` gate [grants] applies: two structures that
  /// differ only in an action of a closed section still differ in what they store.
  static bool _flag(PermissionSections sections, String key) {
    final parts = key.split(".");

    return sections[parts.first]?[parts.length == 1 ? access : parts[1]] == true;
  }
}

/// [PermissionCatalog.read]'s answer: the partial structure, or the key that made it invalid.
final class PermissionsRead {
  const PermissionsRead._(this.sections) : invalidKey = null;

  const PermissionsRead.invalid(String key) : sections = null, invalidKey = key;

  final Map<String, Map<String, bool>>? sections;
  final String? invalidKey;

  bool get ok => sections != null;
}

/// **The app's areas, translated to the catalog**: the backend's `areas.js`. The app gates its
/// screens by area ids (`<area>.<action>`, `docs/app-areas.json`); permissions are stored and
/// checked as catalog keys. Each id maps to the keys its endpoints (or a master's ops) require:
/// one key, a list (every one), `null` (every member), or [owner] (nothing serves it yet: only
/// `all`). On top, an action is granted only with its area's `view`, and a `view` only with its
/// parent's. Changing a line starts in the backend (see [PermissionCatalog]).
abstract final class PermissionAreas {
  /// Only `all`: the owner.
  static const owner = "*";

  /// Area id → what it requires, in the backend's order (a parent's `view` before its children).
  static const Map<String, Object?> map = {
    "business.view": null,
    "business.delete": owner,
    "business.statistics.view": "business",
    "business.employees.view": "employees",
    "business.employees.view_personal": "employees",
    "business.employees.invite": "employees.manage",
    "business.employees.permissions": ["permissions", "permissions.assign"],
    "business.branches.view": null,
    "business.branches.create": "branches.create",
    "business.branches.edit": "branches.edit",
    "business.clients.view": "chats",
    "business.settings.view": "business",
    "business.settings.edit": "business.edit",
    "business.settings.edit_logo": "business.edit",
    "business.settings.manage_emails": "business.emails",
    "messages.view": "chats",
    "messages.reply": "chats.reply",
    "messages.take_over": "chats.bot",
    "messages.assign": "chats.assign",
    "messages.edit_tags": owner,
    "messages.set_stage": "chats.manage",
    "messages.resolve_attention": "chats.manage",
    "messages.view_usage": "chats",
    "deliveries.view": "delivery",
    "deliveries.create": owner,
    "deliveries.settings.view": "delivery",
    "deliveries.settings.edit": ["delivery.create", "delivery.edit", "delivery.delete"],
    "deliveries.areas.view": "delivery",
    "deliveries.areas.create": "delivery.create",
    "deliveries.areas.edit": "delivery.edit",
    "deliveries.areas.delete": "delivery.delete",
    "sales.view": "sales",
    "sales.view_all": "sales",
    "sales.fulfil": "sales.fulfill",
    "sales.approve": "chats.manage",
    "sales.process.view": "sales",
    "sales.done.view": "sales",
    "inventory.view": "products",
    "inventory.create_table": "products.structure",
    "inventory.import": "products.import",
    "inventory.edit_table": "products.structure",
    "inventory.delete_table": "products.structure",
    "inventory.edit_columns": "products.structure",
    "inventory.edit_records": ["products.create", "products.edit", "products.delete"],
    "inventory.move_stock": ["inventory.restock", "inventory.remove"],
    "channels.view": "channels",
    "channels.create": "channels.create",
    "channels.edit": "channels.edit",
    "channels.toggle": ["channels.edit", "channels.connect"],
    "channels.delete": ["channels.delete", "channels.connect"],
    "finance.view": "money",
    "finance.overview.view": "money",
    "finance.overview.view_bot_cost": "money",
    "finance.payments.view": "money",
    "finance.payments.record": "money.charge",
    "finance.payments.void": "money.void",
    "finance.receivables.view": "money",
    "finance.receivables.collect": "money.charge",
    "finance.methods.view": "money",
    "finance.methods.create": "money.accounts",
    "finance.methods.edit": "money.accounts",
    "finance.methods.delete": "money.accounts",
    "finance.methods.manage_currencies": "money.accounts",
    "finance.export": "money.export",
    "pos.view": "pos",
    "pos.sell": "pos.sell",
    "pos.custom_amount": "pos.sell",
    "pos.set_tax": "pos.sell",
    "pos.checkout": "pos.sell",
    "pos.cancel_ticket": "pos.cancel",
    "local_server.view": "server",
    "local_server.devices": "server.devices",
    "local_server.backups": "server.backups",
    "local_server.stop": "server.stop",
    "services.view": owner,
    "marketing.view": owner,
    "report.view": owner,
    "external_services.view": owner,
    "connections.view": owner,
    "connections.create": owner,
    "connections.edit": owner,
    "connections.delete": owner,
  };

  /// The area ids [sections] grant, in the map's order.
  static List<String> granted(PermissionSections sections, {bool all = false}) {
    bool holds(Object? required) {
      if (all || required == null) return true;
      if (required == owner) return false;

      return _keys(required).every((key) => PermissionCatalog.grants(sections, key));
    }

    final open = <String>{};

    // A parent's `view` comes before its children in the map, so one pass settles the chain.
    for (final MapEntry(key: id, value: required) in map.entries) {
      final gate = _gate(id);
      if ((gate == null || open.contains(gate)) && holds(required)) open.add(id);
    }

    return [...open];
  }

  /// What granting [id] takes: its keys and those of every `view` it hangs from; `owner` when
  /// anything on that chain is [owner]. Null for an id the map doesn't have.
  static ({bool owner, List<String> keys})? requires(String id) {
    if (!map.containsKey(id)) return null;

    final keys = <String>{};
    for (String? step = id; step != null; step = _gate(step)) {
      final required = map[step];
      if (required == owner) return (owner: true, keys: const <String>[]);
      if (required != null) keys.addAll(_keys(required));
    }

    return (owner: false, keys: [...keys]);
  }

  /// The granted ids nested as the app reads them (the cloud's `/init` `permissions` entry); an
  /// area with nothing granted is absent.
  /// `{business: {view: true, employees: {view: true, invite: true}}, pos: {view: true}}`
  static Map<String, Object> tree(PermissionSections sections, {bool all = false}) {
    final tree = <String, Object>{};

    for (final id in granted(sections, all: all)) {
      final path = id.split(".");
      final action = path.removeLast();
      var node = tree;

      for (final segment in path) {
        node = node.putIfAbsent(segment, () => <String, Object>{}) as Map<String, Object>;
      }

      node[action] = true;
    }

    return tree;
  }

  /// The `view` [id] is granted only with: an action's is its area's, an area's `view` its
  /// parent's, a top area's `view` none.
  static String? _gate(String id) {
    final area = id.substring(0, id.lastIndexOf("."));
    if (!id.endsWith(".view")) return "$area.view";

    return area.contains(".") ? "${area.substring(0, area.lastIndexOf("."))}.view" : null;
  }

  static List<String> _keys(Object required) => required is List ? [for (final key in required) "$key"] : ["$required"];
}

/// A global template: the backend's `lyra_admin`.`permission_templates` row (code, position) and
/// what it grants (`presets.js`). [name] and [description] are English; the app shows its own
/// words by [code].
final class PermissionPreset {
  const PermissionPreset(this.code, this.name, this.description, {this.all = false, this.keys = const []});

  final String code;
  final String name;
  final String description;

  /// Everything, now and later: only `owner`.
  final bool all;
  final List<String> keys;

  PermissionSections get sections => all ? PermissionCatalog.filled(true) : PermissionCatalog.fromKeys(keys);
}

/// The global templates, in the backend's order (`presets.js`, `schema.sql`).
abstract final class PermissionPresets {
  static const List<PermissionPreset> all = [
    PermissionPreset("owner", "Owner", "Every permission, including those added later", all: true),
    PermissionPreset(
      "manager",
      "Manager",
      "Runs the whole business, except the accounts it receives money into and the templates",
      keys: [
        "inventory", "inventory.restock", "inventory.remove", "inventory.return", "inventory.hold",
        "inventory.configure", "inventory.pictures",
        "reservations", "reservations.create", "reservations.manage",
        "pos", "pos.sell", "pos.cancel",
        "sales", "sales.fulfill",
        "money", "money.charge", "money.void",
        "employees", "employees.manage",
        "permissions", "permissions.assign",
        "products", "products.create", "products.edit", "products.delete", "products.import", "products.structure",
        "chats", "chats.reply", "chats.manage", "chats.assign", "chats.bot",
        "channels", "channels.edit",
        "appointments", "appointments.book", "appointments.configure",
        "knowledge", "knowledge.create", "knowledge.edit", "knowledge.delete",
        "delivery", "delivery.create", "delivery.edit", "delivery.delete",
        "business",
      ],
    ),
    PermissionPreset(
      "marketing",
      "Marketing",
      "The catalog, product pictures and the sales board",
      keys: [
        "inventory", "inventory.pictures",
        "products", "products.create", "products.edit", "products.import",
        "channels", "channels.edit",
        "knowledge", "knowledge.create", "knowledge.edit", "knowledge.delete",
        "chats",
        "appointments",
        "pos",
        "sales",
      ],
    ),
    PermissionPreset(
      "seller",
      "Seller",
      "Sells at the register, holds products and hands over orders",
      keys: [
        "inventory", "inventory.hold",
        "reservations", "reservations.create",
        "pos", "pos.sell",
        "sales", "sales.fulfill",
        "products",
        "chats", "chats.reply", "chats.manage", "chats.bot",
        "appointments", "appointments.book",
        "knowledge",
        "delivery",
      ],
    ),
    PermissionPreset(
      "auditor",
      "Auditor",
      "Sees every section without changing anything",
      keys: [
        "inventory", "reservations", "pos", "sales", "money", "employees", "permissions",
        "products", "chats", "channels", "appointments", "knowledge", "delivery", "business", "server",
      ],
    ),
    PermissionPreset(
      "billing",
      "Billing specialist",
      "Issues and voids invoices and records the payments that settle them",
      keys: ["pos", "pos.sell", "pos.cancel", "sales", "money", "money.charge"],
    ),
    PermissionPreset(
      "finance",
      "Finance",
      "All the money: payments, voids and the business's accounts",
      keys: ["money", "money.charge", "money.void", "money.accounts", "money.export", "sales", "pos", "inventory", "business"],
    ),
  ];

  /// The preset with [code], or null.
  static PermissionPreset? byCode(String code) {
    for (final preset in all) {
      if (preset.code == code) return preset;
    }

    return null;
  }
}

/// **What one person may do in one company**: the backend's `Permissions` (`all` + a normalized
/// structure). `all` is the owner's mark: every key, including ones the catalog adds later.
final class Grant {
  Grant({this.all = false, PermissionSections? sections})
    : sections = PermissionCatalog.normalize(sections, all: all);

  /// No permission at all: a member with access and no document enters and opens nothing.
  factory Grant.none() => Grant();

  /// Everything.
  factory Grant.everything() => Grant(all: true);

  final bool all;
  final PermissionSections sections;

  /// Whether this grants [key] (`<section>` or `<section>.<action>`).
  bool can(String key) => all || PermissionCatalog.grants(sections, key);

  /// The app's area ids it opens.
  List<String> get areas => PermissionAreas.granted(sections, all: all);

  /// The app's area ids nested, as `/init` answers them.
  Map<String, Object> get tree => PermissionAreas.tree(sections, all: all);
}
