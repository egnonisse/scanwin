/// Médicament du référentiel (base ANSM) — peut ne pas avoir de prix.
class Medication {
  const Medication({
    required this.name,
    this.form,
    this.routes,
    this.titulaire,
    this.dcis = const [],
  });

  /// Dénomination complète (nom + dosage + forme), ex :
  /// « PARACÉTAMOL 500 mg, comprimé ».
  final String name;

  final String? form;
  final String? routes;

  /// Laboratoire titulaire de l'AMM.
  final String? titulaire;

  /// Substances actives (DCI).
  final List<String> dcis;

  String get dciLabel => dcis.isEmpty ? '' : dcis.join(', ');
}
