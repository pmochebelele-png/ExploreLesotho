// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import '../../widgets/mountain_background.dart';

class PublicLandingScreen extends StatelessWidget {
  const PublicLandingScreen({super.key});

  static const _blue = Color(0xFF06459B);
  static const _gold = Color(0xFFFFB700);

  void _goToLogin(BuildContext context) => Navigator.pushNamed(context, '/login');
  void _goToRegister(BuildContext context) =>
      Navigator.pushNamed(context, '/register');

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 760;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: MountainBackground(
          overlayOpacity: 0.20,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroSection(
                  isMobile: isMobile,
                  onLogin: () => _goToLogin(context),
                  onRegister: () => _goToRegister(context),
                ),
              ),
              SliverToBoxAdapter(
                child: _PageBand(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WhyExploreGrid(isMobile: isMobile),
                      const SizedBox(height: 54),
                      _SectionHeader(
                        title: 'Top Lesotho stays and experiences',
                        subtitle:
                            'Book mountain lodges, guided adventures, heritage sites, and scenic day trips across the Kingdom in the Sky.',
                        action: 'Explore all',
                        onAction: () => _goToLogin(context),
                      ),
                      const SizedBox(height: 18),
                      _HorizontalCards(
                        isMobile: isMobile,
                        children: _featuredListings
                            .map((item) => _ListingCard(item: item))
                            .toList(),
                      ),
                      const SizedBox(height: 54),
                      _SectionHeader(
                        title: 'Trending destinations in Lesotho',
                        subtitle:
                            'Popular choices for travelers planning from Maseru, the highlands, and nearby border routes.',
                      ),
                      const SizedBox(height: 18),
                      _DestinationGrid(isMobile: isMobile),
                      const SizedBox(height: 54),
                      _SectionHeader(
                        title: 'Browse by tourism type',
                        subtitle:
                            'Find the right experience faster, from accommodation to culture and outdoor adventure.',
                      ),
                      const SizedBox(height: 18),
                      _PropertyTypeGrid(isMobile: isMobile),
                      const SizedBox(height: 54),
                      _DealsBand(onAction: () => _goToLogin(context)),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.isMobile,
    required this.onLogin,
    required this.onRegister,
  });

  final bool isMobile;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return _PageBand(
      top: isMobile ? 18 : 28,
      bottom: isMobile ? 70 : 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopNav(
            isMobile: isMobile,
            onLogin: onLogin,
            onRegister: onRegister,
          ),
          const SizedBox(height: 18),
          _TravelTabs(isMobile: isMobile),
          const SizedBox(height: 18),
          _MarqueeStrip(isMobile: isMobile),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 24 : 42),
            decoration: BoxDecoration(
              color: const Color(0xFF123F43).withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: isMobile
                ? const _HeroCopy(isMobile: true)
                : const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _HeroCopy(isMobile: false),
                      ),
                      SizedBox(width: 42),
                      Expanded(
                        flex: 4,
                        child: _HeroPhotoStack(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find your Lesotho escape',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: isMobile ? 40 : 66,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Search mountain lodges, pony trekking, heritage tours, events, and verified local tourism vendors.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.94),
            fontSize: isMobile ? 18 : 26,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.isMobile,
    required this.onLogin,
    required this.onRegister,
  });

  final bool isMobile;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 14 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF123F43).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.landscape,
                  color: PublicLandingScreen._blue,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Explore Lesotho',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isMobile ? 25 : 32,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _NavTextButton(label: 'Home', onPressed: () {}),
              _NavTextButton(label: 'Destinations', onPressed: () {}),
              _NavTextButton(label: 'List your business', onPressed: onRegister),
              _NavTextButton(label: 'LSL', onPressed: () {}),
              OutlinedButton(
                onPressed: onRegister,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Register'),
              ),
              ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF123F43),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavTextButton extends StatelessWidget {
  const _NavTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }
}

