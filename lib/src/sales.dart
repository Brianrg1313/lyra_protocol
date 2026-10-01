/// The sales board's vocabulary (`sales.md`): where a sale stands, and how it reaches its customer.
///
/// It is the cloud's catalogue (`GET /sales/stages`), snapshotted with the release, so a row means
/// the same on both sides (SA-2). The cloud names it in Spanish only; the other languages are this
/// snapshot's, for a company that operates in one.
abstract final class SaleStages {
  static const process = "process";
  static const done = "done";

  static const open = "open";
  static const shipping = "shipping";
  static const handover = "handover";
  static const transit = "transit";
  static const pickup = "pickup";
  static const owed = "owed";
  static const completed = "completed";

  /// Code → `(section, level, attention, offline, {language: name})`, **in precedence order**.
  /// `offline`: a master can measure it; the conversation stages can't (chats are cloud only), and
  /// `owed` waits for credit (`money.md`).
  static const Map<String, (String, String, bool, bool, Map<String, String>)> kinds = {
    "open": (process, "info", true, true, {
      "es": "Ticket abierto", "en": "Open ticket", "pt": "Ticket aberto", "fr": "Ticket ouvert",
      "it": "Scontrino aperto", "de": "Offener Bon",
    }),
    "uncharged": (process, "warning", true, false, {
      "es": "Sin forma de pago", "en": "No payment method", "pt": "Sem forma de pagamento",
      "fr": "Sans moyen de paiement", "it": "Senza metodo di pagamento", "de": "Keine Zahlungsart",
    }),
    "verifying": (process, "warning", true, false, {
      "es": "Pago por verificar", "en": "Payment to verify", "pt": "Pagamento a verificar",
      "fr": "Paiement à vérifier", "it": "Pagamento da verificare", "de": "Zahlung zu prüfen",
    }),
    "paying": (process, "info", false, false, {
      "es": "Pago pendiente", "en": "Payment pending", "pt": "Pagamento pendente", "fr": "Paiement en attente",
      "it": "Pagamento in sospeso", "de": "Zahlung ausstehend",
    }),
    "reserving": (process, "info", false, false, {
      "es": "Stock reservado", "en": "Stock reserved", "pt": "Estoque reservado", "fr": "Stock réservé",
      "it": "Scorte riservate", "de": "Bestand reserviert",
    }),
    "shipping": (process, "warning", true, true, {
      "es": "Por enviar", "en": "To ship", "pt": "A enviar", "fr": "À expédier", "it": "Da spedire",
      "de": "Zu versenden",
    }),
    "handover": (process, "warning", true, true, {
      "es": "Entrega por coordinar", "en": "Handover to arrange", "pt": "Entrega a combinar",
      "fr": "Remise à organiser", "it": "Consegna da concordare", "de": "Übergabe abzustimmen",
    }),
    "transit": (process, "info", false, true, {
      "es": "En camino", "en": "On the way", "pt": "A caminho", "fr": "En route", "it": "In viaggio",
      "de": "Unterwegs",
    }),
    "pickup": (process, "info", false, true, {
      "es": "Listo para retirar", "en": "Ready for pickup", "pt": "Pronto para retirada", "fr": "Prêt à retirer",
      "it": "Pronto per il ritiro", "de": "Abholbereit",
    }),
    "owed": (process, "warning", true, false, {
      "es": "Crédito por cobrar", "en": "Credit to collect", "pt": "Crédito a receber", "fr": "Crédit à encaisser",
      "it": "Credito da incassare", "de": "Offene Forderung",
    }),
    "completed": (done, "success", false, true, {
      "es": "Venta completada", "en": "Sale completed", "pt": "Venda concluída", "fr": "Vente terminée",
      "it": "Vendita completata", "de": "Verkauf abgeschlossen",
    }),
    "sold": (done, "success", false, false, {
      "es": "Venta cerrada", "en": "Sale closed", "pt": "Venda fechada", "fr": "Vente clôturée",
      "it": "Vendita chiusa", "de": "Verkauf geschlossen",
    }),
  };

