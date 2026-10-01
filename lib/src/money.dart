/// The money screen's vocabulary (`money.md`): what a payment recorded by hand was for.
///
/// It is the cloud's catalogue (`GET /money/catalog`, `concepts`), snapshotted with the release.
/// The concept decides the direction (M-1), so a payment never names one. The cloud names it in
/// Spanish only; the other languages are this snapshot's.
abstract final class MoneyConcepts {
  static const incoming = "in";
  static const outgoing = "out";

  /// Code → `(direction, ticket, settles, {language: name})`, in the cloud's order. `ticket`: the
  /// payment may name a sale (M-6). `settles`: it pays a credit ticket down (M-7), so it only
  /// exists where credit does.
  static const Map<String, (String, bool, bool, Map<String, String>)> kinds = {
    "settlement": (incoming, true, true, {
      "es": "Cobro de una venta a crédito", "en": "Credit sale collected", "pt": "Recebimento de venda a prazo",
      "fr": "Encaissement d'une vente à crédit", "it": "Incasso di una vendita a credito",
      "de": "Zahlungseingang für Kreditverkauf",
    }),
    "advance": (incoming, false, false, {
      "es": "Anticipo de un pedido", "en": "Order deposit", "pt": "Adiantamento de pedido",
      "fr": "Acompte sur commande", "it": "Acconto su un ordine", "de": "Anzahlung auf Bestellung",
    }),
    "supplier_refund": (incoming, false, false, {
      "es": "Devolución de un proveedor", "en": "Supplier refund", "pt": "Reembolso de fornecedor",
      "fr": "Remboursement fournisseur", "it": "Rimborso da un fornitore", "de": "Erstattung eines Lieferanten",
    }),
    "capital": (incoming, false, false, {
      "es": "Aporte de capital", "en": "Capital contribution", "pt": "Aporte de capital", "fr": "Apport en capital",
      "it": "Apporto di capitale", "de": "Kapitaleinlage",
    }),
    "loan": (incoming, false, false, {
      "es": "Préstamo recibido", "en": "Loan received", "pt": "Empréstimo recebido", "fr": "Prêt reçu",
      "it": "Prestito ricevuto", "de": "Erhaltenes Darlehen",
    }),
    "other_income": (incoming, false, false, {
      "es": "Otro ingreso", "en": "Other income", "pt": "Outra receita", "fr": "Autre recette",
      "it": "Altra entrata", "de": "Sonstige Einnahme",
    }),
    "supplier": (outgoing, false, false, {
      "es": "Pago a proveedor", "en": "Supplier payment", "pt": "Pagamento a fornecedor",
      "fr": "Paiement fournisseur", "it": "Pagamento a fornitore", "de": "Lieferantenzahlung",
    }),
    "salary": (outgoing, false, false, {
      "es": "Pago de personal", "en": "Staff payment", "pt": "Pagamento de pessoal", "fr": "Paiement du personnel",
      "it": "Pagamento del personale", "de": "Personalzahlung",
    }),
    "rent": (outgoing, false, false, {
      "es": "Alquiler", "en": "Rent", "pt": "Aluguel", "fr": "Loyer", "it": "Affitto", "de": "Miete",
    }),
    "services": (outgoing, false, false, {
      "es": "Servicios", "en": "Utilities", "pt": "Serviços", "fr": "Services", "it": "Utenze", "de": "Nebenkosten",
    }),
    "logistics": (outgoing, false, false, {
      "es": "Envíos y fletes", "en": "Shipping and freight", "pt": "Envios e fretes", "fr": "Envois et fret",
      "it": "Spedizioni e trasporti", "de": "Versand und Fracht",
    }),
    "maintenance": (outgoing, false, false, {
      "es": "Mantenimiento y reparaciones", "en": "Maintenance and repairs", "pt": "Manutenção e reparos",
      "fr": "Entretien et réparations", "it": "Manutenzione e riparazioni", "de": "Wartung und Reparaturen",
    }),
    "marketing": (outgoing, false, false, {
      "es": "Publicidad", "en": "Advertising", "pt": "Publicidade", "fr": "Publicité", "it": "Pubblicità",
      "de": "Werbung",
    }),
    "fees": (outgoing, false, false, {
      "es": "Comisiones y cargos bancarios", "en": "Bank fees and charges", "pt": "Comissões e tarifas bancárias",
      "fr": "Commissions et frais bancaires", "it": "Commissioni e spese bancarie", "de": "Bankgebühren und Provisionen",
    }),
    "taxes": (outgoing, false, false, {
      "es": "Impuestos y tasas", "en": "Taxes and duties", "pt": "Impostos e taxas", "fr": "Impôts et taxes",
      "it": "Imposte e tasse", "de": "Steuern und Abgaben",
    }),
    "customer_refund": (outgoing, true, false, {
      "es": "Devolución a un cliente", "en": "Customer refund", "pt": "Reembolso a cliente",
      "fr": "Remboursement client", "it": "Rimborso a un cliente", "de": "Erstattung an einen Kunden",
    }),
    "withdrawal": (outgoing, false, false, {
      "es": "Retiro del dueño", "en": "Owner's withdrawal", "pt": "Retirada do dono", "fr": "Prélèvement du gérant",
      "it": "Prelievo del titolare", "de": "Privatentnahme",
    }),
    "loan_payment": (outgoing, false, false, {
      "es": "Pago de un préstamo", "en": "Loan repayment", "pt": "Pagamento de empréstimo",
      "fr": "Remboursement d'un prêt", "it": "Rimborso di un prestito", "de": "Darlehenstilgung",
    }),
    "other_expense": (outgoing, false, false, {
      "es": "Otro egreso", "en": "Other expense", "pt": "Outra despesa", "fr": "Autre dépense", "it": "Altra uscita",
      "de": "Sonstige Ausgabe",
    }),
  };

  /// The concepts as the app's `MoneyConcept` reads them, named in [language] (English when it has
  /// none here), only [direction]'s when given. Without [credit], the ones that settle a credit
  /// ticket are left out: there is nothing for them to settle.
  static List<Map<String, Object?>> rows(String language, {String? direction, bool credit = true}) => [
    for (final MapEntry(key: concept, value: (way, ticket, settles, names)) in kinds.entries)
      if ((direction == null || direction == way) && (credit || !settles))
        {
          "concept": concept,
          "name": names[language] ?? names["en"],
          "direction": way,
          "ticket": ticket,
          "settles": settles,
        },
  ];

  /// [concept]'s name in [language], or null for a code this release doesn't know.
  static String? name(String concept, String language) {
    final names = kinds[concept]?.$4;

    return names == null ? null : names[language] ?? names["en"];
  }
}

/// The limits of a payment recorded by hand (`money.md`), as the cloud bounds them.
abstract final class MoneyLimits {
  /// A page of the payments or the receivables (M-10).
  static const maxPage = 100;

  /// A payment's reference, as a ticket's (`PosLimits.maxReference`).
  static const maxReference = 64;

  /// Each half of the counterpart (`name`, `contact`).
  static const maxCounterpart = 120;

  static const maxNote = 280;

  /// A void's reason.
  static const maxReason = 160;

  /// How far ahead of the master's clock a payment's date may be (M-3): a device whose clock runs
  /// a little fast still records "now".
  static const futureSkew = Duration(minutes: 5);
}
