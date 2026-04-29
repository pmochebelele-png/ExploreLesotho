import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/listing.dart';
import '../../services/listing_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/listing_card.dart';
// Ensure these screens exist or comment them out if not yet created
import '../bookings/my_bookings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ListingService _listingService = ListingService();
  List<Listing> _popularListings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPopularListings();
  }

  Future<void> _loadPopularListings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _listingService.getPopularListings();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _popularListings = result['listings'];
        } else {
          _error = result['error'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Accessing AuthProvider to get user details and logout method
    final authProvider = Provider.of<AuthProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Lesotho'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) async {
              if (value == 'logout') {
                await authProvider.logout();
                if (mounted) {
                  // Redirect to root so AuthWrapper can handle the switch to Login
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                }
              } else if (value == 'bookings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MyBookingsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'bookings',
                child: Row(
                  children: [
                    const Icon(Icons.book_online, size: 20),
                    const SizedBox(width: 8),
                    Text(locale.translate('My Bookings', 'Lipehelo tsa Ka')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(locale.translate('Logout', 'Tsoa'), style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPopularListings,
        child: CustomScrollView(
          slivers: [
            // Welcome Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.translate('Rea u amohela! 👋', 'Rea u amohela! 👋'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locale.translate('Welcome back, ${user?.name ?? 'Guest'}', 'Rea u amohela hape, ${user?.name ?? 'Moeti'}'),
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: locale.translate('Search experiences...', 'Batla liphihlelo...'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ),

            // Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  locale.translate('Popular in Lesotho', 'Tse Tummeng Lesotho'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Listings Content
            _isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                    ? SliverFillRemaining(
                        child: _buildErrorWidget(),
                      )
                    : _popularListings.isEmpty
                        ? SliverFillRemaining(
                            child: Center(child: Text(locale.translate('No listings available', 'Ha ho lintlha tse fumanehang'))),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return ListingCard(
                                  listing: _popularListings[index],
                                  onTap: () {
                                    // Handle navigation to details here
                                  },
                                );
                              },
                              childCount: _popularListings.length,
                            ),
                          ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final locale = Provider.of<LocaleProvider>(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          ElevatedButton(
            onPressed: _loadPopularListings,
            child: Text(locale.translate('Try Again', 'Leka Hape')),
          ),
        ],
      ),
    );
  }
}
