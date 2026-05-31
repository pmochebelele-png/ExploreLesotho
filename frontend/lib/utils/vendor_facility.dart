class VendorFacilityType {
  final String key;
  final String label;
  final String listingCategory;
  final List<String> businessTypes;

  const VendorFacilityType({
    required this.key,
    required this.label,
    required this.listingCategory,
    required this.businessTypes,
  });
}

class VendorFacilityTaxonomy {
  static const facilities = [
    VendorFacilityType(
      key: 'guest',
      label: 'Guest Facility',
      listingCategory: 'Accommodation',
      businessTypes: ['Guest House', 'Lodge', 'Hotel', 'Chalet', 'Homestay'],
    ),
    VendorFacilityType(
      key: 'tour',
      label: 'Tour Facility',
      listingCategory: 'Tour',
      businessTypes: ['Tour Operator', 'Travel Guide', 'Day Tour', 'Hiking Tour'],
    ),
    VendorFacilityType(
      key: 'culture',
      label: 'Culture Facility',
      listingCategory: 'Culture',
      businessTypes: ['Cultural Tours', 'Crafts', 'Museum', 'Heritage Site'],
    ),
    VendorFacilityType(
      key: 'adventure',
      label: 'Adventure Facility',
      listingCategory: 'Adventure',
      businessTypes: ['Adventure Sports', 'Pony Trekking', 'Hiking', 'Outdoor Activity'],
    ),
    VendorFacilityType(
      key: 'food',
      label: 'Food Facility',
      listingCategory: 'Restaurant',
      businessTypes: ['Restaurant', 'Cafe', 'Catering', 'Traditional Food'],
    ),
    VendorFacilityType(
      key: 'experience',
      label: 'Experience Facility',
      listingCategory: 'Experience',
      businessTypes: ['Experience Host', 'Workshop', 'Community Experience'],
    ),
    VendorFacilityType(
      key: 'transport',
      label: 'Transport Facility',
      listingCategory: 'Tour',
      businessTypes: ['Transport', 'Shuttle', 'Car Hire'],
    ),
  ];

  static List<String> get allBusinessTypes =>
      facilities.expand((facility) => facility.businessTypes).toSet().toList();

  static VendorFacilityType facilityForBusinessType(String? businessType) {
    final normalized = (businessType ?? '').trim().toLowerCase();
    for (final facility in facilities) {
      if (facility.businessTypes
          .any((type) => type.toLowerCase() == normalized)) {
        return facility;
      }
    }
    return facilities.first;
  }
}
