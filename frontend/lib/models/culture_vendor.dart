class CultureVendor {
  final String id;
  final String name;
  final String productRange;
  final String location;
  final List<String> contacts;
  final List<String> subcategories;
  final List<String> subcategorySlugs;
  final String? linkedListingId;
  final String? linkedVendorId;
  final String? linkedVendorUserId;
  final String? claimedAt;
  final bool isClaimed;
  final String? sourceDocument;

  const CultureVendor({
    required this.id,
    required this.name,
    required this.productRange,
    required this.location,
    required this.contacts,
    required this.subcategories,
    required this.subcategorySlugs,
    this.linkedListingId,
    this.linkedVendorId,
    this.linkedVendorUserId,
    this.claimedAt,
    this.isClaimed = false,
    this.sourceDocument,
  });

  factory CultureVendor.fromJson(Map<String, dynamic> json) {
    List<String> parseContacts(dynamic value) {
      if (value == null) return const [];
      if (value is List) {
        return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
      }
      if (value is Map) {
        return value.values
            .map((item) => item?.toString() ?? '')
            .where((item) => item.trim().isNotEmpty)
            .toList();
      }
      return value.toString().trim().isEmpty ? const [] : [value.toString()];
    }

    return CultureVendor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      productRange: json['productRange']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      contacts: parseContacts(json['contacts']),
      subcategories: (json['subcategories'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      subcategorySlugs: (json['subcategorySlugs'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      linkedListingId: json['linkedListingId']?.toString(),
      linkedVendorId: json['linkedVendorId']?.toString(),
      linkedVendorUserId: json['linkedVendorUserId']?.toString(),
      claimedAt: json['claimedAt']?.toString(),
      isClaimed: json['isClaimed'] == true,
      sourceDocument: json['sourceDocument']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'productRange': productRange,
      'location': location,
      'contacts': contacts,
      'subcategories': subcategories,
      'subcategorySlugs': subcategorySlugs,
      'linkedListingId': linkedListingId,
      'linkedVendorId': linkedVendorId,
      'linkedVendorUserId': linkedVendorUserId,
      'claimedAt': claimedAt,
      'isClaimed': isClaimed,
      'sourceDocument': sourceDocument,
    };
  }
}
