import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/themes/color_palette.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/culture_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/test_chat_provider.dart';
import '../../services/connectivity_service.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/culture_vendor_card.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/mountain_background.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/upcoming_events_widget.dart';
import '../../services/ml_service.dart';
import '../auth/login_screen.dart';
import '../bookings/my_bookings_screen.dart';
import '../chat/chat_list_screen.dart';
import '../events/events_screen.dart';
import '../notifications/wishlist_notifications_screen.dart';
import 'culture_vendor_detail_screen.dart';
import 'listing_detail_screen.dart';
import 'wishlist_screen.dart';

class TouristDashboard extends StatefulWidget {
  const TouristDashboard({super.key});

  @override
  State<TouristDashboard> createState() => _TouristDashboardState();
}

class _TouristDashboardState extends State<TouristDashboard> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final MlService _mlService = MlService();
  Map<String, dynamic>? _aiDashboard;
  List<Map<String, dynamic>> _aiRecommendations = [];
  List<Map<String, dynamic>> _aiHotspots = [];
  bool _aiLoading = false;

  final List<String> _categories = [
    'All',
    'Accommodation',
    'Tour',
    'Experience',
    'Culture',
    'Adventure',
    'Upcoming Events',
  ];
  VoidCallback? _connectivityListener;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ListingProvider>(context, listen: false).loadListings();
      Provider.of<CultureProvider>(context, listen: false).loadInitial();
      Provider.of<BookingProvider>(context, listen: false).refresh();
      Provider.of<EventProvider>(context, listen: false).fetchUpcomingEvents();
      Provider.of<TestChatProvider>(context, listen: false).loadConversations();
      _loadAiContent();
    });

    final connectivity = context.read<ConnectivityService>();
    _connectivityListener = () {
      if (!connectivity.isConnected || !mounted) return;
      context.read<ListingProvider>().syncListingsSilently();
      context.read<CultureProvider>().loadInitial();
      context.read<EventProvider>().fetchUpcomingEvents();
    };
    connectivity.addListener(_connectivityListener!);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    final listener = _connectivityListener;
    if (listener != null) {
      context.read<ConnectivityService>().removeListener(listener);
    }
    super.dispose();
  }

  void _onSearchChanged() {
    final listingProvider =
        Provider.of<ListingProvider>(context, listen: false);
    final cultureProvider =
        Provider.of<CultureProvider>(context, listen: false);
    listingProvider.search(_searchController.text);
    if (listingProvider.selectedCategory == 'Culture') {
      cultureProvider.loadVendors(search: _searchController.text);
    }
  }

  Future<void> _loadAiContent() async {
    if (!mounted) return;

    setState(() => _aiLoading = true);
    final selectedCategory =
        Provider.of<ListingProvider>(context, listen: false).selectedCategory;

    try {
      final results = await Future.wait<dynamic>([
        _mlService.fetchDashboard(),
        _mlService.fetchRecommendations(
          role: 'tourist',
          preferences: {
            'category': selectedCategory,
          },
        ),
        _mlService.fetchHotspots(),
      ]);

      if (!mounted) return;
      setState(() {
        _aiDashboard = results[0] is Map<String, dynamic>
            ? results[0] as Map<String, dynamic>
            : null;
        _aiRecommendations = results[1] is List<Map<String, dynamic>>
            ? results[1] as List<Map<String, dynamic>>
            : const [];
        _aiHotspots = results[2] is List<Map<String, dynamic>>
            ? results[2] as List<Map<String, dynamic>>
            : const [];
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  String _mapMlCategoryToDashboard(String? rawCategory) {
    final value = rawCategory?.trim().toLowerCase() ?? '';
    switch (value) {
      case 'accommodation':
      case 'hotel':
      case 'lodge':
        return 'Accommodation';
      case 'tour':
      case 'tours':
        return 'Tour';
      case 'adventure':
        return 'Adventure';
      case 'culture':
      case 'cultural':
      case 'craft':
      case 'music':
      case 'dance':
      case 'art':
        return 'Culture';
      case 'experience':
        return 'Experience';
      default:
        return 'All';
    }
  }

  Future<void> _openHotspotDiscovery(Map<String, dynamic> hotspot) async {
    final listingProvider =
        Provider.of<ListingProvider>(context, listen: false);
    final cultureProvider =
        Provider.of<CultureProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);

    final mappedCategory = _mapMlCategoryToDashboard(
      hotspot['category']?.toString(),
    );
    listingProvider.filterByCategory(mappedCategory);
    _searchController.clear();
    listingProvider.search('');

    if (mappedCategory == 'Culture') {
      await cultureProvider.loadVendors();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          locale.translate(
            'Showing ${hotspot['name'] ?? 'hotspot'} discoveries now.',
            'Re bontsha dikgetho tsa ${hotspot['name'] ?? 'hotspot'} jwale.',
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openRecommendationDiscovery(Map<String, dynamic> item) async {
    final listingProvider =
        Provider.of<ListingProvider>(context, listen: false);
    final cultureProvider =
        Provider.of<CultureProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);

    final mappedCategory =
        _mapMlCategoryToDashboard(item['category']?.toString());
    listingProvider.filterByCategory(mappedCategory);
    _searchController.clear();
    listingProvider.search('');

    if (mappedCategory == 'Culture') {
      await cultureProvider.loadVendors();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          locale.translate(
            'Showing options for ${item['name'] ?? 'this activity'}.',
            'Re bontsha dikgetho tsa ${item['name'] ?? 'tshebetso ena'}.',
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WishlistScreen()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MyBookingsScreen(),
          ),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TouristEventsScreen(),
          ),
        );
        break;
      case 4:
        _showAccountSheet();
        break;
    }
  }

  void _showAccountSheet() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ColorPalette.primaryGreen,
                    child: Text(
                      _getUserInitial(authProvider.user?.name),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(authProvider.user?.name ?? 'User'),
                  subtitle: Text(authProvider.user?.email ?? ''),
                ),
                ListTile(
                  leading: const Icon(Icons.book_online_outlined),
                  title: Text(
                      locale.translate('My Bookings', 'Lipeheletso Tsa Ka')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(
                          builder: (_) => const MyBookingsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: const Text('My Event Tickets'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(this.context, '/my-event-tickets');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title:
                      Text(locale.translate('Change Language', 'Fetola Puo')),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: this.context,
                      builder: (_) => AlertDialog(
                        title: Text(
                            locale.translate('Select Language', 'Khetha Puo')),
                        content: Consumer<LocaleProvider>(
                          builder: (_, localeProvider, __) {
                            final isEnglish =
                                localeProvider.locale.languageCode == 'en';
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text('English'),
                                  trailing: isEnglish
                                      ? const Icon(Icons.check,
                                          color: Colors.green)
                                      : null,
                                  onTap: () async {
                                    await localeProvider.setLocale('en');
                                    if (mounted) Navigator.pop(this.context);
                                  },
                                ),
                                ListTile(
                                  title: const Text('Sesotho sa Lesotho'),
                                  trailing: !isEnglish
                                      ? const Icon(Icons.check,
                                          color: Colors.green)
                                      : null,
                                  onTap: () async {
                                    await localeProvider.setLocale('st');
                                    if (mounted) Navigator.pop(this.context);
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(locale.translate('Logout', 'Tswa')),
                  onTap: () async {
                    Navigator.pop(context);
                    await authProvider.logout();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      this.context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getUserInitial(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return 'U';
    return trimmed[0].toUpperCase();
  }

  String? _formatLastSynced(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
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

  String _getTranslatedCategory(String category, LocaleProvider locale) {
    final translations = {
      'All': ('All', 'Kakaretso'),
      'Accommodation': ('Accommodation', 'Libaka Tsa Boroko'),
      'Tour': ('Tour', 'Tsa Bohahlauli'),
      'Experience': ('Experience', 'Litsebo'),
      'Culture': ('Culture', 'Setso'),
      'Adventure': ('Adventure', 'Boiketlo'),
      'Upcoming Events': ('Upcoming Events', 'Liketsahalo Tse Tlang'),
    };

    final pair = translations[category] ?? (category, category);
    return locale.translate(pair.$1, pair.$2);
  }

  String _getTranslatedCultureType(String type, LocaleProvider locale) {
    const translations = {
      'All': ('All Types', 'Mefuta Eohle'),
      'Crafts': ('Crafts', 'Mesebetsi ea Matsoho'),
      'Music': ('Music', 'Mmino'),
      'Dance': ('Dance', 'Motjeko'),
      'Art': ('Art', 'Bonono'),
      'Food Heritage': ('Food Heritage', 'Lefa la Lijo'),
      'Storytelling': ('Storytelling', 'Pale tsa Setso'),
      'History': ('History', 'Nalane'),
      'Traditional Wear': ('Traditional Wear', 'Liaparo tsa Setso'),
      'Architecture': ('Architecture', 'Meaho ea Setso'),
      'Spiritual Heritage': ('Spiritual Heritage', 'Lefa la Moea'),
      'Festival': ('Festival', 'Mokete'),
    };
    final pair = translations[type] ?? (type, type);
    return locale.translate(pair.$1, pair.$2);
  }

  IconData _cultureTypeIcon(String type) {
    switch (type) {
      case 'Crafts':
        return Icons.handyman;
      case 'Music':
        return Icons.music_note;
      case 'Dance':
        return Icons.nightlife;
      case 'Art':
        return Icons.palette;
      case 'Food Heritage':
        return Icons.restaurant;
      case 'Storytelling':
        return Icons.menu_book;
      case 'History':
        return Icons.history_edu;
      case 'Traditional Wear':
        return Icons.checkroom;
      case 'Architecture':
        return Icons.architecture;
      case 'Spiritual Heritage':
        return Icons.temple_buddhist;
      case 'Festival':
        return Icons.celebration;
      default:
        return Icons.category;
    }
  }

  Color _cultureTypeColor(String type) {
    switch (type) {
      case 'Crafts':
        return Colors.brown;
      case 'Music':
        return Colors.deepPurple;
      case 'Dance':
        return Colors.pink;
      case 'Art':
        return Colors.indigo;
      case 'Food Heritage':
        return Colors.deepOrange;
      case 'Storytelling':
        return Colors.blueGrey;
      case 'History':
        return Colors.teal;
      case 'Traditional Wear':
        return Colors.cyan;
      case 'Architecture':
        return Colors.blue;
      case 'Spiritual Heritage':
        return Colors.green;
      case 'Festival':
        return Colors.orange;
      default:
        return ColorPalette.darkGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final listingProvider = Provider.of<ListingProvider>(context);
    final cultureProvider = Provider.of<CultureProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    final eventProvider = Provider.of<EventProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);

    TestChatProvider? chatProvider;
    try {
      chatProvider = Provider.of<TestChatProvider>(context, listen: false);
    } catch (_) {
      chatProvider = null;
    }

    final isMobile = ResponsiveLayout.isMobile(context);
    final fontSize = ResponsiveLayout.getFontSize(context);
    final padding = ResponsiveLayout.getPadding(context);
    final gridCrossAxisCount = ResponsiveLayout.getGridCrossAxisCount(context);
    final isOverview = listingProvider.selectedCategory == 'All';
    final isCultureView = listingProvider.selectedCategory == 'Culture';
    final isEventsView = listingProvider.selectedCategory == 'Upcoming Events';
    final activeOfflineMode = isEventsView
        ? eventProvider.isOfflineMode
        : isCultureView
            ? cultureProvider.isOfflineMode
            : listingProvider.isOfflineMode;
    final activeLastSynced = isEventsView
        ? eventProvider.lastSyncedAt
        : isCultureView
            ? cultureProvider.lastSyncedAt
            : listingProvider.lastSyncedAt;
    final activeLastSyncedLabel = _formatLastSynced(activeLastSynced);
    final activeResultCount = isEventsView
        ? eventProvider.upcomingEvents.length
        : isCultureView
            ? cultureProvider.vendors.length
            : listingProvider.listings.length;
    final activeLoading = isEventsView
        ? eventProvider.isUpcomingLoading
        : isCultureView
            ? cultureProvider.isLoading
            : listingProvider.isLoading;

    return MountainBackground(
      overlayOpacity: 0.08,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const OfflineIndicator(),
                    _buildHeader(
                      context: context,
                      authProvider: authProvider,
                      bookingProvider: bookingProvider,
                      listingProvider: listingProvider,
                      notificationProvider: notificationProvider,
                      locale: locale,
                      chatProvider: chatProvider,
                      isMobile: isMobile,
                      fontSize: fontSize,
                      padding: padding,
                    ),
                    Padding(
                      padding: padding.copyWith(top: 0, bottom: 12),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: locale.translate(
                            'Search destinations...',
                            'Batla mehloli...',
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: ResponsiveLayout.getIconSize(context),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.9),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isMobile ? 12 : 16,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.grey[300] ?? Colors.grey,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: ColorPalette.primaryGreen,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: padding.copyWith(top: 0, bottom: 12),
                      child: _buildDiscoverHero(
                        locale: locale,
                        isOverview: isOverview,
                        listingCount: activeResultCount,
                        fontSize: fontSize,
                      ),
                    ),
                    Padding(
                      padding: padding.copyWith(top: 0, bottom: 10),
                      child: _buildSectionHeading(
                        title: isOverview
                            ? locale.translate(
                                'Browse by Category', 'Batla ka Sehlopha')
                            : _getTranslatedCategory(
                                listingProvider.selectedCategory,
                                locale,
                              ),
                        subtitle: isOverview
                            ? locale.translate(
                                'Pick the kind of experience you want today.',
                                'Khetha mofuta oa boiphihlelo boo u bo batlang kajeno.',
                              )
                            : locale.translate(
                                'Showing places matched to your selected category.',
                                'Ho bonts\'a libaka tse tsamaellanang le sehlopha seo u se khethileng.',
                              ),
                      ),
                    ),
                    SizedBox(
                      height: isMobile ? 48 : 56,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: padding.copyWith(top: 0, bottom: 0),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected =
                              listingProvider.selectedCategory == category;

                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: FilterChip(
                              label: Text(
                                _getTranslatedCategory(category, locale),
                                style: TextStyle(
                                  fontSize: isMobile ? 13 : 15,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (_) {
                                listingProvider.filterByCategory(category);
                                if (category == 'Culture') {
                                  cultureProvider.loadInitial();
                                } else if (category == 'Upcoming Events') {
                                  eventProvider.fetchUpcomingEvents();
                                }
                              },
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.7),
                              selectedColor: ColorPalette.primaryGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? ColorPalette.primaryGreen
                                      : Colors.grey[300] ?? Colors.grey,
                                  width: 1.5,
                                ),
                              ),
                              labelStyle: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 8 : 10,
                              ),
                              elevation: isSelected ? 4 : 1,
                              shadowColor: ColorPalette.primaryGreen
                                  .withValues(alpha: 0.3),
                            ),
                          );
                        },
                      ),
                    ),
                    if (isCultureView)
                      Padding(
                        padding: padding.copyWith(top: 8, bottom: 6),
                        child: SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ...[
                                const {'name': 'All Types', 'slug': 'all'},
                                ...cultureProvider.subcategories
                                    .map((subcategory) => {
                                          'name': subcategory.name,
                                          'slug': subcategory.slug,
                                        }),
                              ].map((item) {
                                final type = item['name']!;
                                final slug = item['slug']!;
                                final selected =
                                    cultureProvider.selectedSubcategorySlug ==
                                        slug;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _cultureTypeIcon(type),
                                          size: 15,
                                          color: selected
                                              ? Colors.white
                                              : _cultureTypeColor(type),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getTranslatedCultureType(
                                              type, locale),
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : _cultureTypeColor(type),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    selected: selected,
                                    onSelected: (_) {
                                      cultureProvider.selectSubcategory(slug);
                                    },
                                    selectedColor: _cultureTypeColor(type),
                                    backgroundColor:
                                        _cultureTypeColor(type).withValues(
                                      alpha: 0.12,
                                    ),
                                    side: BorderSide(
                                      color: _cultureTypeColor(type)
                                          .withValues(alpha: 0.35),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    if (isOverview) ...[
                      Padding(
                        padding: padding.copyWith(top: 0, bottom: 12),
                        child: _buildAiTouristPanel(locale, fontSize),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (isEventsView)
                      Padding(
                        padding: padding.copyWith(top: 0, bottom: 12),
                        child: const UpcomingEventsWidget(
                          title: 'Upcoming Events',
                          limit: 8,
                        ),
                      ),
                    Padding(
                      padding: padding.copyWith(top: 0, bottom: 12),
                      child: isEventsView
                          ? const SizedBox.shrink()
                          : _buildResultsHeader(
                              context: context,
                              locale: locale,
                              listingProvider: listingProvider,
                              cultureProvider: cultureProvider,
                              fontSize: fontSize,
                            ),
                    ),
                    if (activeOfflineMode && activeResultCount > 0)
                      Padding(
                        padding: padding.copyWith(top: 0, bottom: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ColorPalette.primaryGreen
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: ColorPalette.primaryGreen
                                  .withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                color: ColorPalette.darkGreen,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locale.translate(
                                        'Offline mode active',
                                        'Mokgwa wa offline o sebetsa',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: ColorPalette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      locale.translate(
                                        isEventsView
                                            ? 'Showing cached events and syncing again when connection returns.'
                                            : isCultureView
                                                ? 'Showing cached culture results and syncing again when connection returns.'
                                                : 'Showing cached listings and syncing again when connection returns.',
                                        isEventsView
                                            ? 'Re bontsha liketsahalo tse bolokilweng mme re tla hokahanya hape ha inthanete e khutla.'
                                            : isCultureView
                                                ? 'Re bontsha dintlha tsa setso tse bolokilweng mme re tla hokahanya hape ha inthanete e khutla.'
                                                : 'Re bontsha listings tse bolokilweng mme re tla hokahanya hape ha inthanete e khutla.',
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: fontSize - 3,
                                      ),
                                    ),
                                    if (activeLastSyncedLabel != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        locale.translate(
                                          'Last synced: $activeLastSyncedLabel',
                                          'Qetellong e hokahantswe: $activeLastSyncedLabel',
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: fontSize - 4,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (activeLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (isEventsView)
                const SliverToBoxAdapter(child: SizedBox.shrink())
              else if (activeResultCount == 0)
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: SingleChildScrollView(
                    padding: padding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height * 0.48,
                      ),
                      child: _buildEmptyState(
                        context: context,
                        locale: locale,
                        listingProvider: listingProvider,
                        cultureProvider: cultureProvider,
                        fontSize: fontSize,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: padding,
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCrossAxisCount,
                      childAspectRatio: isMobile ? 0.7 : 0.8,
                      crossAxisSpacing: isMobile ? 8 : 12,
                      mainAxisSpacing: isMobile ? 8 : 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (isCultureView) {
                          final vendor = cultureProvider.vendors[index];
                          return CultureVendorCard(
                            vendor: vendor,
                            onTap: () {
                              if (vendor.linkedListingId != null &&
                                  vendor.linkedListingId!.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListingDetailScreen(
                                      listingId: vendor.linkedListingId!,
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CultureVendorDetailScreen(vendor: vendor),
                                ),
                              );
                            },
                          );
                        }

                        final listing = listingProvider.listings[index];
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
                      childCount: isCultureView
                          ? cultureProvider.vendors.length
                          : listingProvider.listings.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: isMobile
            ? BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.favorite),
                    label: 'Wishlist',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.book_online),
                    label: 'Bookings',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.event),
                    label: 'Events',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildAiTouristPanel(LocaleProvider locale, double fontSize) {
    final legacyIntelligence = _mapValue(_aiDashboard?['legacy_intelligence']);
    final peakMonth = _mapValue(legacyIntelligence['peak_month']);
    final topAttractions = _mapList(legacyIntelligence['top_attractions']);
    final topMarkets = _mapList(legacyIntelligence['top_markets']);
    final sentimentHighlights =
        _mapList(legacyIntelligence['sentiment_highlights']);
    final seasonalHotspots =
        _mapList(legacyIntelligence['seasonal_hotspots']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ColorPalette.primaryGreen.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: ColorPalette.darkGreen.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
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
                  Icons.auto_awesome,
                  color: ColorPalette.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.translate(
                        'Recommended for You',
                        'Likgothaletso Tsa Hao',
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      locale.translate(
                        'AI-picked ideas to help you discover Lesotho faster.',
                        'Mehopolo e khethiloeng ke AI ho u thusa ho sibolla Lesotho kapele.',
                      ),
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_aiLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (peakMonth.isNotEmpty ||
                topAttractions.isNotEmpty ||
                topMarkets.isNotEmpty ||
                sentimentHighlights.isNotEmpty) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (peakMonth.isNotEmpty)
                    _buildTouristInsightChip(
                      title: locale.translate('Peak Month', 'Kgwedi e Chesehang'),
                      value:
                          '${peakMonth['month'] ?? '-'} • ${peakMonth['arrivals'] ?? 0}',
                      accent: Colors.deepOrange,
                    ),
                  if (topAttractions.isNotEmpty)
                    _buildTouristInsightChip(
                      title: locale.translate(
                        'Top Attraction',
                        'Sebaka se Tummeng',
                      ),
                      value:
                          '${topAttractions.first['name'] ?? '-'} • ${topAttractions.first['visitors'] ?? 0}',
                      accent: Colors.green,
                    ),
                  if (topMarkets.isNotEmpty)
                    _buildTouristInsightChip(
                      title: locale.translate('Top Market', 'Mmaraka o Moholo'),
                      value:
                          '${topMarkets.first['country'] ?? '-'} • ${topMarkets.first['market_share'] ?? 0}%',
                      accent: Colors.blue,
                    ),
                  if (sentimentHighlights.isNotEmpty)
                    _buildTouristInsightChip(
                      title: locale.translate(
                        'Visitors Love',
                        'Baeti ba Rata',
                      ),
                      value:
                          '${sentimentHighlights.first['label'] ?? '-'} • ${sentimentHighlights.first['percentage'] ?? 0}%',
                      accent: Colors.purple,
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            if (topMarkets.isNotEmpty) ...[
              Text(
                locale.translate('Market Momentum', 'Matla a Mmaraka'),
                style: TextStyle(
                  fontSize: fontSize + 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 126,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: topMarkets.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final market = topMarkets[index];
                    return _buildTouristMarketCard(market);
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (_aiHotspots.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      locale.translate(
                        'Hotspots Right Now',
                        'Libaka Tse Tummeng Hona Jwale',
                      ),
                      style: TextStyle(
                        fontSize: fontSize + 2,
                        fontWeight: FontWeight.w700,
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
                      locale.translate(
                        '${_aiHotspots.length} live picks',
                        '${_aiHotspots.length} dikgetho tsa jwale',
                      ),
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
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _aiHotspots.take(4).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => _buildTouristHotspotCard(
                    hotspot: _aiHotspots[index],
                    locale: locale,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (seasonalHotspots.isNotEmpty) ...[
              Text(
                locale.translate('Seasonal Playbook', 'Moralo wa Dihla'),
                style: TextStyle(
                  fontSize: fontSize + 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 154,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: seasonalHotspots.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final season = seasonalHotspots[index];
                    return _buildTouristSeasonCard(season);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_aiRecommendations.isNotEmpty) ...[
              Text(
                locale.translate(
                    'Suggested Activities', 'Mesebetsi e Sisinywang'),
                style: TextStyle(
                  fontSize: fontSize + 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ..._aiRecommendations.take(3).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildTouristRecommendationCard(
                        item: item,
                        locale: locale,
                      ),
                    ),
                  ),
            ],
            if (false && _aiHotspots.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      locale.translate(
                        'Hotspots Right Now',
                        'Libaka Tse Tummeng Hona Jwale',
                      ),
                      style: TextStyle(
                        fontSize: fontSize + 2,
                        fontWeight: FontWeight.w700,
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
                      locale.translate(
                        '${_aiHotspots.length} live picks',
                        '${_aiHotspots.length} dikgetho tsa jwale',
                      ),
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
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _aiHotspots.take(4).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final hotspot = _aiHotspots[index];
                    return Container(
                      width: 240,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            ColorPalette.primaryGreen,
                            ColorPalette.secondaryGreen,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            hotspot['name']?.toString() ?? 'Hotspot',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${hotspot['district'] ?? ''} • ${hotspot['category'] ?? ''}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Score ${hotspot['score'] ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (false && _aiRecommendations.isNotEmpty) ...[
              Text(
                locale.translate(
                    'Suggested Activities', 'Mesebetsi e Sisinywang'),
                style: TextStyle(
                  fontSize: fontSize + 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ..._aiRecommendations.take(3).map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ColorPalette.lightGreen.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hiking, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name']?.toString() ?? 'Activity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${item['season'] ?? 'Any time'} • popularity ${item['popularity'] ?? 0}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            if (false && _aiHotspots.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                locale.translate('Hotspots Right Now', 'Libaka Tse Chesehang'),
                style: TextStyle(
                  fontSize: fontSize + 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _aiHotspots.take(4).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final hotspot = _aiHotspots[index];
                    return Container(
                      width: 220,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            ColorPalette.primaryGreen,
                            ColorPalette.secondaryGreen,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            hotspot['name']?.toString() ?? 'Hotspot',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${hotspot['district'] ?? ''} • score ${hotspot['score'] ?? 0}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTouristInsightChip({
    required String title,
    required String value,
    required Color accent,
  }) {
    return Container(
      width: 220,
      height: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            accent.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTouristMarketCard(Map<String, dynamic> market) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            ColorPalette.lightGreen.withValues(alpha: 0.34),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ColorPalette.primaryGreen.withValues(alpha: 0.14),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${market['country'] ?? 'Market'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          Text(
            '${market['arrivals'] ?? 0} arrivals',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              Text(
                '${market['market_share'] ?? 0}% share',
                style: const TextStyle(
                  color: ColorPalette.primaryGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '+${market['growth'] ?? 0}%',
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTouristSeasonCard(Map<String, dynamic> season) {
    final places = (season['places'] as List?) ?? const [];
    return Container(
      width: 230,
      height: 138,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            ColorPalette.lightGreen.withValues(alpha: 0.45),
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
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...places.take(3).map(
                (place) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $place',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTouristHotspotCard({
    required Map<String, dynamic> hotspot,
    required LocaleProvider locale,
  }) {
    final name = hotspot['name']?.toString() ?? 'Hotspot';
    final district = hotspot['district']?.toString() ?? 'Lesotho';
    final category = hotspot['category']?.toString() ?? 'Experience';
    final score = hotspot['score']?.toString() ?? '0';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openHotspotDiscovery(hotspot),
        child: Ink(
          width: 252,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorPalette.primaryGreen,
                ColorPalette.secondaryGreen,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: ColorPalette.primaryGreen.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 12),
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
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      locale.translate('Score $score', 'Sekala $score'),
                      style: const TextStyle(
                        color: Colors.white,
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
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$district • $category',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.explore_outlined,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      locale.translate(
                        'Tap to explore this area now',
                        'Tobetsa ho sheba sebaka sena jwale',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTouristRecommendationCard({
    required Map<String, dynamic> item,
    required LocaleProvider locale,
  }) {
    final name = item['name']?.toString() ?? 'Activity';
    final season = item['season']?.toString() ?? 'Any time';
    final popularity = item['popularity']?.toString() ?? '0';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openRecommendationDiscovery(item),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.96),
                ColorPalette.lightGreen.withValues(alpha: 0.52),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ColorPalette.primaryGreen.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: ColorPalette.primaryGreen.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ColorPalette.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.hiking, color: ColorPalette.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locale.translate(
                        '$season • popularity $popularity',
                        '$season • botumo $popularity',
                      ),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  locale.translate('Open', 'Bula'),
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverHero({
    required LocaleProvider locale,
    required bool isOverview,
    required int listingCount,
    required double fontSize,
  }) {
    final title = isOverview
        ? locale.translate(
            'Discover Lesotho Better', 'Fumana Lesotho ka Botle bo Fetang')
        : locale.translate('Filtered Discovery', 'Patlo e Hloekisitsoeng');
    final subtitle = isOverview
        ? locale.translate(
            'Curated places, real events, and trusted local experiences.',
            'Libaka tse hlophisitsoeng, liketsahalo tsa nnete, le maeto a tshepahalang.',
          )
        : locale.translate(
            'You are now exploring a focused category view.',
            'U se u shebile pono e shebaneng le sehlopha se le seng.',
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            ColorPalette.lightGreen.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: ColorPalette.darkGreen.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: fontSize + 3,
                    fontWeight: FontWeight.w800,
                    color: ColorPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    color: ColorPalette.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ColorPalette.darkGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$listingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  locale.translate('Live', 'Phela'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading({
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: ColorPalette.primaryGreen,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsHeader({
    required BuildContext context,
    required LocaleProvider locale,
    required ListingProvider listingProvider,
    required CultureProvider cultureProvider,
    required double fontSize,
  }) {
    final activeCategory = listingProvider.selectedCategory;
    String? selectedCulture;
    if (cultureProvider.selectedSubcategorySlug != 'all') {
      for (final subcategory in cultureProvider.subcategories) {
        if (subcategory.slug == cultureProvider.selectedSubcategorySlug) {
          selectedCulture = subcategory.name;
          break;
        }
      }
    }

    final cultureSuffix =
        (activeCategory == 'Culture' && selectedCulture != null)
            ? ' • $selectedCulture'
            : '';
    final resultsCount = activeCategory == 'Culture'
        ? cultureProvider.vendors.length
        : listingProvider.listings.length;
    final categoryLabel = (activeCategory == 'All'
            ? locale.translate('Overview', 'Kakaretso')
            : _getTranslatedCategory(activeCategory, locale)) +
        cultureSuffix;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ColorPalette.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    color: ColorPalette.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$resultsCount ${locale.translate('places found', 'libaka tse fumane')}',
                        style: TextStyle(
                          fontSize: fontSize,
                          color: ColorPalette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        categoryLabel,
                        style: const TextStyle(
                          color: ColorPalette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: ResponsiveLayout.getIconSize(context) - 2,
                color: ColorPalette.darkGreen,
              ),
              const SizedBox(width: 6),
              Text(
                locale.translate('Filtered', 'E Hloekisitsoe'),
                style: TextStyle(
                  fontSize: fontSize - 2,
                  color: ColorPalette.darkGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required LocaleProvider locale,
    required ListingProvider listingProvider,
    required CultureProvider cultureProvider,
    required double fontSize,
  }) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final hasCategory = listingProvider.selectedCategory != 'All';
    final isCulture = listingProvider.selectedCategory == 'Culture';

    final title = isCulture
        ? locale.translate(
            'No culture vendors match this filter',
            'Ha ho barekisi ba setso ba tsamaellanang le sefefo sena',
          )
        : hasQuery || hasCategory
            ? locale.translate(
                'No places match this filter',
                'Ha ho libaka tse tsamaellanang le patlo ena',
              )
            : locale.translate(
                'No live listings yet',
                'Ha ho lintlha tse phelang hajoale',
              );

    final subtitle = isCulture
        ? locale.translate(
            'Try another culture subtype or search term to discover more vendors.',
            'Leka mofuta o mong oa setso kapa lentsoe le leng la patlo ho fumana barekisi ba bang.',
          )
        : hasQuery || hasCategory
            ? locale.translate(
                'Try another category or clear your search to see more results.',
                'Leka sehlopha se seng kapa u hlakole patlo ho bona tse ling.',
              )
            : locale.translate(
                'Listings from registered users will appear here once they are available.',
                'Lintlha tse tsoang ho basebelisi ba ngolisitsoeng li tla hlaha mona ha li se li fumaneha.',
              );

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ColorPalette.lightGreen,
                    ColorPalette.primaryLight.withValues(alpha: 0.6),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 36,
                color: ColorPalette.darkGreen,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize + 3,
                fontWeight: FontWeight.w800,
                color: ColorPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize - 2,
                color: ColorPalette.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    listingProvider.filterByCategory('All');
                    listingProvider.search('');
                    cultureProvider.selectSubcategory('all');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorPalette.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    locale.translate('Reset Filters', 'Hlophisa Botjha'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    if (isCulture) {
                      cultureProvider.loadInitial();
                    } else {
                      listingProvider.loadListings();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorPalette.darkGreen,
                    side: BorderSide(
                      color: ColorPalette.primaryGreen.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_sync_rounded),
                  label: Text(locale.translate('Try Again', 'Leka Hape')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required AuthProvider authProvider,
    required BookingProvider bookingProvider,
    required ListingProvider listingProvider,
    required NotificationProvider notificationProvider,
    required LocaleProvider locale,
    required TestChatProvider? chatProvider,
    required bool isMobile,
    required double fontSize,
    required EdgeInsets padding,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: 0.18),
            ColorPalette.darkGreen.withValues(alpha: 0.28),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isMobile ? 18 : 24,
            backgroundColor: ColorPalette.primaryGreen,
            child: Text(
              authProvider.user?.name[0] ?? 'U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  authProvider.user?.name ?? 'Explorer',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.22),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WishlistNotificationsScreen(),
                    ),
                  );
                },
                tooltip: 'Notifications',
              ),
              if (notificationProvider.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
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
                      '${notificationProvider.unreadCount}',
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
          Stack(
            children: [
              IconButton(
                icon:
                    const Icon(Icons.chat_bubble_outline, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.22),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatListScreen(),
                    ),
                  );
                },
                tooltip: 'Messages',
              ),
              if (chatProvider != null && chatProvider.totalUnread > 0)
                Positioned(
                  right: 8,
                  top: 8,
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.22),
            ),
            onPressed: () {
              listingProvider.loadListings();
              bookingProvider.refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    locale.translate('Data refreshed', 'Data e nchafatsoe'),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: locale.translate('Refresh', 'Nchafatsa'),
          ),
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.22),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    locale.translate('Select Language', 'Khetha Puo'),
                  ),
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
            tooltip: locale.translate('Change Language', 'Fetola Puo'),
          ),
          IconButton(
            icon: Icon(
              Icons.favorite_border,
              color: Colors.white,
              size: ResponsiveLayout.getIconSize(context),
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.22),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WishlistScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'bookings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyBookingsScreen(),
                  ),
                );
              } else if (value == 'event_tickets') {
                Navigator.pushNamed(context, '/my-event-tickets');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'bookings',
                child: Row(
                  children: [
                    Icon(Icons.book_online),
                    SizedBox(width: 8),
                    Text('My Bookings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'event_tickets',
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number),
                    SizedBox(width: 8),
                    Text('My Event Tickets'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.22),
            ),
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
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
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
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}