  /// The stages as the app's `SaleStage` reads them, named in [language] (English when it has none
  /// here). With [offline], only those a master measures (SA-2).
  static List<Map<String, Object?>> rows(String language, {bool offline = false}) => [
    for (final MapEntry(key: stage, value: (section, level, attention, measured, names)) in kinds.entries)
      if (!offline || measured)
        {"stage": stage, "name": names[language] ?? names["en"], "section": section, "level": level, "attention": attention},
  ];

  /// [stage]'s name in [language], or null for a code this release doesn't know.
  static String? name(String stage, String language) {
    final names = kinds[stage]?.$5;

    return names == null ? null : names[language] ?? names["en"];
  }
}

/// How a sale reaches its customer (`sales.md` SA-20): the mode is who moves next, the state how
/// far that got.
abstract final class Handover {
  static const immediate = "immediate";
  static const pickup = "pickup";
  static const delivery = "delivery";

  static const pending = "pending";
  static const dispatched = "dispatched";
  static const done = "done";

  /// Mode → `(states in order, {language: name})`. The first state is where naming only the mode
  /// leaves it (SA-22).
  static const Map<String, (List<String>, Map<String, String>)> modes = {
    immediate: ([done], {
      "es": "Entregado en el momento", "en": "Handed over on the spot", "pt": "Entregue na hora",
      "fr": "Remis sur place", "it": "Consegnato sul posto", "de": "Sofort übergeben",
    }),
    pickup: ([pending, done], {
      "es": "Retiro en tienda", "en": "Store pickup", "pt": "Retirada na loja", "fr": "Retrait en magasin",
      "it": "Ritiro in negozio", "de": "Abholung im Geschäft",
    }),
    delivery: ([pending, dispatched, done], {
      "es": "Envío a domicilio", "en": "Home delivery", "pt": "Entrega em domicílio", "fr": "Livraison à domicile",
      "it": "Consegna a domicilio", "de": "Lieferung nach Hause",
    }),
  };

  static const Map<String, Map<String, String>> states = {
    pending: {
      "es": "Sin entregar", "en": "Not handed over", "pt": "Não entregue", "fr": "Non remis", "it": "Non consegnato",
      "de": "Nicht übergeben",
    },
    dispatched: {
      "es": "Despachado", "en": "Dispatched", "pt": "Despachado", "fr": "Expédié", "it": "Spedito", "de": "Versandt",
    },
    done: {
      "es": "Entregado", "en": "Handed over", "pt": "Entregue", "fr": "Remis", "it": "Consegnato", "de": "Übergeben",
    },
  };

  /// The modes as the app's `SaleHandoverMode` reads them, named in [language].
  static List<Map<String, Object?>> rows(String language) => [
    for (final MapEntry(key: mode, value: (allowed, names)) in modes.entries)
      {
        "mode": mode,
        "name": names[language] ?? names["en"],
        "states": [for (final state in allowed) {"state": state, "name": stateName(state, language)}],
      },
  ];

  static String? modeName(String? mode, String language) {
    final names = modes[mode]?.$2;

    return names == null ? null : names[language] ?? names["en"];
  }

  static String? stateName(String? state, String language) {
    final names = states[state];

    return names == null ? null : names[language] ?? names["en"];
  }
}

/// Where a sale came in through. Offline there is one: the counter (`sales.md`, row fields).
abstract final class SaleChannels {
  static const pos = "pos";

  static const Map<String, String> _names = {
    "es": "Punto de venta", "en": "Point of sale", "pt": "Ponto de venda", "fr": "Point de vente",
    "it": "Punto vendita", "de": "Kasse",
  };

  /// The channels as the app's `SaleChannel` reads them.
  static List<Map<String, Object?>> rows(String language) => [
    {"channel": pos, "name": _names[language] ?? _names["en"], "default": true},
  ];
}
