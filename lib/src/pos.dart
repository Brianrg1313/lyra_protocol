/// The settlement kinds: how a sale was paid (`business.md`, `money.settlements`; `pos.md` POS-30).
///
/// A kind is what a sale is stored and reconciled as, the same word in every country
/// (`transfer`), not the rail a customer is offered (Pago Móvil, Zelle). It is the cloud's closed
/// vocabulary, snapshotted with the release, so a ticket charged on a master reads the same codes.
abstract final class Settlements {
  /// What the checkout assumes when the app has to pick one first (`default: true`).
  static const defaultMethod = "cash";

  /// Code → `(reference, change, credit, {language: name})`. `reference`: the app asks for the
  /// payment's number. `change`: money changes hands, so change can be computed. `credit`: the
  /// store's own tab, a promise and not money (not offered offline, POS-33).
  static const Map<String, (bool, bool, bool, Map<String, String>)> kinds = {
    "cash": (false, true, false, {
      "es": "Efectivo", "en": "Cash", "pt": "Dinheiro", "fr": "Espèces", "it": "Contanti", "de": "Bargeld",
    }),
    "card": (true, false, false, {
      "es": "Tarjeta", "en": "Card", "pt": "Cartão", "fr": "Carte", "it": "Carta", "de": "Karte",
    }),
    "debit": (true, false, false, {
      "es": "Débito", "en": "Debit", "pt": "Débito", "fr": "Débit", "it": "Debito", "de": "Debitkarte",
    }),
    "credit": (true, false, false, {
      "es": "Crédito", "en": "Credit", "pt": "Crédito", "fr": "Crédit", "it": "Credito", "de": "Kreditkarte",
    }),
    "transfer": (true, false, false, {
      "es": "Transferencia", "en": "Transfer", "pt": "Transferência", "fr": "Virement", "it": "Bonifico",
      "de": "Überweisung",
    }),
    "mobile": (true, false, false, {
      "es": "Pago móvil", "en": "Mobile payment", "pt": "Pagamento móvel", "fr": "Paiement mobile",
      "it": "Pagamento mobile", "de": "Mobile Zahlung",
    }),
    "wallet": (true, false, false, {
      "es": "Billetera digital", "en": "Digital wallet", "pt": "Carteira digital", "fr": "Portefeuille numérique",
      "it": "Portafoglio digitale", "de": "Digitale Geldbörse",
    }),
    "crypto": (true, false, false, {
      "es": "Criptomoneda", "en": "Cryptocurrency", "pt": "Criptomoeda", "fr": "Cryptomonnaie",
      "it": "Criptovaluta", "de": "Kryptowährung",
    }),
    "check": (true, false, false, {
      "es": "Cheque", "en": "Check", "pt": "Cheque", "fr": "Chèque", "it": "Assegno", "de": "Scheck",
    }),
    "account": (false, false, true, {
      "es": "Crédito de la tienda", "en": "Store credit", "pt": "Crédito da loja", "fr": "Crédit magasin",
      "it": "Credito del negozio", "de": "Ladenkredit",
    }),
    "other": (false, false, false, {
      "es": "Otro", "en": "Other", "pt": "Outro", "fr": "Autre", "it": "Altro", "de": "Sonstiges",
    }),
  };

  /// The kinds as the app's `PosPaymentMethod` reads them, named in [language] (English when it
  /// has none here). Without [credit], the kinds with `credit: true` are left out.
  static List<Map<String, Object?>> rows(String language, {bool credit = true}) => [
    for (final MapEntry(key: method, value: (reference, change, isCredit, names)) in kinds.entries)
      if (credit || !isCredit)
        {
          "method": method,
          "name": names[language] ?? names["en"],
          "reference": reference,
          "change": change,
          "credit": isCredit,
          "default": method == defaultMethod,
        },
  ];

  /// [method]'s name in [language], or null for a code this release doesn't know.
  static String? name(String method, String language) {
    final names = kinds[method]?.$4;

    return names == null ? null : names[language] ?? names["en"];
  }
}

/// The ticket's limits (`pos.md`).
abstract final class PosLimits {
  /// Units on one line (POS-16, `too_many_units`). The app's own guard is 999.
  static const maxUnits = 9999;

  /// A typed-in charge's concept (POS-14).
  static const maxConcept = 80;

  /// A payment's reference, as the cloud bounds it.
  static const maxReference = 64;

  /// A ticket's note at close.
  static const maxNote = 500;

  /// A page of the catalogue or of the open tickets (POS-4, POS-45).
  static const maxPage = 100;
}
