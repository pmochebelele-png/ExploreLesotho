// lib/data/models/listing.dart
class Listing {
  final String id;
  final String title;
  final String description;
  final double price;
  final String location;
  final String category;

  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.category,
  });
}