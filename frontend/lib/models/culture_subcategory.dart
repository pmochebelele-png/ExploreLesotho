class CultureSubcategory {
  final String id;
  final String name;
  final String slug;
  final String? icon;
  final String? color;
  final int vendorCount;

  const CultureSubcategory({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.color,
    required this.vendorCount,
  });

  factory CultureSubcategory.fromJson(Map<String, dynamic> json) {
    return CultureSubcategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
      vendorCount: int.tryParse(json['vendorCount']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'icon': icon,
      'color': color,
      'vendorCount': vendorCount,
    };
  }
}
