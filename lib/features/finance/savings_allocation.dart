/// Une poche d'épargne pour le calcul de répartition.
class Pocket {
  Pocket({
    required this.id,
    required this.name,
    required this.weight,
    this.remaining,
  });
  final int id;
  final String name;
  final int weight;

  /// Montant restant avant d'atteindre l'objectif ; null = poche sans
  /// objectif (jamais plafonnée). <= 0 signifie objectif déjà atteint.
  final double? remaining;
}

/// Répartit [capacity] € entre les poches selon leur poids, en plafonnant
/// chaque poche à son objectif restant et en redistribuant le surplus aux
/// autres. Renvoie le montant alloué par id de poche.
///
/// Algo « poids + stop à l'objectif » :
///  - une poche dont l'objectif est atteint (remaining <= 0) reçoit 0 ;
///  - sinon on répartit au prorata des poids ;
///  - si une poche à objectif dépasse son restant, on la plafonne et on
///    redistribue le surplus aux poches non plafonnées, en itérant.
Map<int, double> allocateSavings(double capacity, List<Pocket> pockets) {
  final result = {for (final p in pockets) p.id: 0.0};
  if (capacity <= 0) return result;

  // Poches éligibles : pas d'objectif, ou objectif non encore atteint.
  final active = pockets
      .where((p) => p.weight > 0 && (p.remaining == null || p.remaining! > 0))
      .toList();
  if (active.isEmpty) return result;

  final capped = <int>{}; // poches plafonnées à leur objectif
  var pool = capacity;

  // On itère : tant qu'il reste du budget et des poches non plafonnées.
  for (var guard = 0; guard < 100; guard++) {
    final open = active.where((p) => !capped.contains(p.id)).toList();
    if (open.isEmpty || pool <= 0.005) break;

    final totalWeight = open.fold<int>(0, (s, p) => s + p.weight);
    if (totalWeight == 0) break;

    var newlyCapped = false;
    var distributed = 0.0;

    for (final p in open) {
      var share = pool * p.weight / totalWeight;
      // Plafonnement à l'objectif restant.
      if (p.remaining != null) {
        final room = p.remaining! - result[p.id]!;
        if (share >= room) {
          share = room;
          capped.add(p.id);
          newlyCapped = true;
        }
      }
      result[p.id] = result[p.id]! + share;
      distributed += share;
    }

    pool -= distributed;
    // Si rien n'a été plafonné, la répartition proportionnelle est stable.
    if (!newlyCapped) break;
  }

  // Arrondi à 2 décimales.
  return {
    for (final e in result.entries)
      e.key: (e.value * 100).roundToDouble() / 100,
  };
}
