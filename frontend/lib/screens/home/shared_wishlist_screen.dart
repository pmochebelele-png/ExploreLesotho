// lib/screens/home/shared_wishlist_screen.dart
import 'package:flutter/material.dart';
import '../../models/listing.dart';
import '../../widgets/listing_card.dart';
import '../../core/themes/color_palette.dart';
import 'listing_detail_screen.dart';

class SharedWishlistScreen extends StatelessWidget {
  final List<Listing> wishlistItems;
  final String userName;
  final int itemCount;

  const SharedWishlistScreen({
    super.key,
    required this.wishlistItems,
    required this.userName,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('$userName\'s Wishlist'),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: wishlistItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                        'This wishlist is empty',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                      ),
                  const SizedBox(height: 8),
                  Text(
                    '$userName hasn\'t added any places yet',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: wishlistItems.length,
              itemBuilder: (context, index) {
                final listing = wishlistItems[index];
                return ListingCard(
                  listing: listing,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ListingDetailScreen(
                          listingId: listing.id.toString(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}