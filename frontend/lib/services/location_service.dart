import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/listing.dart';

class LocationService {
  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  double calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
          startLatitude,
          startLongitude,
          endLatitude,
          endLongitude,
        ) /
        1000;
  }

  String formatDistanceKm(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String buildStaticMapPreviewUrl({
    required double latitude,
    required double longitude,
    int width = 600,
    int height = 320,
    int zoom = 13,
  }) {
    return 'https://staticmap.openstreetmap.de/staticmap.php?center=$latitude,$longitude&zoom=$zoom&size=${width}x$height&maptype=mapnik&markers=$latitude,$longitude,red-pushpin';
  }

  Future<void> openInGoogleMaps({
    double? latitude,
    double? longitude,
    String? query,
  }) async {
    Uri uri;
    if (latitude != null && longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query ?? '')}',
      );
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open Google Maps');
    }
  }

  Future<void> openDirections({
    double? originLatitude,
    double? originLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationQuery,
  }) async {
    final destination = (destinationLatitude != null && destinationLongitude != null)
        ? '$destinationLatitude,$destinationLongitude'
        : Uri.encodeComponent(destinationQuery ?? '');

    final hasOrigin = originLatitude != null && originLongitude != null;
    final uri = hasOrigin
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1&origin=$originLatitude,$originLongitude&destination=$destination&travelmode=driving',
          )
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
          );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open directions');
    }
  }

  List<Listing> getNearbyListings({
    required Listing currentListing,
    required List<Listing> allListings,
    int limit = 4,
  }) {
    final others = allListings.where((item) => item.id != currentListing.id);

    if (currentListing.hasCoordinates) {
      final ranked = others
          .where((item) => item.hasCoordinates)
          .map((item) {
            final distance = calculateDistanceKm(
              startLatitude: currentListing.latitude!,
              startLongitude: currentListing.longitude!,
              endLatitude: item.latitude!,
              endLongitude: item.longitude!,
            );
            return MapEntry(item, distance);
          })
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      return ranked.take(limit).map((entry) => entry.key).toList();
    }

    final districtMatches = others
        .where(
          (item) =>
              (item.district?.trim().isNotEmpty ?? false) &&
              item.district?.trim().toLowerCase() ==
                  currentListing.district?.trim().toLowerCase(),
        )
        .toList();

    if (districtMatches.isNotEmpty) {
      return districtMatches.take(limit).toList();
    }

    final categoryMatches = others
        .where(
          (item) =>
              item.category.trim().toLowerCase() ==
              currentListing.category.trim().toLowerCase(),
        )
        .toList();

    return categoryMatches.take(limit).toList();
  }

  double calculateNorthSouthHint(Listing origin, Listing target) {
    if (!origin.hasCoordinates || !target.hasCoordinates) return 0;
    return target.latitude! - origin.latitude!;
  }

  double calculateEastWestHint(Listing origin, Listing target) {
    if (!origin.hasCoordinates || !target.hasCoordinates) return 0;
    return target.longitude! - origin.longitude!;
  }

  String describeRelativePosition(Listing origin, Listing target) {
    if (!origin.hasCoordinates || !target.hasCoordinates) {
      return target.district?.trim().isNotEmpty == true
          ? target.district!
          : target.location;
    }

    final northSouth = calculateNorthSouthHint(origin, target);
    final eastWest = calculateEastWestHint(origin, target);

    final vertical = northSouth.abs() < 0.02
        ? ''
        : northSouth > 0
            ? 'north'
            : 'south';
    final horizontal = eastWest.abs() < 0.02
        ? ''
        : eastWest > 0
            ? 'east'
            : 'west';

    if (vertical.isEmpty && horizontal.isEmpty) return 'nearby';
    if (vertical.isNotEmpty && horizontal.isNotEmpty) {
      return '$vertical-$horizontal';
    }
    return vertical.isNotEmpty ? vertical : horizontal;
  }
}
