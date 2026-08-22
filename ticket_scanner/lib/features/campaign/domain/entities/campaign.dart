/// Campagne (bannière) pilotée depuis le dashboard admin.
class Campaign {
  const Campaign({
    required this.title,
    this.subtitle,
    this.url,
    this.backgroundColorHex,
    this.imageUrl,
    this.sortOrder = 0,
    this.active = true,
  });

  final String title;
  final String? subtitle;
  final String? url;

  /// Image optionnelle (logo/visuel) — URL Firebase Storage.
  final String? imageUrl;

  /// Couleur de fond au format '#RRGGBB' (défaut : vert PharmaScan).
  final String? backgroundColorHex;

  /// Ordre d'affichage (défini dans le dashboard).
  final int sortOrder;

  /// Toujours true côté app : le repository filtre déjà les inactives.
  final bool active;

  bool get hasUrl => url != null && url!.isNotEmpty;

  /// Convertit '#RRGGBB' en Color Flutter (défaut vert PharmaScan #0E7A5F).
  int get backgroundColorValue {
    var h = (backgroundColorHex ?? '#0E7A5F').replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return 0xFF0E7A5F;
    return int.tryParse(h, radix: 16) ?? 0xFF0E7A5F;
  }
}
