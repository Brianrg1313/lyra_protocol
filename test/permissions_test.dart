import 'dart:convert';
import 'dart:io';

import 'package:lyra_protocol/lyra_protocol.dart';
import 'package:test/test.dart';

/// The backend's vocabulary as `pnpm permissions:export` prints it (backend
/// `scripts/permissions_export.js`). Refreshed in the same change as the backend's catalog, areas
/// or presets; a difference here means the master would grant other things than the cloud.
Map<String, dynamic> _backend() =>
  jsonDecode(File("test/fixtures/backend_permissions.json").readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('the copy equals the backend', () {
    test('catalog: the same sections and actions, in order', () {
      expect(PermissionCatalog.describe(), _backend()["catalog"]);
    });

    test('areas: the same ids, in order, requiring the same keys', () {
      final areas = _backend()["areas"] as Map<String, dynamic>;

      expect(PermissionAreas.map.keys.toList(), areas.keys.toList());
      for (final MapEntry(:key, :value) in areas.entries) {
        expect(PermissionAreas.map[key], value, reason: key);
      }
    });

    test('presets: the same templates, in order, granting the same keys', () {
      final presets = _backend()["presets"] as Map<String, dynamic>;

      expect([for (final preset in PermissionPresets.all) preset.code], presets.keys.toList());
      for (final preset in PermissionPresets.all) {
        final backend = presets[preset.code] as Map<String, dynamic>;
        expect(preset.all, backend["all"] ?? false, reason: preset.code);
        expect(preset.keys, backend["keys"] ?? const [], reason: preset.code);
      }
    });

    test('every area names keys the catalog knows', () {
      for (final MapEntry(:key, :value) in PermissionAreas.map.entries) {
        if (value == null || value == PermissionAreas.owner) continue;
        for (final required in value is List ? value : [value]) {
          expect(PermissionCatalog.known("$required"), isTrue, reason: "$key -> $required");
        }
      }
    });
  });

  group('rules', () {
    test('an action needs its section', () {
      final sections = PermissionCatalog.fromKeys(["money.void"]);

      expect(PermissionCatalog.grants(sections, "money.void"), isFalse);
      expect(PermissionCatalog.grants(PermissionCatalog.fromKeys(["money", "money.void"]), "money.void"), isTrue);
    });

    test('all grants every key, a structure stored with it notwithstanding', () {
      final grant = Grant(all: true, sections: PermissionCatalog.filled(false));

      expect(grant.can("server.stop"), isTrue);
      expect(grant.areas, contains("business.delete"));
    });

    test('normalize keeps the catalog\'s shape and drops what it does not know', () {
      final sections = PermissionCatalog.normalize({
        "money": {"access": true, "void": true, "teleport": true},
        "nowhere": {"access": true},
      });

      expect(sections.keys, PermissionCatalog.sections.keys);
      expect(sections["money"], {"access": true, "charge": false, "void": true, "accounts": false, "export": false});
    });

    test('read refuses an unknown or malformed key, naming it', () {
      expect(PermissionCatalog.read({"money": {"teleport": true}}).invalidKey, "money.teleport");
      expect(PermissionCatalog.read({"money": {"void": "maybe"}}).invalidKey, "money.void");
      expect(PermissionCatalog.read({"nowhere": {}}).invalidKey, "nowhere");
      expect(PermissionCatalog.read([]).invalidKey, "permissions");
      expect(PermissionCatalog.read({"money": {"access": 1, "void": "false"}}).sections, {
        "money": {"access": true, "void": false},
      });
    });

    test('changes lists every stored flag that differs, a closed section\'s actions included', () {
      final before = PermissionCatalog.fromKeys(["money.void"]);
      final after = PermissionCatalog.fromKeys(["money", "money.charge"]);

      expect(PermissionCatalog.changes(before, after), ["money", "money.charge", "money.void"]);
    });

    test('an area opens only with its parent\'s view, and the tree nests what is granted', () {
      final seller = PermissionPresets.byCode("seller")!.sections;

      expect(PermissionAreas.granted(seller), containsAll(["pos.view", "pos.sell", "sales.fulfil"]));
      expect(PermissionAreas.granted(seller), isNot(contains("finance.view")));
      expect(PermissionAreas.tree(PermissionCatalog.fromKeys(["money", "money.export"])), {
        "business": {"view": true, "branches": {"view": true}},
        "finance": {
          "view": true,
          "overview": {"view": true, "view_bot_cost": true},
          "payments": {"view": true},
          "receivables": {"view": true},
          "methods": {"view": true},
          "export": true,
        },
      });
    });

    test('requires takes the parents\' views and refuses what only the owner holds', () {
      final devices = PermissionAreas.requires("local_server.devices")!;
      expect(devices.owner, isFalse);
      expect(devices.keys, ["server.devices", "server"]);
      expect(PermissionAreas.requires("business.delete")?.owner, isTrue);
      expect(PermissionAreas.requires("nowhere.view"), isNull);
    });
  });
}