class _MarqueeStrip extends StatelessWidget {
  const _MarqueeStrip({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final items = const [
      _MarqueeData(Icons.verified, 'LTDC-aligned tourism'),
      _MarqueeData(Icons.phone_android, 'Web and mobile ready'),
      _MarqueeData(Icons.auto_awesome, 'Scikit AI insights'),
      _MarqueeData(Icons.storefront, 'Verified local vendors'),
      _MarqueeData(Icons.event_available, 'Events and tickets'),
      _MarqueeData(Icons.landscape, 'Kingdom in the Sky'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items
            .map(
              (item) => Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, color: const Color(0xFFC9EA5A), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TravelTabs extends StatelessWidget {
  const _TravelTabs({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      _TabData(Icons.hotel, 'Stays'),
      _TabData(Icons.hiking, 'Adventures'),
      _TabData(Icons.museum, 'Heritage'),
      _TabData(Icons.event, 'Events'),
      _TabData(Icons.directions_car, 'Tours'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final selected = tab.label == 'Stays';
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: isMobile ? 12 : 16,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: selected ? 0.9 : 0.35),
              ),
              color: selected ? Colors.white.withValues(alpha: 0.10) : null,
            ),
            child: Row(
              children: [
                Icon(tab.icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  tab.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HeroPhotoStack extends StatelessWidget {
  const _HeroPhotoStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: 48,
            child: _RoundedImage(
              imagePath: 'assets/images/tourism_seed/maletsunyane_1.jpg',
              borderRadius: 18,
            ),
          ),
          Positioned(
            left: 0,
            bottom: -24,
            width: 230,
            height: 160,
            child: _RoundedImage(
              imagePath: 'assets/images/tourism_seed/kome_caves_1.jpg',
              borderRadius: 16,
            ),
          ),
          Positioned(
            right: 22,
            top: -20,
            child: _RatingBadge(),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Transform.translate(
        offset: const Offset(0, -50),
        child: Column(
          children: const [
            _SearchField(icon: Icons.search, title: 'Where are you going?'),
            _SearchField(icon: Icons.calendar_month, title: 'Check-in - Check-out'),
            _SearchField(icon: Icons.person, title: '2 adults - 0 children'),
            _SearchButton(),
          ],
        ),
      );
    }

    return Transform.translate(
      offset: const Offset(0, -46),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: PublicLandingScreen._gold,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: const [
              Expanded(
                flex: 4,
                child: _SearchField(
                  icon: Icons.search,
                  title: 'Where in Lesotho are you going?',
                ),
              ),
              Expanded(
                flex: 3,
                child: _SearchField(
                  icon: Icons.calendar_month,
                  title: 'Check-in date - Check-out date',
                ),
              ),
              Expanded(
                flex: 3,
                child: _SearchField(
                  icon: Icons.person,
                  title: '2 adults - 0 children - 1 room',
                ),
              ),
              SizedBox(width: 4),
              SizedBox(width: 180, child: _SearchButton()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 30, color: Colors.black.withValues(alpha: 0.62)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, '/login'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0071E8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        child: const Text('Search'),
      ),
    );
  }
}

class _WhyExploreGrid extends StatelessWidget {
  const _WhyExploreGrid({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final cards = const [
      _WhyData(Icons.verified_user, 'Verified local vendors',
          'Tourism businesses can register and appear for admin approval.'),
      _WhyData(Icons.map, 'Lesotho-first discovery',
          'Find places by district, tourism type, rating, and local highlights.'),
      _WhyData(Icons.forum, 'Bookings and messages',
          'Tourists and vendors can coordinate requests inside the app.'),
      _WhyData(Icons.auto_awesome, 'AI travel insights',
          'Admin dashboards surface recent vendor activity and tourism trends.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Why Explore Lesotho?'),
        const SizedBox(height: 18),
        _ResponsiveGrid(
          isMobile: isMobile,
          minTileWidth: 240,
          children: cards.map((card) => _WhyCard(data: card)).toList(),
        ),
      ],
    );
  }
}

class _HorizontalCards extends StatelessWidget {
  const _HorizontalCards({required this.children, required this.isMobile});

  final List<Widget> children;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: child,
              ),
            )
            .toList(),
      );
    }

    return SizedBox(
      height: 470,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, index) => SizedBox(width: 310, child: children[index]),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.item});

  final _ListingData item;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/login'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.22,
                  child: Image.asset(item.imagePath, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_border, size: 28),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.type,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.62),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.star, size: 17, color: Colors.amber),
                        const Icon(Icons.star, size: 17, color: Colors.amber),
                        const Icon(Icons.star, size: 17, color: Colors.amber),
                        const Icon(Icons.star, size: 17, color: Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: PublicLandingScreen._blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.rating,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${item.reviewText}\n${item.reviewCount} reviews',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.70),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text.rich(
                        TextSpan(
                          text: 'Starting from ',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.55),
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: 'LSL ${item.price}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationGrid extends StatelessWidget {
  const _DestinationGrid({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      _DestinationData('Maseru', 'assets/images/tourism_seed/thaba_bosiu_1.jpg',
          'Culture, food, business stays'),
      _DestinationData('Semonkong',
          'assets/images/tourism_seed/maletsunyane_1.jpg', 'Falls and pony treks'),
      _DestinationData('Butha-Buthe', 'assets/images/tourism_seed/maliba_1.jpg',
          'Luxury lodges and parks'),
      _DestinationData('Thaba-Tseka',
          'assets/images/tourism_seed/katse_dam_1.jpg', 'Katse Dam routes'),
      _DestinationData('Qacha\'s Nek',
          'assets/images/tourism_seed/sani_pass_1.jpg', 'Highland pass tours'),
    ];

    return _ResponsiveGrid(
      isMobile: isMobile,
      minTileWidth: isMobile ? 260 : 360,
      children: destinations
          .map((item) => _DestinationCard(item: item))
          .toList(),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.item});

  final _DestinationData item;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/login'),
        child: AspectRatio(
          aspectRatio: 2.2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(item.imagePath, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent, Colors.black45],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.title}  LS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyTypeGrid extends StatelessWidget {
  const _PropertyTypeGrid({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final types = const [
      _TypeData('Hotels', 'assets/images/tourism_seed/avani_maseru_1.jpg'),
      _TypeData('Lodges', 'assets/images/tourism_seed/semonkong_lodge_1.jpg'),
      _TypeData('Resorts', 'assets/images/tourism_seed/afriski_1.jpg'),
      _TypeData('Tours', 'assets/images/tourism_seed/pony_trekking_1.jpg'),
      _TypeData('Heritage', 'assets/images/tourism_seed/kome_caves_1.jpg'),
      _TypeData('Scenic sites', 'assets/images/tourism_seed/bokong_1.jpg'),
    ];

    return _ResponsiveGrid(
      isMobile: isMobile,
      minTileWidth: 230,
      children: types.map((item) => _TypeCard(item: item)).toList(),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.item});

  final _TypeData item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/login'),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 1.7,
              child: Image.asset(item.imagePath, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _DealsBand extends StatelessWidget {
  const _DealsBand({required this.onAction});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Travel more, support local',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  'Register or sign in to book trusted Lesotho tourism services and help local vendors grow.',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.72),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: PublicLandingScreen._blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

class _PageBand extends StatelessWidget {
  const _PageBand({
    required this.child,
    this.top = 0,
    this.bottom = 0,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1660),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            width < 760 ? 16 : 64,
            top,
            width < 760 ? 16 : 64,
            bottom,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.children,
    required this.isMobile,
    required this.minTileWidth,
  });

  final List<Widget> children;
  final bool isMobile;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = isMobile
            ? 1
            : (constraints.maxWidth / minTileWidth)
                .floor()
                .clamp(2, 4)
                .toInt();
        return GridView.count(
          crossAxisCount: count,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 18,
          mainAxisSpacing: 18,
          childAspectRatio: minTileWidth > 320 ? 2.2 : 1.35,
          children: children,
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.66),
                    fontSize: 18,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                color: PublicLandingScreen._blue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.data});

  final _WhyData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: PublicLandingScreen._blue, size: 42),
          const Spacer(),
          Text(
            data.title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            data.body,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.70),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundedImage extends StatelessWidget {
  const _RoundedImage({required this.imagePath, required this.borderRadius});

  final String imagePath;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(imagePath, fit: BoxFit.cover),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.star, color: Colors.amber),
          SizedBox(width: 8),
          Text(
            '4.8 guest rated',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _TabData {
  const _TabData(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _MarqueeData {
  const _MarqueeData(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _WhyData {
  const _WhyData(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _ListingData {
  const _ListingData({
    required this.title,
    required this.location,
    required this.type,
    required this.imagePath,
    required this.rating,
    required this.reviewText,
    required this.reviewCount,
    required this.price,
  });

  final String title;
  final String location;
  final String type;
  final String imagePath;
  final String rating;
  final String reviewText;
  final int reviewCount;
  final String price;
}

class _DestinationData {
  const _DestinationData(this.title, this.imagePath, this.subtitle);
  final String title;
  final String imagePath;
  final String subtitle;
}

class _TypeData {
  const _TypeData(this.title, this.imagePath);
  final String title;
  final String imagePath;
}

const _featuredListings = [
  _ListingData(
    title: 'Maliba Lodge',
    location: 'Ts\'ehlanyane National Park, Butha-Buthe',
    type: 'Lodge',
    imagePath: 'assets/images/tourism_seed/maliba_1.jpg',
    rating: '9.4',
    reviewText: 'Wonderful',
    reviewCount: 124,
    price: '1,850',
  ),
  _ListingData(
    title: 'Afriski Mountain Resort',
    location: 'Oxbow, Butha-Buthe',
    type: 'Resort',
    imagePath: 'assets/images/tourism_seed/afriski_1.jpg',
    rating: '9.1',
    reviewText: 'Excellent',
    reviewCount: 98,
    price: '750',
  ),
  _ListingData(
    title: 'Sani Pass 4x4 Experience',
    location: 'Qacha\'s Nek highlands',
    type: 'Tour',
    imagePath: 'assets/images/tourism_seed/sani_pass_1.jpg',
    rating: '9.6',
    reviewText: 'Exceptional',
    reviewCount: 87,
    price: '950',
  ),
  _ListingData(
    title: 'Semonkong Lodge',
    location: 'Semonkong, Maseru District',
    type: 'Lodge',
    imagePath: 'assets/images/tourism_seed/semonkong_lodge_1.jpg',
    rating: '8.8',
    reviewText: 'Very good',
    reviewCount: 73,
    price: '920',
  ),
  _ListingData(
    title: 'Katse Dam Scenic Tour',
    location: 'Katse, Thaba-Tseka',
    type: 'Scenic tour',
    imagePath: 'assets/images/tourism_seed/katse_dam_1.jpg',
    rating: '8.9',
    reviewText: 'Excellent',
    reviewCount: 76,
    price: '520',
  ),
];
