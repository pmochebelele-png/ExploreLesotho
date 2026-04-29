// lib/screens/home/listing_detail_screen.dart
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/review.dart';
import '../../models/listing.dart';
import '../../providers/listing_provider.dart';
import '../../providers/review_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/location_service.dart';
import '../../services/social_service.dart';
import '../../widgets/review_card.dart';
import '../../widgets/social_media_buttons.dart';
import '../../core/themes/color_palette.dart';
import '../../widgets/custom_button.dart';
import '../bookings/booking_screen.dart';
import '../chat/new_message_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final LocationService _locationService = LocationService();
  double? _userLatitude;
  double? _userLongitude;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    reviewProvider.fetchReviewsForListing(
      widget.listingId,
      forceRefresh: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocationContext();
    });
  }

  Future<void> _loadLocationContext() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _userLatitude = position?.latitude;
      _userLongitude = position?.longitude;
      _isLoadingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    final listingProvider = Provider.of<ListingProvider>(context);

    final listing = listingProvider.getListingById(widget.listingId);

    if (listing == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
              locale.translate('Listing Details', 'Lintlha Tse Felletseng')),
          backgroundColor: ColorPalette.primaryGreen,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
              locale.translate('Listing not found', 'Lintlha ha li fumanehe')),
        ),
      );
    }

    final hasContactInfo = (listing.vendorPhone?.trim().isNotEmpty ?? false) ||
        (listing.vendorEmail?.trim().isNotEmpty ?? false) ||
        (listing.vendorWebsite?.trim().isNotEmpty ?? false) ||
        (listing.vendorFacebook?.trim().isNotEmpty ?? false) ||
        (listing.vendorInstagram?.trim().isNotEmpty ?? false) ||
        (listing.vendorWhatsapp?.trim().isNotEmpty ?? false);
    final hasBookingHost = (listing.vendorId?.trim().isNotEmpty ?? false) &&
        (listing.vendorName?.trim().isNotEmpty ?? false);
    final portfolioImages = _collectPortfolioImages(listing);
    final videoLinks = _collectVideoLinks(listing);
    final userDistanceKm = (listing.hasCoordinates &&
            _userLatitude != null &&
            _userLongitude != null)
        ? _locationService.calculateDistanceKm(
            startLatitude: _userLatitude!,
            startLongitude: _userLongitude!,
            endLatitude: listing.latitude!,
            endLongitude: listing.longitude!,
          )
        : null;
    final nearbyListings = _locationService.getNearbyListings(
      currentListing: listing,
      allListings: listingProvider.allListings,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: ColorPalette.primaryGreen,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(listing.title),
              background: Container(
                color: ColorPalette.primaryGreen.withValues(alpha: 0.3),
                child: listing.imageUrl != null && listing.imageUrl!.isNotEmpty
                    ? _buildListingImage(listing.imageUrl!)
                    : const Center(
                        child: Icon(Icons.image, size: 64, color: Colors.white),
                      ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        listing.location +
                            (listing.district != null
                                ? ', ${listing.district}'
                                : ''),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLocationServicesCard(
                  listing: listing,
                  locale: locale,
                  userDistanceKm: userDistanceKm,
                  nearbyListings: nearbyListings,
                ),
                const SizedBox(height: 16),
                // Host info
                if (listing.vendorName != null)
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.grey[600], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Hosted by ${listing.vendorName}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                // Price
                Row(
                  children: [
                    Text(
                      listing.formattedPrice,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ColorPalette.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      listing.priceUnit ?? '/night',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Rating
                if (listing.rating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        listing.rating!.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (listing.reviewCount != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${listing.reviewCount} reviews)',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 24),
                if (portfolioImages.isNotEmpty || videoLinks.isNotEmpty) ...[
                  Text(
                    locale.translate('Portfolio', 'Pokello ya Mesebetsi'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (portfolioImages.isNotEmpty)
                    SizedBox(
                      height: 210,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: portfolioImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final image = portfolioImages[index];
                          return InkWell(
                            onTap: () => _showImagePreview(image),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 250,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.grey[100],
                              ),
                              child: _buildListingImage(image),
                            ),
                          );
                        },
                      ),
                    ),
                  if (videoLinks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(videoLinks.length, (index) {
                        final link = videoLinks[index];
                        return ActionChip(
                          avatar: const Icon(Icons.play_circle_fill, size: 18),
                          label: Text('Video ${index + 1}'),
                          onPressed: () async {
                            try {
                              await SocialService.launchWebsite(link);
                            } catch (_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Could not open this video link'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],

                // Description
                Text(
                  locale.translate('Description', 'Tlhaloso'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  listing.description,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 24),

                // ========== CONTACT & SOCIAL MEDIA SECTION ==========
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.translate(
                              'Contact Host', 'Ikopanye le Moamoheli'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (hasContactInfo)
                          SocialMediaButtons(
                            whatsapp:
                                listing.vendorWhatsapp ?? listing.vendorPhone,
                            phone: listing.vendorPhone,
                            email: listing.vendorEmail,
                            website: listing.vendorWebsite,
                            facebook: listing.vendorFacebook,
                            instagram: listing.vendorInstagram,
                            iconSize: 24,
                          )
                        else
                          Text(
                            locale.translate(
                              'Host contact details are not available yet.',
                              'Lintlha tsa ho ikopanya le moamoheli ha li eo hajoale.',
                            ),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (hasBookingHost) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final started = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NewMessageScreen(
                            title: locale.translate(
                              'Message Host',
                              'Romela molaetsa ho moamoheli',
                            ),
                            allowedRoles: const {'vendor'},
                            initialRecipientId: listing.vendorId!,
                            initialRecipientName: listing.vendorName!,
                            initialListingId: listing.id,
                            lockRecipient: true,
                          ),
                        ),
                      );
                      if (started == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              locale.translate(
                                'Conversation started with the host.',
                                'Puisano e qalile le moamoheli.',
                              ),
                            ),
                            backgroundColor: ColorPalette.primaryGreen,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(
                      locale.translate('Message Host', 'Romela molaetsa'),
                    ),
                  ),
                ],
                // ========== END CONTACT & SOCIAL MEDIA SECTION ==========

                const SizedBox(height: 24),

                // ========== REVIEWS SECTION ==========
                Text(
                  locale.translate('Reviews', 'Maikutlo'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Consumer<ReviewProvider>(
                  builder: (context, reviewProvider, child) {
                    final reviews =
                        reviewProvider.getReviewsForListing(widget.listingId);
                    final averageRating = reviewProvider
                        .getAverageRatingForListing(widget.listingId);
                    final reviewCount = reviews.length;

                    if (reviewCount == 0) {
                      return _buildEmptyReviews();
                    }

                    return Column(
                      children: [
                        // Rating Summary Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        averageRating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(5, (index) {
                                          return Icon(
                                            index < averageRating
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 16,
                                            color: Colors.amber[700],
                                          );
                                        }),
                                      ),
                                      Text(
                                        '$reviewCount review${reviewCount > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 60,
                                  color: Colors.grey[300],
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildRatingBar(5, reviews),
                                      _buildRatingBar(4, reviews),
                                      _buildRatingBar(3, reviews),
                                      _buildRatingBar(2, reviews),
                                      _buildRatingBar(1, reviews),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Reviews List
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            return ReviewCard(
                              review: review,
                              onHelpful: () =>
                                  reviewProvider.markHelpful(review.id),
                              onReport: () => _showReportDialog(review),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                // ========== END REVIEWS SECTION ==========

                const SizedBox(height: 32),
                // Book button
                CustomButton(
                  onPressed: () {
                    if (!hasBookingHost) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            locale.translate(
                              'This listing is missing host booking details.',
                              'Lintlha tsa ho behela ho moamoheli ha lia phethahala.',
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingScreen(
                          listingId: listing.id,
                          listingTitle: listing.title,
                          vendorId: listing.vendorId!,
                          vendorName: listing.vendorName!,
                          pricePerNight: listing.price,
                          listingCategory: listing.category,
                          priceUnit: listing.priceUnit,
                          additionalDetails: listing.additionalDetails,
                        ),
                      ),
                    );
                  },
                  text: hasBookingHost
                      ? locale.translate('Book Now', 'Behla Hona Joale')
                      : locale.translate(
                          'Booking Unavailable', 'Ho Buka Ha ho Fumanehe'),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationServicesCard({
    required Listing listing,
    required LocaleProvider locale,
    required double? userDistanceKm,
    required List<Listing> nearbyListings,
  }) {
    final hasLiveDistance = userDistanceKm != null;
    final locationQuery = [
      listing.title,
      listing.location,
      if (listing.district?.trim().isNotEmpty ?? false) listing.district,
      'Lesotho',
    ].whereType<String>().join(', ');

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPlacePreviewPanel(
              listing: listing,
              locale: locale,
              userDistanceKm: userDistanceKm,
              nearbyCount: nearbyListings.length,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorPalette.primaryGreen.withValues(alpha: 0.95),
                    ColorPalette.secondaryGreen.withValues(alpha: 0.88),
                    Colors.white.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.explore,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.translate(
                            'Location Services',
                            'Ditshebeletso tsa Sebaka',
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          locale.translate(
                            'Open maps, calculate distance, and discover nearby places around this destination.',
                            'Bula dimmapa, bala bohole, mme o fumane dibaka tse haufi le sebaka sena.',
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildLocationStatChip(
                  icon: Icons.place_outlined,
                  label: listing.location,
                  background: Colors.green.shade50,
                  foreground: Colors.green.shade800,
                ),
                if (listing.district?.trim().isNotEmpty ?? false)
                  _buildLocationStatChip(
                    icon: Icons.map_outlined,
                    label: listing.district!,
                    background: Colors.blue.shade50,
                    foreground: Colors.blue.shade800,
                  ),
                _buildLocationStatChip(
                  icon: listing.hasCoordinates
                      ? Icons.my_location
                      : Icons.location_searching_outlined,
                  label: listing.hasCoordinates
                      ? 'Coordinates Ready'
                      : 'Map Search',
                  background: listing.hasCoordinates
                      ? Colors.orange.shade50
                      : Colors.grey.shade200,
                  foreground: listing.hasCoordinates
                      ? Colors.orange.shade900
                      : Colors.grey.shade800,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingLocation)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locale.translate(
                        'Checking your location for distance and directions...',
                        'Re sheba sebaka sa hao bakeng sa bohole le tsela...',
                      ),
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              )
            else if (hasLiveDistance)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorPalette.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.near_me, color: ColorPalette.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locale.translate(
                          'You are about ${_locationService.formatDistanceKm(userDistanceKm)} away.',
                          'O hole ka ${_locationService.formatDistanceKm(userDistanceKm)}.',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                locale.translate(
                  'Add listing coordinates and allow location access to unlock live distance and directions.',
                  'Kenya dikhokahano tsa sebaka mme o dumelle sebaka sa hao ho bona bohole le tsela ka kotloloho.',
                ),
                style: TextStyle(color: Colors.grey[700]),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await _locationService.openInGoogleMaps(
                        latitude: listing.latitude,
                        longitude: listing.longitude,
                        query: locationQuery,
                      );
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Could not open Google Maps right now.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(locale.translate('Open Map', 'Bula Mmapa')),
                ),
                OutlinedButton.icon(
                  onPressed: (listing.hasCoordinates ||
                          locationQuery.trim().isNotEmpty)
                      ? () async {
                          try {
                            await _locationService.openDirections(
                              originLatitude: _userLatitude,
                              originLongitude: _userLongitude,
                              destinationLatitude: listing.latitude,
                              destinationLongitude: listing.longitude,
                              destinationQuery: locationQuery,
                            );
                          } catch (_) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not open directions right now.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.directions_outlined),
                  label:
                      Text(locale.translate('Get Directions', 'Fumana Tsela')),
                ),
                TextButton.icon(
                  onPressed: _isLoadingLocation ? null : _loadLocationContext,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    locale.translate('Refresh Distance', 'Ntlafatsa Bohole'),
                  ),
                ),
              ],
            ),
            if (nearbyListings.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                locale.translate(
                  'Nearby Attractions & Places',
                  'Dibaka le dikgahleho tse haufi',
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...nearbyListings.map(
                (item) {
                  final relativePosition =
                      _locationService.describeRelativePosition(listing, item);
                  final nearbyDistance =
                      (listing.hasCoordinates && item.hasCoordinates)
                          ? _locationService.calculateDistanceKm(
                              startLatitude: listing.latitude!,
                              startLongitude: listing.longitude!,
                              endLatitude: item.latitude!,
                              endLongitude: item.longitude!,
                            )
                          : null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor:
                          ColorPalette.primaryGreen.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.place_outlined,
                        color: ColorPalette.primaryGreen,
                      ),
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.location}${item.district != null ? ', ${item.district}' : ''} • $relativePosition',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ListingDetailScreen(listingId: item.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStatChip({
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacePreviewPanel({
    required Listing listing,
    required LocaleProvider locale,
    required double? userDistanceKm,
    required int nearbyCount,
  }) {
    final placeType = _describePlaceType(listing);
    final staticMapUrl = listing.hasCoordinates
        ? _locationService.buildStaticMapPreviewUrl(
            latitude: listing.latitude!,
            longitude: listing.longitude!,
            width: 420,
            height: 320,
          )
        : null;
    final locationLine = [
      listing.location,
      if (listing.district?.trim().isNotEmpty ?? false) listing.district!,
      'Lesotho',
    ].join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (listing.rating != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                listing.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.star,
                                size: 18,
                                color: Colors.amber,
                              ),
                              if ((listing.reviewCount ?? 0) > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${listing.reviewCount} reviews',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ],
                          ),
                        Text(
                          placeType,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locationLine,
                      style: TextStyle(
                        color: Colors.grey[700],
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ColorPalette.primaryGreen.withValues(alpha: 0.95),
                      ColorPalette.secondaryGreen.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: staticMapUrl != null
                            ? Image.network(
                                staticMapUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  if (listing.imageUrl != null &&
                                      listing.imageUrl!.trim().isNotEmpty) {
                                    return Opacity(
                                      opacity: 0.28,
                                      child: _buildListingImage(
                                        listing.imageUrl!,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              )
                            : listing.imageUrl != null &&
                                    listing.imageUrl!.trim().isNotEmpty
                                ? Opacity(
                                    opacity: 0.28,
                                    child: _buildListingImage(
                                      listing.imageUrl!,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: ColorPalette.primaryGreen,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLocationStatChip(
                icon: Icons.travel_explore,
                label: locale.translate(
                  '$nearbyCount nearby spots',
                  '$nearbyCount dibaka tse haufi',
                ),
                background: Colors.green.shade50,
                foreground: Colors.green.shade800,
              ),
              if (userDistanceKm != null)
                _buildLocationStatChip(
                  icon: Icons.near_me,
                  label: _locationService.formatDistanceKm(userDistanceKm),
                  background: Colors.blue.shade50,
                  foreground: Colors.blue.shade800,
                ),
              _buildLocationStatChip(
                icon: listing.hasCoordinates
                    ? Icons.pin_drop_outlined
                    : Icons.manage_search_outlined,
                label: listing.hasCoordinates ? 'Map ready' : 'Search ready',
                background: Colors.orange.shade50,
                foreground: Colors.orange.shade900,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _describePlaceType(Listing listing) {
    final category = listing.category.trim();
    if (category.isEmpty) return 'Destination in Lesotho';
    return '$category destination in Lesotho';
  }

  Widget _buildListingImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      final parts = imageUrl.split(',');
      if (parts.length == 2) {
        return Image.memory(
          base64Decode(parts[1]),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.image, size: 64, color: Colors.white),
          ),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(
          color: ColorPalette.primaryGreen,
        ),
      ),
      errorWidget: (context, url, error) {
        return const Center(
          child: Icon(Icons.image, size: 64, color: Colors.white),
        );
      },
    );
  }

  List<String> _collectPortfolioImages(dynamic listing) {
    final images = <String>[];
    if (listing.imageUrl != null &&
        listing.imageUrl!.toString().trim().isNotEmpty) {
      images.add(listing.imageUrl!.toString());
    }
    if (listing.images != null) {
      for (final img in listing.images!) {
        final value = img.toString().trim();
        if (value.isNotEmpty && !images.contains(value)) {
          images.add(value);
        }
      }
    }
    return images;
  }

  List<String> _collectVideoLinks(dynamic listing) {
    final raw = listing.additionalDetails?['videoLinks'];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      return raw
          .split(RegExp(r'[\n,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  void _showImagePreview(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Positioned.fill(child: _buildListingImage(imageUrl)),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods
  Widget _buildEmptyReviews() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to review this place!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(int stars, List<Review> reviews) {
    final count =
        reviews.where((r) => r.rating >= stars && r.rating < stars + 1).length;
    final percentage = reviews.isEmpty ? 0 : (count / reviews.length) * 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$stars★',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              color: Colors.amber[700],
              minHeight: 6,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(Review review) {
    final locale = Provider.of<LocaleProvider>(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale.translate('Report Review', 'Tlaleha Maikutlo')),
        content: Text(locale.translate(
            'Are you sure you want to report this review?',
            'Na u na le bonnete ba hore u batla ho tlaleha maikutlo aa?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(locale.translate('Cancel', 'Hlakola')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(locale.translate(
                      'Review reported. Thank you for helping keep our community safe.',
                      'Maikutlo a tlalehiloe. Re leboha ho thusa ho boloka sechaba sa rona se sireletsehile.')),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(locale.translate('Report', 'Tlaleha')),
          ),
        ],
      ),
    );
  }
}
