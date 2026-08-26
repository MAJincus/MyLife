/// Devine le nom de catégorie d'une transaction à partir de son libellé,
/// via des mots-clés de marchands/opérations courants en France.
class Categorizer {
  Categorizer._();

  // Nom de catégorie MyLife -> mots-clés (en minuscules).
  static const _rules = <String, List<String>>{
    'Alimentation': [
      'carrefour', 'leclerc', 'auchan', 'lidl', 'aldi', 'monoprix',
      'franprix', 'intermarche', 'intermarché', 'casino', 'super u',
      'superu', 'hyper u', 'cora', 'g20', 'naturalia', 'biocoop',
      'boulangerie', 'boucherie', 'restaurant', 'mcdo', 'mcdonald',
      'burger', 'kfc', 'uber eats', 'deliveroo', 'just eat', 'sushi',
      'pizza', 'brasserie', 'cafe', 'café', 'starbucks',
    ],
    'Transport': [
      'sncf', 'ratp', 'navigo', 'uber', 'bolt', 'total', 'totalenergies',
      'esso', 'shell', 'bp ', 'station', 'essence', 'carburant', 'autoroute',
      'vinci', 'sanef', 'aprr', 'parking', 'blablacar', 'ouigo', 'trainline',
      'peage', 'péage', 'velib', 'lime', 'taxi',
    ],
    'Logement': [
      'loyer', 'edf', 'engie', 'total energie', 'veolia', 'suez',
      'saur', 'gaz', 'electricite', 'électricité', 'eau', 'syndic',
      'assurance habitation', 'foncia',
    ],
    'Abonnements': [
      'netflix', 'spotify', 'deezer', 'canal', 'disney', 'amazon prime',
      'prime video', 'apple.com', 'apple com', 'itunes', 'google', 'youtube',
      'free ', 'free mobile', 'sfr', 'orange', 'bouygues', 'sosh', 'red by sfr',
      'microsoft', 'adobe', 'openai', 'anthropic', 'audible',
    ],
    'Santé': [
      'pharmacie', 'pharma', 'docteur', 'medecin', 'médecin', 'mutuelle',
      'hopital', 'hôpital', 'clinique', 'laboratoire', 'labo', 'dentaire',
      'dentiste', 'opticien', 'optique', 'kine', 'kiné', 'ameli', 'cpam',
    ],
    'Loisirs': [
      'fnac', 'cultura', 'cinema', 'cinéma', 'pathe', 'gaumont', 'ugc',
      'steam', 'playstation', 'xbox', 'nintendo', 'decathlon', 'basic fit',
      'basic-fit', 'fitness', 'salle de sport', 'spotify', 'concert',
      'theatre', 'théâtre', 'musee', 'musée', 'amazon',
    ],
    'Salaire': [
      'salaire', 'paie', 'paye', 'remuneration', 'rémunération', 'traitement',
    ],
  };

  /// Renvoie le nom de catégorie deviné, ou null si aucun mot-clé ne matche.
  static String? guess(String label) {
    final l = label.toLowerCase();
    for (final entry in _rules.entries) {
      for (final kw in entry.value) {
        if (l.contains(kw)) return entry.key;
      }
    }
    return null;
  }
}
