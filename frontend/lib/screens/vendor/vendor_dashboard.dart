// lib/screens/vendor/vendor_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/test_chat_provider.dart';
import '../../core/themes/color_palette.dart';
import '../../services/api_service.dart';
import '../../services/ml_service.dart';
import '../../widgets/social_media_buttons.dart';
import '../../widgets/mountain_background.dart';
import '../auth/login_screen.dart';
import '../chat/chat_detail_screen.dart';
import '../chat/chat_list_screen.dart';
import 'vendor_listings_screen.dart';
import 'vendor_bookings_screen.dart';
import 'vendor_analytics_screen.dart';
import 'vendor_events_screen.dart';
import 'vendor_reviews_screen.dart';
import '../../models/culture_vendor.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final MlService _mlService = MlService();
  CultureVendor? _claimedCultureVendor;
  bool _isCultureProfileLoading = false;
  Map<String, dynamic>? _aiDashboard;
  List<Map<String, dynamic>> _aiForecast = [];
  List<Map<String, dynamic>> _aiRecommendations = [];
  List<Map<String, dynamic>> _aiHotspots = [];
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);

    // Load vendor events when dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final chatProvider = Provider.of<TestChatProvider>(context, listen: false);
      final vendorUserId = authProvider.user?.userId ??
          int.tryParse(authProvider.user?.id ?? '0');
      if (vendorUserId != null && vendorUserId > 0) {
        eventProvider.fetchMyEvents(vendorUserId);
      }
      chatProvider.loadConversations();
      _loadClaimedCultureProfile();
      _loadAiInsights();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openVendorHotspot(Map<String, dynamic> spot) {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    _tabController.animateTo(3);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          locale.translate(
            'Focused analytics on ${spot['name'] ?? 'this hotspot'} in ${spot['district'] ?? 'Lesotho'}.',
            'Lipalopalo li shebane le ${spot['name'] ?? 'hotspot ena'} ho ${spot['district'] ?? 'Lesotho'}.',
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    final listingProvider = Provider.of<ListingProvider>(context);
    final eventProvider = Provider.of<EventProvider>(context);
    final chatProvider = Provider.of<TestChatProvider>(context);

    final vendorUserId =
        authProvider.user?.userId?.toString() ?? authProvider.user?.id;

    // Use raw listings so tourist search/category filters do not hide vendor data.
    final vendorListings = listingProvider.allListings
        .where((l) => l.vendorId == vendorUserId)
        .toList();

    // When logged in as a vendor, BookingProvider already loads vendor bookings from the API.
    final vendorBookings = bookingProvider.userBookings;

    // Calculate stats
    final totalListings = vendorListings.length;
    final totalBookings = vendorBookings.length;
    final totalEvents = eventProvider.myEvents.length; // ✅ ADDED: Events count
    final completedBookings =
        vendorBookings.where((b) => b.status == 'completed').length;
    final pendingBookings =
        vendorBookings.where((b) => b.status == 'pending').length;
    final totalRevenue = vendorBookings
        .where((b) => b.status == 'completed')
        .fold(0.0, (sum, b) => sum + b.grandTotal);
    final primaryListing =
        vendorListings.isNotEmpty ? vendorListings.first : null;

    return MountainBackground(
      overlayOpacity: 0.25,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(locale.translate('Vendor Dashboard', 'Letlapa la Morekisi')),
          backgroundColor: ColorPalette.primaryGreen,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.language),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Select Language / Khetha Puo'),
                    content: Consumer<LocaleProvider>(
                      builder: (context, localeProvider, child) {
                        final isEnglish =
                            localeProvider.locale.languageCode == 'en';
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: const Text('English'),
                              trailing: isEnglish
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              onTap: () async {
                                await localeProvider.setLocale('en');
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              title: const Text('Sesotho sa Lesotho'),
                              trailing: !isEnglish
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              onTap: () async {
                                await localeProvider.setLocale('st');
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
              tooltip: 'Change Language',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                listingProvider.loadListings();
                bookingProvider.refresh();
                await chatProvider.loadConversations();
                final vendorUserIdNum = authProvider.user?.userId ??
                    int.tryParse(authProvider.user?.id ?? '0');
                if (vendorUserIdNum != null && vendorUserIdNum > 0) {
                  await eventProvider.fetchMyEvents(vendorUserIdNum);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(locale.translate(
                        'Data refreshed', 'Data e nchafatsoe')),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              tooltip: 'Refresh Data',
            ),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => _openMessagesInbox(context),
                  tooltip: 'Messages',
                ),
                if (chatProvider.totalUnread > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${chatProvider.totalUnread}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
              tooltip: 'Logout',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                icon: const Icon(Icons.dashboard),
                text: locale.translate('Overview', 'Kakaretso'),
              ),
              Tab(
                icon: const Icon(Icons.list),
                text: locale.translate('Listings', 'Manane'),
              ),
              Tab(
                icon: const Icon(Icons.book_online),
                text: locale.translate('Bookings', 'Lipeheletso'),
              ),
              Tab(
                icon: const Icon(Icons.analytics),
                text: locale.translate('Analytics', 'Lipalopalo'),
              ),
              Tab(
                icon: const Icon(Icons.rate_review),
                text: locale.translate('Reviews', 'Maikutlo'),
              ),
              // ✅ Events Tab
              Tab(
                icon: const Icon(Icons.event),
                text: locale.translate('Events', 'Liketsahalo'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(
                context,
                locale,
                totalListings,
                totalBookings,
                totalEvents,
                completedBookings,
                pendingBookings,
                totalRevenue,
                vendorBookings,
                authProvider,
                chatProvider,
                vendorListings,
                primaryListing),
            const VendorListingsScreen(),
            VendorBookingsScreen(vendorBookings: vendorBookings),
            VendorAnalyticsScreen(
                vendorBookings: vendorBookings, vendorListings: vendorListings),
            const VendorReviewsScreen(),
            // ✅ Vendor Events Screen
            VendorEventsScreen(),
          ],
        ),
      ),
    );
  }

  Future<void> _loadClaimedCultureProfile() async {
    if (!mounted) return;
    setState(() => _isCultureProfileLoading = true);
    try {
      final response = await _apiService.get('/culture/vendors/claimed/me');
      final body = json.decode(response.body);
      if (!mounted) return;
      setState(() {
        _claimedCultureVendor = body['success'] == true &&
                body['vendor'] != null
            ? CultureVendor.fromJson(Map<String, dynamic>.from(body['vendor']))
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _claimedCultureVendor = null);
    } finally {
      if (mounted) {
        setState(() => _isCultureProfileLoading = false);
      }
    }
  }

  Future<void> _loadAiInsights() async {
    if (!mounted) return;
    setState(() => _isAiLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _mlService.fetchDashboard(),
        _mlService.fetchForecast(),
        _mlService.fetchHotspots(),
        _mlService.fetchRecommendations(
          role: 'vendor',
          preferences: {'focus': 'vendor_growth'},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _aiDashboard = results[0] is Map<String, dynamic>
            ? results[0] as Map<String, dynamic>
            : null;
        _aiForecast = results[1] is List<Map<String, dynamic>>
            ? results[1] as List<Map<String, dynamic>>
            : const [];
        _aiHotspots = results[2] is List<Map<String, dynamic>>
            ? results[2] as List<Map<String, dynamic>>
            : const [];
        _aiRecommendations = results[3] is List<Map<String, dynamic>>
            ? results[3] as List<Map<String, dynamic>>
            : const [];
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, val) => MapEntry(key.toString(), val)),
        )
        .toList();
  }

  Future<void> _showEditClaimedCultureProfileDialog() async {
    final vendor = _claimedCultureVendor;
    if (vendor == null) return;

    final nameController = TextEditingController(text: vendor.name);
    final productController = TextEditingController(text: vendor.productRange);
    final locationController = TextEditingController(text: vendor.location);
    final contactsController =
        TextEditingController(text: vendor.contacts.join(', '));
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Claimed Culture Profile'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Business name',
                          prefixIcon: Icon(Icons.storefront),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: productController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Products / services',
                          prefixIcon: Icon(Icons.design_services),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: contactsController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Contacts / profile notes',
                          prefixIcon: Icon(Icons.contact_phone),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setStateDialog(() => isSaving = true);
                          try {
                            final response = await _apiService.patch(
                              '/culture/vendors/claimed/me',
                              {
                                'name': nameController.text.trim(),
                                'productRange': productController.text.trim(),
                                'location': locationController.text.trim(),
                                'contacts': contactsController.text
                                    .split(RegExp(r'[\n,]'))
                                    .map((item) => item.trim())
                                    .where((item) => item.isNotEmpty)
                                    .toList(),
                                'subcategorySlugs': vendor.subcategorySlugs,
                              },
                            );
                            final body = json.decode(response.body);
                            if (response.statusCode == 200 &&
                                body['success'] == true) {
                              await _loadClaimedCultureProfile();
                              if (!mounted || !dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Claimed culture profile updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              return;
                            }
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  body['message']?.toString() ??
                                      body['error']?.toString() ??
                                      'Failed to update culture profile',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } catch (_) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Failed to update culture profile'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            if (dialogContext.mounted) {
                              setStateDialog(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditSocialLinksDialog(dynamic primaryListing) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final listingProvider =
        Provider.of<ListingProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);

    final phoneController = TextEditingController(
      text: (primaryListing?.vendorPhone ?? '').toString(),
    );
    final emailController = TextEditingController(
      text: (primaryListing?.vendorEmail ?? authProvider.user?.email ?? '')
          .toString(),
    );
    final whatsappController = TextEditingController(
      text: (primaryListing?.vendorWhatsapp ?? '').toString(),
    );
    final facebookController = TextEditingController(
      text: (primaryListing?.vendorFacebook ?? '').toString(),
    );
    final instagramController = TextEditingController(
      text: (primaryListing?.vendorInstagram ?? '').toString(),
    );

    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                locale.translate(
                    'Edit Social Links', 'Fetola Dikamano tsa Sechaba'),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: whatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                          prefixIcon: Icon(Icons.chat),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: facebookController,
                        decoration: const InputDecoration(
                          labelText: 'Facebook username/page',
                          prefixIcon: Icon(Icons.facebook),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: instagramController,
                        decoration: const InputDecoration(
                          labelText: 'Instagram username',
                          prefixIcon: Icon(Icons.camera_alt),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(dialogContext),
                  child: Text(locale.translate('Cancel', 'Hlakola')),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setStateDialog(() => isSaving = true);
                          try {
                            final response = await _apiService.patch(
                              '/vendors/social-links',
                              {
                                'business_phone': phoneController.text.trim(),
                                'business_email': emailController.text.trim(),
                                'whatsapp': whatsappController.text.trim(),
                                'facebook': facebookController.text.trim(),
                                'instagram': instagramController.text.trim(),
                              },
                            );

                            final body = json.decode(response.body);
                            if (response.statusCode == 200 &&
                                body['success'] == true) {
                              await listingProvider.loadListings();
                              if (mounted && dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      locale.translate(
                                        'Social links updated',
                                        'Dikamano tsa sechaba di ntlafaditswe',
                                      ),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                              return;
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    body['message']?.toString() ??
                                        'Failed to update social links',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Failed to update social links'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setStateDialog(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(locale.translate('Save', 'Boloka')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOverviewTab(
      BuildContext context,
      LocaleProvider locale,
      int totalListings,
      int totalBookings,
      int totalEvents,
      int completedBookings,
      int pendingBookings,
      double totalRevenue,
      List<dynamic> vendorBookings,
      AuthProvider authProvider,
      TestChatProvider chatProvider,
      List<dynamic> vendorListings,
      dynamic primaryListing) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    ColorPalette.primaryGreen,
                    ColorPalette.secondaryGreen
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.translate('Welcome back,', 'Rea u amohela hape,'),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authProvider.user?.name ?? 'Vendor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    locale.translate(
                      'Manage your listings, events, and track bookings',
                      'Laola lintlha, liketsahalo, le ho shebella lipehelo tsa hao',
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Stats Grid
          Text(
            locale.translate('Quick Stats', 'Lipalopalo'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                title: locale.translate('Total Listings', 'Lintlha'),
                value: '$totalListings',
                icon: Icons.list_alt,
                color: Colors.blue,
              ),
              _buildStatCard(
                title:
                    locale.translate('Total Events', 'Liketsahalo'), // ✅ ADDED
                value: '$totalEvents',
                icon: Icons.event,
                color: Colors.deepPurple,
              ),
              _buildStatCard(
                title: locale.translate('Total Bookings', 'Lipehelo'),
                value: '$totalBookings',
                icon: Icons.book_online,
                color: Colors.green,
              ),
              _buildStatCard(
                title: locale.translate('Completed', 'Tse Felileng'),
                value: '$completedBookings',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _buildStatCard(
                title: locale.translate('Pending', 'Tse Emaetseng'),
                value: '$pendingBookings',
                icon: Icons.pending,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: locale.translate('Total Revenue', 'Lekeno'),
                value: 'M${totalRevenue.toStringAsFixed(0)}',
                icon: Icons.attach_money,
                color: Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildAiVendorPanel(locale),

          const SizedBox(height: 24),

          _buildMessagesPreviewCard(
            context: context,
            locale: locale,
            chatProvider: chatProvider,
            currentUserId: authProvider.user?.id ?? '',
          ),

          const SizedBox(height: 24),

          // Revenue Chart
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.translate('Revenue Overview', 'Kakaretso ea Lekeno'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildRevenueChart(vendorBookings),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Text(
            locale.translate('Quick Actions', 'Liketso tse Potlakileng'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.add_business,
                  label: locale.translate('Add Listing', 'Kenya Lintlha'),
                  color: Colors.green,
                  onTap: () {
                    _tabController.animateTo(1);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.add,
                  label: locale.translate(
                      'Add Event', 'Kenya Ketsahalo'), // ✅ ADDED
                  color: Colors.deepPurple,
                  onTap: () {
                    _tabController.animateTo(5); // Events tab
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.book_online,
                  label: locale.translate('View Bookings', 'Bona Lipehelo'),
                  color: Colors.blue,
                  onTap: () {
                    _tabController.animateTo(2);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.analytics,
                  label: locale.translate('View Analytics', 'Bona Lipalopalo'),
                  color: Colors.purple,
                  onTap: () {
                    _tabController.animateTo(3);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.rate_review,
                  label: locale.translate('Reviews', 'Maikutlo'),
                  color: Colors.teal,
                  onTap: () {
                    _tabController.animateTo(4);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.message,
                  label: locale.translate('Messages', 'Melaetsa'),
                  color: Colors.orange,
                  onTap: () => _openMessagesInbox(context),
                ),
              ),
            ],
          ),

          // Social Media & Contact Section
          const SizedBox(height: 24),
          if (_isCultureProfileLoading || _claimedCultureVendor != null)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _isCultureProfileLoading
                    ? const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Loading claimed culture profile...'),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_user,
                                  color: Colors.blue),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Claimed Culture Profile',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _showEditClaimedCultureProfileDialog,
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _claimedCultureVendor?.productRange.isNotEmpty ==
                                    true
                                ? _claimedCultureVendor!.productRange
                                : 'Add a stronger description of your products and services.',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (_claimedCultureVendor?.location.isNotEmpty ??
                                    false)
                                ? 'Location: ${_claimedCultureVendor!.location}'
                                : 'Location: Not yet specified',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
              ),
            ),
          if (_isCultureProfileLoading || _claimedCultureVendor != null)
            const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connect With Customers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share your social media links to help customers reach you',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  // Social Media Buttons
                  SocialMediaButtons(
                    whatsapp: primaryListing?.vendorWhatsapp,
                    phone: primaryListing?.vendorPhone,
                    email:
                        primaryListing?.vendorEmail ?? authProvider.user?.email,
                    website: primaryListing?.vendorWebsite,
                    facebook: primaryListing?.vendorFacebook,
                    instagram: primaryListing?.vendorInstagram,
                    iconSize: 20,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      _showEditSocialLinksDialog(primaryListing);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Social Links'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Your Latest Listings Section
          const SizedBox(height: 24),
          Text(
            locale.translate(
                'Your Latest Listings', 'Lintlha tsa Hao tsa Morao-rao'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (vendorListings.isEmpty)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Your listings will appear here as soon as you add them.'),
              ),
            )
          else
            ...vendorListings.take(3).map((listing) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: ColorPalette.lightGreen,
                    child:
                        Icon(Icons.list_alt, color: ColorPalette.primaryGreen),
                  ),
                  title: Text(
                    listing.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      '${listing.location} • M${listing.price.toStringAsFixed(0)}'),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      listing.isAvailable ? 'Live' : 'Hidden',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAiVendorPanel(LocaleProvider locale) {
    final rawAiInsights = _aiDashboard?['ai_insights'];
    final aiInsights = rawAiInsights is Map<String, dynamic>
        ? rawAiInsights
        : <String, dynamic>{};
    final legacyIntelligence = _mapValue(_aiDashboard?['legacy_intelligence']);
    final peakMonth = _mapValue(legacyIntelligence['peak_month']);
    final topMarkets = _mapList(legacyIntelligence['top_markets']);
    final topAttractions = _mapList(legacyIntelligence['top_attractions']);
    final seasonalHotspots = _mapList(legacyIntelligence['seasonal_hotspots']);
    final recommendedActions =
        (aiInsights['recommended_actions'] as List?) ?? const [];
    final rawForecastPreview =
        _aiForecast.isNotEmpty ? _aiForecast.first : null;
    final forecastPreview = rawForecastPreview is Map<String, dynamic>
        ? rawForecastPreview
        : null;
    final forecastBookings =
        forecastPreview?['predicted_bookings'] ??
        forecastPreview?['bookings'] ??
        0;
    final forecastConfidence = forecastPreview?['confidence'] ?? '-';

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ColorPalette.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_graph,
                    color: ColorPalette.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locale.translate('AI Business Tips', 'Malebela a AI'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        locale.translate(
                          'Quick insight from current tourism demand and platform activity.',
                          'Tlhahisoleseding e potlakileng ho tloha tlhokahalong ya bohahlaudi le tshebetso ya sethala.',
                        ),
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isAiLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildAiMiniChip(
                    'Approval Rate',
                    '${aiInsights['vendor_approval_rate'] ?? 0}%',
                    Colors.green,
                  ),
                  _buildAiMiniChip(
                    'Fraud Alerts',
                    '${aiInsights['fraud_detection_alerts'] ?? 0}',
                    Colors.orange,
                  ),
                  _buildAiMiniChip(
                    'Peak Season',
                    aiInsights['high_demand_season']?.toString() ?? 'Winter',
                    Colors.deepPurple,
                  ),
                ],
              ),
              if (peakMonth.isNotEmpty ||
                  topMarkets.isNotEmpty ||
                  topAttractions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (peakMonth.isNotEmpty)
                      _buildAiMiniChip(
                        'Peak Month',
                        '${peakMonth['month'] ?? '-'}',
                        Colors.deepOrange,
                      ),
                    if (topMarkets.isNotEmpty)
                      _buildAiMiniChip(
                        'Top Market',
                        '${topMarkets.first['country'] ?? '-'}',
                        Colors.blue,
                      ),
                    if (topAttractions.isNotEmpty)
                      _buildAiMiniChip(
                        'Top Attraction',
                        '${topAttractions.first['name'] ?? '-'}',
                        Colors.teal,
                      ),
                  ],
                ),
              ],
              if (_aiHotspots.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        locale.translate(
                          'Tourism Hotspots',
                          'Libaka Tse Tummeng tsa Bohahlaudi',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ColorPalette.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_aiHotspots.length} live',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ColorPalette.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 206,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _aiHotspots.take(3).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => _buildVendorHotspotCard(
                      _aiHotspots[index],
                    ),
                  ),
                ),
              ],
              if (seasonalHotspots.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  locale.translate(
                    'Seasonal Playbook',
                    'Moralo wa Dihla',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: seasonalHotspots.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) =>
                        _buildVendorSeasonCard(seasonalHotspots[index]),
                  ),
                ),
              ],
              if (false && _aiHotspots.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  locale.translate(
                    'Tourism Hotspots',
                    'Libaka Tse Tummeng tsa Bohahlaudi',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _aiHotspots.take(3).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final spot = _aiHotspots[index];
                      return Container(
                        width: 220,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              ColorPalette.lightGreen.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${spot['name'] ?? 'Hotspot'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${spot['district'] ?? ''} • score ${spot['score'] ?? 0}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (forecastPreview != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ColorPalette.lightGreen.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Next demand signal: ${forecastPreview['date']} • $forecastBookings expected bookings • confidence $forecastConfidence%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              if (recommendedActions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  locale.translate(
                    'Recommended Actions',
                    'Liketso Tse Kgothaletswang',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...recommendedActions.take(3).map(
                      (action) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.bolt,
                          color: ColorPalette.primaryGreen,
                        ),
                        title: Text(action.toString()),
                      ),
                    ),
              ],
              if (_aiRecommendations.isNotEmpty) ...[
                const SizedBox(height: 16),
                ..._aiRecommendations.take(3).map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.lightbulb_outline,
                          color: ColorPalette.primaryGreen,
                        ),
                        title:
                            Text(item['name']?.toString() ?? 'Recommendation'),
                        subtitle: Text(
                          '${item['season'] ?? 'All year'} • popularity ${item['popularity'] ?? 0}',
                        ),
                      ),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiMiniChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorSeasonCard(Map<String, dynamic> season) {
    final places = (season['places'] as List?) ?? const [];
    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            ColorPalette.lightGreen.withValues(alpha: 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ColorPalette.primaryGreen.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${season['season'] ?? 'Season'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...places.take(3).map(
                (place) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• $place',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildVendorHotspotCard(Map<String, dynamic> spot) {
    final name = '${spot['name'] ?? 'Hotspot'}';
    final district = '${spot['district'] ?? 'Lesotho'}';
    final score = '${spot['score'] ?? 0}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openVendorHotspot(spot),
        child: Ink(
          width: 240,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                ColorPalette.lightGreen.withValues(alpha: 0.56),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ColorPalette.primaryGreen.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: ColorPalette.primaryGreen.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ColorPalette.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: ColorPalette.primaryGreen,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Score $score',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                district,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tap to focus your vendor analytics here.',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<dynamic> bookings) {
    // Group bookings by month
    final Map<int, double> monthlyRevenue = {};
    for (var booking in bookings) {
      if (booking.status == 'completed') {
        final month = booking.createdAt.month;
        monthlyRevenue[month] =
            (monthlyRevenue[month] ?? 0) + booking.grandTotal;
      }
    }

    final spots = List.generate(12, (index) {
      final month = index + 1;
      return FlSpot(index.toDouble(), monthlyRevenue[month] ?? 0);
    });

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = [
                  'Jan',
                  'Feb',
                  'Mar',
                  'Apr',
                  'May',
                  'Jun',
                  'Jul',
                  'Aug',
                  'Sep',
                  'Oct',
                  'Nov',
                  'Dec'
                ];
                return Text(
                  months[value.toInt()],
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('M${value.toInt()}',
                    style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: ColorPalette.primaryGreen,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: ColorPalette.primaryGreen.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMessagesInbox(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatListScreen(),
      ),
    );
    if (!mounted) return;
    context.read<TestChatProvider>().loadConversations();
  }

  Widget _buildMessagesPreviewCard({
    required BuildContext context,
    required LocaleProvider locale,
    required TestChatProvider chatProvider,
    required String currentUserId,
  }) {
    final conversations = chatProvider.conversations.take(3).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_outlined, color: ColorPalette.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locale.translate('Messages', 'Melaetsa'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (chatProvider.totalUnread > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ColorPalette.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${chatProvider.totalUnread} new',
                      style: const TextStyle(
                        color: ColorPalette.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (conversations.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  locale.translate(
                    'No tourist or admin messages yet.',
                    'Ha ho melaetsa ya bahahlaudi kapa admin hajoale.',
                  ),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              )
            else
              ...conversations.map((conversation) {
                final otherParticipant = conversation.participants.cast<dynamic?>().firstWhere(
                      (participant) => participant?.userId != currentUserId,
                      orElse: () => conversation.participants.isNotEmpty
                          ? conversation.participants.first
                          : null,
                    );

                final senderName = otherParticipant?.fullName?.toString() ??
                    locale.translate('Unknown User', 'Mosebedisi ya sa tsejweng');
                final subtitle =
                    conversation.lastMessage?.content ?? locale.translate(
                      'Tap to open conversation',
                      'Tobetsa ho bula puisano',
                    );

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    color: Colors.white,
                  ),
                  child: ListTile(
                    onTap: () async {
                      await chatProvider.markConversationAsRead(conversation.id);
                      chatProvider.selectConversation(conversation.id);
                      if (!context.mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            conversationId: conversation.id,
                            conversation: conversation,
                          ),
                        ),
                      );
                      if (!context.mounted) return;
                      chatProvider.selectConversation('');
                      chatProvider.loadUnreadCounts();
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: ColorPalette.primaryGreen.withOpacity(0.12),
                      child: Text(
                        senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: ColorPalette.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: conversation.unreadCount > 0
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                  ),
                );
              }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openMessagesInbox(context),
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  locale.translate('Open Inbox', 'Bula Inbox'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
