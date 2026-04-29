// lib/widgets/listing_card.dart
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/listing.dart';
import '../services/location_service.dart';
import '../providers/wishlist_provider.dart';
import '../services/social_service.dart';

class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;
  static final LocationService _locationService = LocationService();

  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final wishlistProvider =
        Provider.of<WishlistProvider>(context, listen: false);
    final isInWishlist = wishlistProvider.isInWishlist(listing.id.toString());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(isInWishlist, context, wishlistProvider),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleAndCategory(),
                  const SizedBox(height: 4),
                  _buildLocation(),
                  const SizedBox(height: 8),
                  _buildLocationChips(context),
                  if (_hasSocialQuickActions()) ...[
                    const SizedBox(height: 8),
                    _buildSocialQuickActions(context),
                  ],
                  const SizedBox(height: 8),
                  _buildPriceAndRating(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(bool isInWishlist, BuildContext context,
      WishlistProvider wishlistProvider) {
    final Map<String, Color> categoryColors = {
      'Accommodation': Colors.blue,
      'Experience': Colors.orange,
      'Culture': Colors.purple,
      'Adventure': Colors.red,
      'Restaurant': Colors.green,
      'Tour': Colors.teal,
    };

    final categoryColor = categoryColors[listing.category] ?? Colors.green;

    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withValues(alpha: 0.3),
            categoryColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (listing.imageUrl != null && listing.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: _buildListingImage(categoryColor),
            )
          else
            _buildPlaceholderIcon(categoryColor),

          // Featured Badge
          if (listing.isFeatured)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Featured',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Unavailable Badge
          if (!listing.isAvailable)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Unavailable',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Wishlist Heart Button
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  isInWishlist ? Icons.favorite : Icons.favorite_border,
                  color: isInWishlist ? Colors.red : Colors.grey[600],
                  size: 20,
                ),
                onPressed: () async {
                  if (isInWishlist) {
                    await wishlistProvider
                        .removeFromWishlist(listing.id.toString());
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Removed from wishlist'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  } else {
                    await wishlistProvider.addToWishlist(listing);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Added to wishlist'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  }
                },
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingImage(Color categoryColor) {
    final imageUrl = listing.imageUrl!;
    if (imageUrl.startsWith('data:image')) {
      final parts = imageUrl.split(',');
      if (parts.length == 2) {
        return Image.memory(
          base64Decode(parts[1]),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderIcon(categoryColor),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(
        child: CircularProgressIndicator(color: categoryColor),
      ),
      errorWidget: (context, url, error) {
        return _buildPlaceholderIcon(categoryColor);
      },
    );
  }

  Widget _buildPlaceholderIcon(Color categoryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCategoryIcon(listing.category),
            size: 48,
            color: categoryColor,
          ),
          const SizedBox(height: 8),
          Text(
            listing.category,
            style: TextStyle(
              color: categoryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Accommodation':
        return Icons.hotel;
      case 'Experience':
        return Icons.explore;
      case 'Culture':
        return Icons.museum;
      case 'Adventure':
        return Icons.downhill_skiing;
      case 'Restaurant':
        return Icons.restaurant;
      case 'Tour':
        return Icons.tour;
      default:
        return Icons.place;
    }
  }

  Widget _buildTitleAndCategory() {
    final cultureType = listing.cultureType;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            listing.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            listing.category,
            style: TextStyle(
              fontSize: 9,
              color: Colors.green.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (cultureType != null && cultureType.isNotEmpty) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              cultureType,
              style: TextStyle(
                fontSize: 9,
                color: Colors.purple.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: 12,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _formatLocation(),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationChips(BuildContext context) {
    final chips = <Widget>[
      _buildInfoChip(
        icon: Icons.public,
        label: listing.district?.trim().isNotEmpty == true
            ? listing.district!
            : 'Lesotho',
        background: Colors.green.shade50,
        foreground: Colors.green.shade800,
      ),
      _buildInfoChip(
        icon: listing.hasCoordinates ? Icons.my_location : Icons.place_outlined,
        label: listing.hasCoordinates ? 'Map Ready' : 'Location Set',
        background: listing.hasCoordinates
            ? Colors.blue.shade50
            : Colors.orange.shade50,
        foreground: listing.hasCoordinates
            ? Colors.blue.shade800
            : Colors.orange.shade800,
      ),
    ];

    if (listing.hasCoordinates || listing.location.trim().isNotEmpty) {
      chips.add(
        _buildActionPill(
          context: context,
          icon: Icons.map_outlined,
          label: 'Map',
          background: Colors.black.withValues(alpha: 0.05),
          foreground: Colors.black87,
          onTap: () => _locationService.openInGoogleMaps(
            latitude: listing.latitude,
            longitude: listing.longitude,
            query: _formatLocation(),
          ),
          errorMessage: 'Could not open the map',
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
    required Future<void> Function() onTap,
    required String errorMessage,
  }) {
    return InkWell(
      onTap: () async {
        try {
          await onTap();
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: foreground.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLocation() {
    if (listing.district != null && listing.district!.isNotEmpty) {
      if (listing.location.isNotEmpty) {
        return '${listing.location}, ${listing.district}';
      }
      return listing.district!;
    }
    return listing.location.isNotEmpty
        ? listing.location
        : 'Location not specified';
  }

  Widget _buildPriceAndRating(BuildContext context) {
    return Row(
      children: [
        // Price section
        Expanded(
          flex: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                listing.formattedPrice,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 2),
              Text(
                listing.priceUnit ?? '/night',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Rating section
        if (listing.rating != null && listing.rating! > 0)
          Expanded(
            flex: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.star, size: 12, color: Colors.amber.shade700),
                const SizedBox(width: 2),
                Text(
                  listing.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (listing.reviewCount != null &&
                    listing.reviewCount! > 0) ...[
                  const SizedBox(width: 2),
                  Text(
                    '(${listing.reviewCount})',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

        // Spacer to push content
        const Spacer(),
      ],
    );
  }

  bool _hasSocialQuickActions() {
    return (listing.vendorWhatsapp?.trim().isNotEmpty ?? false) ||
        (listing.vendorFacebook?.trim().isNotEmpty ?? false) ||
        (listing.vendorInstagram?.trim().isNotEmpty ?? false) ||
        (listing.vendorPhone?.trim().isNotEmpty ?? false) ||
        (listing.vendorEmail?.trim().isNotEmpty ?? false);
  }

  Widget _buildSocialQuickActions(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (listing.vendorWhatsapp?.trim().isNotEmpty ?? false)
          _buildActionChip(
            context: context,
            icon: Icons.chat,
            color: Colors.green.shade700,
            onTap: () => SocialService.launchWhatsApp(listing.vendorWhatsapp!),
            errorMessage: 'Could not open WhatsApp',
          ),
        if (listing.vendorFacebook?.trim().isNotEmpty ?? false)
          _buildActionChip(
            context: context,
            icon: Icons.facebook,
            color: Colors.blue.shade700,
            onTap: () => SocialService.launchFacebook(listing.vendorFacebook!),
            errorMessage: 'Could not open Facebook',
          ),
        if (listing.vendorInstagram?.trim().isNotEmpty ?? false)
          _buildActionChip(
            context: context,
            icon: Icons.camera_alt,
            color: Colors.pink.shade700,
            onTap: () =>
                SocialService.launchInstagram(listing.vendorInstagram!),
            errorMessage: 'Could not open Instagram',
          ),
        if (listing.vendorPhone?.trim().isNotEmpty ?? false)
          _buildActionChip(
            context: context,
            icon: Icons.call,
            color: Colors.teal.shade700,
            onTap: () => SocialService.callPhone(listing.vendorPhone!),
            errorMessage: 'Could not open dialer',
          ),
        if (listing.vendorEmail?.trim().isNotEmpty ?? false)
          _buildActionChip(
            context: context,
            icon: Icons.email,
            color: Colors.deepOrange.shade700,
            onTap: () => SocialService.sendEmail(listing.vendorEmail!),
            errorMessage: 'Could not open email app',
          ),
      ],
    );
  }

  Widget _buildActionChip({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required Future<void> Function() onTap,
    required String errorMessage,
  }) {
    return InkWell(
      onTap: () async {
        try {
          await onTap();
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
