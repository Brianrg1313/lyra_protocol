/// The vocabulary of `employees.md`: the keys `employees.edit` and `profile.edit` take (the
/// cloud's request keys, which the app's screens already send, E-12) and the closed lists their
/// values come from (the app's `Employee*` enums).
abstract final class EmployeeFields {
  /// The job, in clear: the card and the list show them.
  static const Set<String> job = {
    "JOB_TITLE", "DEPARTMENT", "EMPLOYEE_CODE", "BRANCH_ID", "MANAGER_ID", "CONTRACT", "WORKDAY",
    "START_DATE", "END_DATE", "WORK_EMAIL", "WORK_PHONE",
  };

  /// The job's sealed keys (scope `hr`, plan §6.3). `NOTES` is the company's and never reaches
  /// the person.
  static const Set<String> pay = {"SALARY", "SALARY_CURRENCY", "PAY_PERIOD", "NOTES"};

  /// The person's names, in clear: they are the card.
  static const Set<String> names = {"FIRST_NAME", "LAST_NAME"};

  /// The person's private profile, sealed (scope `hr` and the person's own key).
  static const Set<String> private = {
    "PHONE", "SEX", "BIRTHDAY", "ABOUT", "DOCUMENT_TYPE", "DOCUMENT_NUMBER", "NATIONALITY", "COUNTRY",
    "ADDRESS", "CITY", "REGION", "POSTAL_CODE", "EMERGENCY_NAME", "EMERGENCY_PHONE", "EMERGENCY_RELATION",
  };

  /// Every key whose value is sealed: kept out of a write's ledger hash (`OpRule.sealedArgs`).
  static const Set<String> sealed = {...pay, ...private};

  static const List<String> states = ["invited", "active", "ended", "declined", "cancelled"];
  static const List<String> contracts = ["permanent", "fixed_term", "probation", "internship", "freelance", "temporary"];
  static const List<String> workdays = ["full_time", "part_time", "hourly", "shifts"];
  static const List<String> payPeriods = ["hour", "day", "week", "fortnight", "month", "year"];
  static const List<String> documents = ["national_id", "passport", "foreign_id", "tax_id"];
  static const List<String> sexes = ["female", "male", "other"];
}
