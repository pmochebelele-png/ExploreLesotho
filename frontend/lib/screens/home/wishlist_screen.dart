// lib/screens/home/wishlist_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/listing_card.dart';
import '../../core/themes/color_palette.dart';
import 'listing_detail_screen.dart';
import '../../utils/responsive_layout.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WishlistProvider>(context, listen: false).loadWishlistFromLocal();
    });
  }

  Future<void> _shareWishlist() async {
    final wishlistProvider = Provider.of<WishlistProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    
    if (wishlistProvider.wishlistItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locale.translate(
            'Your wishlist is empty. Add some places first!',
            'Lethathamo la hao le se na letho. Kenya libaka pele!',
          )),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSharing = true);

    try {
      final userName = authProvider.user?.name ?? 'Explorer';
      final wishlistCount = wishlistProvider.wishlistCount;
      
      // Generate share message
      String shareMessage = _generateShareMessage(
        userName, 
        wishlistCount, 
        wishlistProvider.wishlistItems,
        locale,
      );
      
      // Show custom share dialog with social media options
      _showShareDialog(context, shareMessage, locale);
      
    } catch (e) {
      print('❌ Error sharing wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locale.translate(
            'Failed to share wishlist. Please try again.',
            'Ho arolelana lethathamo ho hlolehile. Ka kopo leka hape.',
          )),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSharing = false);
    }
  }

  void _showShareDialog(BuildContext context, String message, LocaleProvider locale) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Wishlist',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how to share your wishlist',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _buildShareOption(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onTap: () => _shareToWhatsApp(message, locale),
                ),
                _buildShareOption(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: () => _shareToFacebook(message, locale),
                ),
                _buildShareOption(
                  icon: Icons.message,
                  label: 'Messenger',
                  color: const Color(0xFF0084FF),
                  onTap: () => _shareToMessenger(message, locale),
                ),
                _buildShareOption(
                  icon: Icons.telegram,
                  label: 'Telegram',
                  color: const Color(0xFF26A5E4),
                  onTap: () => _shareToTelegram(message, locale),
                ),
                _buildShareOption(
                  icon: Icons.mail,
                  label: 'Email',
                  color: Colors.red,
                  onTap: () => _shareToEmail(message, locale),
                ),
                _buildShareOption(
                  icon: Icons.sms,
                  label: 'SMS',
                  color: Colors.blue,
                  onTap: () => _shareToSMS(message, locale),
                ),
                _buildShareOption(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  color: Colors.grey,
                  onTap: () => _copyToClipboard(message, locale),
                ),
                _buildShareOption(
                  icon: Icons.more_horiz,
                  label: 'More',
                  color: Colors.purple,
                  onTap: () => _shareWithSystem(message, locale),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                locale.translate('Cancel', 'Hlakola'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color.withOpacity(0.1),
          child: IconButton(
            icon: Icon(icon, color: color, size: 28),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Future<void> _shareToWhatsApp(String message, LocaleProvider locale) async {
    final whatsappUrl = 'whatsapp://send?text=${Uri.encodeComponent(message)}';
    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
      } else {
        _shareWithSystem(message, locale);
      }
    } catch (e) {
      _shareWithSystem(message, locale);
    }
  }

  Future<void> _shareToFacebook(String message, LocaleProvider locale) async {
    final facebookUrl = 'https://www.facebook.com/sharer/sharer.php?u=https://explorelesotho.com/wishlist&quote=${Uri.encodeComponent(message)}';
    try {
      if (await canLaunchUrl(Uri.parse(facebookUrl))) {
        await launchUrl(Uri.parse(facebookUrl), mode: LaunchMode.externalApplication);
      } else {
        _shareWithSystem(message, locale);
      }
    } catch (e) {
      _shareWithSystem(message, locale);
    }
  }

  Future<void> _shareToMessenger(String message, LocaleProvider locale) async {
    final messengerUrl = 'fb-messenger://share?link=https://explorelesotho.com/wishlist&quote=${Uri.encodeComponent(message)}';
    try {
      if (await canLaunchUrl(Uri.parse(messengerUrl))) {
        await launchUrl(Uri.parse(messengerUrl));
      } else {
        _shareWithSystem(message, locale);
      }
    } catch (e) {
      _shareWithSystem(message, locale);
    }
  }

  Future<void> _shareToTelegram(String message, LocaleProvider locale) async {
    final telegramUrl = 'https://t.me/share/url?url=https://explorelesotho.com/wishlist&text=${Uri.encodeComponent(message)}';
    try {
      if (await canLaunchUrl(Uri.parse(telegramUrl))) {
        await launchUrl(Uri.parse(telegramUrl), mode: LaunchMode.externalApplication);
      } else {
        _shareWithSystem(message, locale);
      }
    } catch (e) {
      _shareWithSystem(message, locale);
    }
  }

  Future<void> _shareToEmail(String message, LocaleProvider locale) async {
    final emailUrl = 'mailto:?subject=My%20Explore%20Lesotho%20Wishlist&body=${Uri.encodeComponent(message)}';
    try {
      if (await canLaunchUrl(Uri.parse(emailUrl))) {
        await launchUrl(Uri.parse(emailUrl));
      } else {
        _shareWithSystem(message, locale);
      }
    } catch (e) {
      _shareWithSystem(message, locale);
    }
  }

  Future<void> _shareToSMS(String message, LocaleProvider locale) async {
    final smsUrl = 'sms:?body=${Uri.encodeComponent(message)}';
    try {
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
      } else {
        _shareWithSystem(message, locale);
      }
    } catch (e) {
      _shareWithSystem(message, locale);
    }
  }

  Future<void> _shareWithSystem(String message, LocaleProvider locale) async {
    try {
      await Share.share(
        message,
        subject: 'My Explore Lesotho Wishlist',
      );
    } catch (e) {
      _copyToClipboard(message, locale);
    }
  }

  Future<void> _copyToClipboard(String message, LocaleProvider locale) async {
    try {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale.translate(
              'Wishlist copied to clipboard!',
              'Lethathamo le kopitsoe!',
            )),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error copying to clipboard: $e');
    }
  }

  String _generateShareMessage(String userName, int count, List<dynamic> items, LocaleProvider locale) {
    String message = '🌟 $userName\'s Explore Lesotho Wishlist 🌟\n';
    message += '📍 ${locale.translate('Saved Places', 'Libaka tse Bolokiloeng')}: $count\n\n';
    
    final topItems = items.take(10).toList();
    for (int i = 0; i < topItems.length; i++) {
      final item = topItems[i];
      message += '${i + 1}. ${item.title}\n';
      if (item.rating != null && item.rating! > 0) {
        message += '   ⭐ ${item.rating!.toStringAsFixed(1)} ★\n';
      }
      if (item.location != null && item.location!.isNotEmpty) {
        message += '   📍 ${item.location}\n';
      }
      message += '\n';
    }
    
    if (items.length > 10) {
      message += '... ${locale.translate('and', 'le')} ${items.length - 10} ${locale.translate('more places', 'libaka tse ling')}\n\n';
    }
    
    message += '✨ ${locale.translate('Plan your next adventure with Explore Lesotho!', 'Rala leeto la hao le latelang le Explore Lesotho!')}\n';
    message += '📱 ${locale.translate('Download the app', 'Khoasolla sesebelisoa')}: https://explorelesotho.com/app';
    
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final wishlistProvider = Provider.of<WishlistProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final fontSize = ResponsiveLayout.getFontSize(context);
    final padding = ResponsiveLayout.getPadding(context);
    final gridCrossAxisCount = ResponsiveLayout.getGridCrossAxisCount(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/tourist-dashboard',
              (route) => false,
            );
          },
          tooltip: locale.translate('Back to Home', 'Khutlela Lethathamong'),
        ),
        title: Text(
          locale.translate('My Wishlist', 'Lethathamo la ka'),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          // Share Button
          if (wishlistProvider.wishlistCount > 0)
            IconButton(
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.share),
              onPressed: _isSharing ? null : _shareWishlist,
              tooltip: locale.translate('Share Wishlist', 'Arolelana Lethathamo'),
            ),
          // Clear Button
          if (wishlistProvider.wishlistCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(locale.translate('Clear Wishlist', 'Hlakola Lethathamo')),
                    content: Text(locale.translate(
                      'Are you sure you want to remove all items from your wishlist?',
                      'Na u netefatsa hore u batla ho hlakola lintho tsohle lethathamong la hao?',
                    )),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(locale.translate('Cancel', 'Hlakola')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text(locale.translate('Clear', 'Hlakola')),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await wishlistProvider.clearWishlist();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(locale.translate('Wishlist cleared', 'Lethathamo le hlakotsoe')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              tooltip: locale.translate('Clear All', 'Hlakola Tsohle'),
            ),
        ],
      ),
      body: wishlistProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : wishlistProvider.wishlistItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: isMobile ? 64 : 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        locale.translate('Your wishlist is empty', 'Lethathamo la hao le se na letho'),
                        style: TextStyle(
                          fontSize: fontSize + 2,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        locale.translate('Start adding places you love!', 'Qala ho kenya libaka tseo u li ratang!'),
                        style: TextStyle(
                          fontSize: fontSize - 2,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/tourist-dashboard',
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.explore),
                        label: Text(locale.translate('Explore Listings', 'Fumana Lintlha')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorPalette.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: padding,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCrossAxisCount,
                    childAspectRatio: isMobile ? 0.7 : 0.8,
                    crossAxisSpacing: isMobile ? 8 : 12,
                    mainAxisSpacing: isMobile ? 8 : 12,
                  ),
                  itemCount: wishlistProvider.wishlistItems.length,
                  itemBuilder: (context, index) {
                    final listing = wishlistProvider.wishlistItems[index];
                    return Stack(
                      children: [
                        ListingCard(
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
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () async {
                                final removed = await wishlistProvider.removeFromWishlist(listing.id.toString());
                                if (removed && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        locale.translate('Removed from wishlist', 'E tlositsoe lethathamong'),
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
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
                    );
                  },
                ),
    );
  }
}
