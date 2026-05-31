import '../../widgets/admin/advanced_stats_grid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/admin_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/test_chat_provider.dart';
import '../../core/themes/color_palette.dart';
import '../../models/user.dart';
import '../../data/models/vendor.dart';
import '../../models/review.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/mountain_background.dart';
import '../analytics/ai_insights_dashboard.dart';
import '../chat/chat_list_screen.dart';
import '../chat/new_message_screen.dart';
import '../auth/login_screen.dart';
import '../../utils/responsive_layout.dart';
import 'culture_directory_review_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _overviewScrollController = ScrollController();
  bool _popupShown = false;
  bool _requestedInitialAdminLoad = false;

  final TextEditingController _addNameController = TextEditingController();
  final TextEditingController _addEmailController = TextEditingController();
  final TextEditingController _addBusinessNameController =
      TextEditingController();
  final TextEditingController _addPasswordController = TextEditingController();
  String _selectedRole = 'tourist';
  bool _isVerified = false;
  User? _editingUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _popupShown = false;
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _requestedInitialAdminLoad) return;
      _requestedInitialAdminLoad = true;
      context.read<AdminProvider>().fetchAllAdminData();
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging && _tabController.index == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdminProvider>().fetchReviewsSafe();
      });
    }
  }

  void _showChatUnreadDialog(BuildContext context, int unreadCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.read<LocaleProvider>().translate(
              'Unread Messages',
              'Melaetsa e sa Baloang',
            )),
        content: Text(context.read<LocaleProvider>().translate(
              'You have $unreadCount unread messages. Would you like to view them now?',
              'U na le melaetsa e $unreadCount e sa baloang. Na u ka rata ho e bona hona joale?',
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.read<LocaleProvider>().translate(
                  'Later',
                  'Hamorao',
                )),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatListScreen(),
                ),
              );
            },
            child: Text(context.read<LocaleProvider>().translate(
                  'View Messages',
                  'Bona Melaetsa',
                )),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _overviewScrollController.dispose();
    _addNameController.dispose();
    _addEmailController.dispose();
    _addBusinessNameController.dispose();
    _addPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    final adminProvider = Provider.of<AdminProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Safely get TestChatProvider (it might not be available)
    TestChatProvider? chatProvider;
    try {
      chatProvider = Provider.of<TestChatProvider>(context, listen: false);
    } catch (e) {
      // Provider not found, handle gracefully
    }

    final stats = adminProvider.getPlatformStats();
    final isMobile = ResponsiveLayout.isMobile(context);
    final fontSize = ResponsiveLayout.getFontSize(context);
    final padding = ResponsiveLayout.getPadding(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatProvider != null &&
          chatProvider.totalUnread > 0 &&
          ModalRoute.of(context)?.isCurrent == true &&
          !_popupShown) {
        _popupShown = true;
        _showChatUnreadDialog(context, chatProvider.totalUnread);
      }
    });

    return MountainBackground(
      overlayOpacity: 0.25,
      child: Scaffold(
        appBar: AppBar(
          title: Text(locale.translate(
            'Admin Dashboard',
            'Letlapa la Molaoli',
          )),
          backgroundColor: ColorPalette.primaryGreen,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                  icon: const Icon(Icons.dashboard),
                  text: locale.translate('Overview', 'Kakaretso')),
              Tab(
                  icon: const Icon(Icons.people),
                  text: locale.translate('Users', 'Basebelisi')),
              Tab(
                  icon: const Icon(Icons.store),
                  text: locale.translate('Vendors', 'Barekisi')),
              Tab(
                  icon: const Icon(Icons.rate_review),
                  text: locale.translate('Reviews', 'Maikutlo')),
              Tab(
                  icon: const Icon(Icons.museum),
                  text:
                      locale.translate('Culture Review', 'Tlhahlobo ea Setso')),
              Tab(
                  icon: const Icon(Icons.assessment),
                  text: locale.translate('Reports', 'Litlaleho')),
              Tab(
                  icon: const Icon(Icons.auto_awesome),
                  text: locale.translate('AI Insights', 'Tlhahlobo ea AI')),
            ],
          ),
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
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ChatListScreen()));
                  },
                  tooltip: locale.translate('Messages', 'Melaetsa'),
                ),
                if (chatProvider != null && chatProvider.totalUnread > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('${chatProvider.totalUnread}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => adminProvider.refresh(),
                tooltip: locale.translate('Refresh', 'Nchafatsa')),
            IconButton(
              icon: const Icon(Icons.switch_account),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(locale.translate(
                        'Use the role switcher at the top',
                        'Sebelisa sesebelisoa sa ho fetola karolo ka holimo'))));
              },
              tooltip: locale.translate('Switch Role', 'Fetola Karolo'),
            ),
            // LOGOUT BUTTON
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
        ),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(context, locale, adminProvider, stats,
                    chatProvider, isMobile, fontSize, padding),
                _buildUsersTab(context, locale, adminProvider),
                _buildVendorsTab(context, locale, adminProvider),
                _buildReviewsTab(context, locale, adminProvider),
                const CultureDirectoryReviewScreen(),
                _buildReportsTab(context, locale, adminProvider),
                const AIInsightsDashboard(),
              ],
            ),
            if (adminProvider.isLoading && _tabController.index != 6)
              const Positioned(
                top: 16,
                right: 16,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
      BuildContext context,
      LocaleProvider locale,
      AdminProvider provider,
      Map<String, dynamic> stats,
      TestChatProvider? chatProvider,
      bool isMobile,
      double fontSize,
      EdgeInsets padding) {
    return Scrollbar(
      controller: _overviewScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _overviewScrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    ColorPalette.primaryGreen,
                    ColorPalette.secondaryGreen
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      locale.translate(
                          'Welcome, Admin!', 'Rea u amohela, Molaoli!'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      locale.translate('Manage your platform effectively',
                          'Laola sethala sa hao hantle'),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                          radius: isMobile ? 18 : 24,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                              Provider.of<AuthProvider>(context)
                                      .user
                                      ?.name[0] ??
                                  'A',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 14 : 16))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                locale.translate(
                                    'Logged in as,', 'U kene joaloka,'),
                                style: TextStyle(
                                    fontSize: fontSize - 2,
                                    color: Colors.white70)),
                            Text(
                                Provider.of<AuthProvider>(context).user?.role ==
                                        'admin'
                                    ? 'Admin'
                                    : (Provider.of<AuthProvider>(context)
                                            .user
                                            ?.name ??
                                        'User'),
                                style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ChatListScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                              chatProvider != null &&
                                      chatProvider.totalUnread > 0
                                  ? locale.translate(
                                      '${chatProvider.totalUnread} unread messages',
                                      'Melaetsa e sa baloang e ${chatProvider.totalUnread}')
                                  : locale.translate('No unread messages',
                                      'Ha ho melaetsa e mecha'),
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(locale.translate('Platform Overview', 'Kakaretso ea Sethala'),
              style: _brightHeadingStyle(20)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _buildMetricCard(
                  title: locale.translate('Total Users', 'Basebelisi'),
                  value: '${stats['totalUsers']}',
                  icon: Icons.people,
                  color: Colors.blue),
              _buildMetricCard(
                  title: locale.translate('Total Vendors', 'Barekisi'),
                  value: '${stats['totalVendors']}',
                  icon: Icons.store,
                  color: Colors.green),
              _buildMetricCard(
                  title: locale.translate('Total Bookings', 'Lipehelo'),
                  value: '${stats['totalBookings']}',
                  icon: Icons.book_online,
                  color: Colors.orange),
              _buildMetricCard(
                  title: locale.translate('Total Revenue', 'Lekeno'),
                  value: 'M${stats['totalRevenue']}',
                  icon: Icons.attach_money,
                  color: Colors.purple),
            ],
          ),
          const SizedBox(height: 20),
          Text(
              locale.translate(
                  'Additional Insights', 'Lintlha Tse Eketsehileng'),
              style: _brightHeadingStyle(18)),
          const SizedBox(height: 12),
          const AdvancedStatsGrid(),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          locale.translate(
                              'Pending Approvals', 'Tse Emaetseng Tumello'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                              '${stats['pendingVendors'] + stats['pendingReviews']}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.store, color: Colors.orange)),
                    title: Text(
                        locale.translate(
                            'Vendor Applications', 'Likopo tsa Barekisi'),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Text('${stats['pendingVendors']}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () => _tabController.animateTo(2),
                  ),
                  ListTile(
                    leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.rate_review,
                            color: Colors.orange)),
                    title: Text(
                        locale.translate('Live Reviews', 'Maikutlo a Phelang'),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Text('${provider.reviews.length}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () => _tabController.animateTo(3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(locale.translate('Quick Actions', 'Liketso tse Potlakileng'),
              style: _brightHeadingStyle(18)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildActionCard(
                      icon: Icons.chat,
                      label: locale.translate('Messages', 'Melaetsa'),
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ChatListScreen())))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildActionCard(
                      icon: Icons.person_add,
                      label: locale.translate('Add User', 'Kenya Mosebelisi'),
                      color: Colors.blue,
                      onTap: () => _showAddUserDialog(context, locale))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildActionCard(
                      icon: Icons.download,
                      label: locale.translate('Export Data', 'Lumella Datha'),
                      color: Colors.green,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(locale.translate(
                                'Export started...', 'Ho qala ho export...'))));
                      })),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildActionCard(
                      icon: Icons.support_agent,
                      label: locale.translate('Support', 'Thuso'),
                      color: Colors.orange,
                      onTap: () {})),
            ],
          ),
        ],
        ),
      ),
    );
  }

  TextStyle _brightHeadingStyle(double fontSize) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      shadows: const [
        Shadow(
          color: Colors.black54,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      {required String title,
      required String value,
      required IconData icon,
      required Color color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 12),
            Text(value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
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
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[800])),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, LocaleProvider locale) {
    _addNameController.clear();
    _addEmailController.clear();
    _addBusinessNameController.clear();
    _addPasswordController.clear();
    _selectedRole = 'tourist';
    _isVerified = false;
    _editingUser = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
                locale.translate('Add New User', 'Kenya Mosebelisi e Mocha')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: _addNameController,
                      decoration: InputDecoration(
                          labelText: locale.translate(
                              'Full Name', 'Lebitso le Felletseng'),
                          border: const OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _addEmailController,
                      decoration: InputDecoration(
                          labelText: locale.translate('Email', 'Email'),
                          border: const OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _addPasswordController,
                      decoration: InputDecoration(
                          labelText: locale.translate('Password', 'Phasewete'),
                          border: const OutlineInputBorder()),
                      obscureText: true),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: InputDecoration(
                        labelText: locale.translate('Role', 'Karolo'),
                        border: const OutlineInputBorder()),
                    items: ['tourist', 'vendor', 'admin']
                        .map((role) => DropdownMenuItem(
                            value: role, child: Text(role.toUpperCase())))
                        .toList(),
                    onChanged: (String? newValue) =>
                        setState(() => _selectedRole = newValue!),
                  ),
                  if (_selectedRole == 'vendor') ...[
                    const SizedBox(height: 12),
                    TextField(
                        controller: _addBusinessNameController,
                        decoration: InputDecoration(
                            labelText: locale.translate(
                                'Business Name', 'Lebitso la Khoebo'),
                            border: const OutlineInputBorder())),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                      title: Text(locale.translate('Verified', 'Netefalitsoe')),
                      value: _isVerified,
                      onChanged: (value) => setState(() => _isVerified = value),
                      contentPadding: EdgeInsets.zero),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(locale.translate('Cancel', 'Hlakola'))),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final success =
                      await Provider.of<AdminProvider>(context, listen: false)
                          .createUser({
                    'full_name': _addNameController.text,
                    'email': _addEmailController.text,
                    'password': _addPasswordController.text,
                    'role': _selectedRole,
                    'business_name': _addBusinessNameController.text,
                    'verified': _isVerified,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success
                          ? locale.translate('User created successfully',
                              'Mosebelisi o entsoe ka katleho')
                          : locale.translate('Failed to create user',
                              'Ho theha mosebelisi ho hlolehile')),
                      backgroundColor: success ? Colors.green : Colors.red));
                },
                child: Text(locale.translate('Create', 'Kenya')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditUserDialog(
      BuildContext context, LocaleProvider locale, User user) {
    _addNameController.text = user.name;
    _addEmailController.text = user.email;
    _addBusinessNameController.text = user.businessName ?? '';
    _addPasswordController.clear();
    _selectedRole = user.role;
    _isVerified = user.verified;
    _editingUser = user;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(locale.translate('Edit User', 'Fetola Mosebelisi')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: _addNameController,
                      decoration: InputDecoration(
                          labelText: locale.translate(
                              'Full Name', 'Lebitso le Felletseng'),
                          border: const OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _addEmailController,
                      decoration: InputDecoration(
                          labelText: locale.translate('Email', 'Email'),
                          border: const OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _addPasswordController,
                      decoration: InputDecoration(
                          labelText: locale.translate('New Password (optional)',
                              'Phasewete e Ncha (boikhethelo)'),
                          border: const OutlineInputBorder(),
                          hintText: locale.translate(
                              'Leave blank to keep current',
                              'Tlohela e se na letho ho boloka ea hona joale')),
                      obscureText: true),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: InputDecoration(
                        labelText: locale.translate('Role', 'Karolo'),
                        border: const OutlineInputBorder()),
                    items: ['tourist', 'vendor', 'admin']
                        .map((role) => DropdownMenuItem(
                            value: role, child: Text(role.toUpperCase())))
                        .toList(),
                    onChanged: (String? newValue) =>
                        setState(() => _selectedRole = newValue!),
                  ),
                  if (_selectedRole == 'vendor') ...[
                    const SizedBox(height: 12),
                    TextField(
                        controller: _addBusinessNameController,
                        decoration: InputDecoration(
                            labelText: locale.translate(
                                'Business Name', 'Lebitso la Khoebo'),
                            border: const OutlineInputBorder())),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                      title: Text(locale.translate('Verified', 'Netefalitsoe')),
                      value: _isVerified,
                      onChanged: (value) => setState(() => _isVerified = value),
                      contentPadding: EdgeInsets.zero),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(locale.translate('Cancel', 'Hlakola'))),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final userData = {
                    'full_name': _addNameController.text,
                    'email': _addEmailController.text,
                    'role': _selectedRole,
                    'business_name': _addBusinessNameController.text,
                    'verified': _isVerified,
                  };
                  if (_addPasswordController.text.isNotEmpty)
                    userData['password'] = _addPasswordController.text;
                  final success =
                      await Provider.of<AdminProvider>(context, listen: false)
                          .updateUser(user.id, userData);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success
                          ? locale.translate('User updated successfully',
                              'Mosebelisi o ntlafalitsoe ka katleho')
                          : locale.translate('Failed to update user',
                              'Ho ntlafatsa mosebelisi ho hlolehile')),
                      backgroundColor: success ? Colors.green : Colors.red));
                },
                child: Text(locale.translate('Update', 'Ntlafatsa')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUsersTab(
      BuildContext context, LocaleProvider locale, AdminProvider provider) {
    final filteredUsers = _searchController.text.isEmpty
        ? provider.users
        : provider.users
            .where((user) =>
                user.name
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()) ||
                user.email
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()) ||
                (user.businessName
                        ?.toLowerCase()
                        .contains(_searchController.text.toLowerCase()) ??
                    false))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText:
                  locale.translate('Search users...', 'Batla basebelisi...'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey[100],
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      })
                  : null,
            ),
            onChanged: (value) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                  child: _buildUserStatCard(
                      title: locale.translate('Total', 'Kakaretso'),
                      value: '${provider.users.length}',
                      color: Colors.blue)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildUserStatCard(
                      title: locale.translate('Vendors', 'Barekisi'),
                      value:
                          '${provider.users.where((u) => u.isVendor).length}',
                      color: Colors.orange)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildUserStatCard(
                      title: locale.translate('Tourists', 'Bahahlauli'),
                      value:
                          '${provider.users.where((u) => u.isTourist).length}',
                      color: Colors.green)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filteredUsers.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                          locale.translate('No users found',
                              'Ha ho basebelisi ba fumanoeng'),
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]))
                    ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                _getRoleColor(user.role).withOpacity(0.1),
                            child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: _getRoleColor(user.role),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))),
                        title: Row(
                          children: [
                            Expanded(
                                child: Text(user.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: _getRoleColor(user.role)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text(user.role.toString(),
                                    style: TextStyle(
                                        color: _getRoleColor(user.role),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            if (user.verified)
                              const Icon(Icons.verified,
                                  color: Colors.green, size: 16),
                            if (user.isSuspended)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                      locale.translate(
                                          'Suspended', 'Emisitsoe'),
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.red))),
                          ],
                        ),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email,
                                  style: const TextStyle(fontSize: 12)),
                              if (user.businessName != null)
                                Text(user.businessName!,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]))
                            ]),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) =>
                              _handleUserAction(context, value, user, locale),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                    leading:
                                        Icon(Icons.edit, color: Colors.blue),
                                    title: Text('Edit'))),
                            PopupMenuItem(
                                value: 'suspend',
                                child: ListTile(
                                    leading: const Icon(Icons.block,
                                        color: Colors.orange),
                                    title: Text(user.isSuspended
                                        ? 'Activate'
                                        : 'Suspend'))),
                            if (!user.isAdmin)
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                      leading:
                                          Icon(Icons.delete, color: Colors.red),
                                      title: Text('Delete'))),
                            if (user.isVendor && !user.verified)
                              const PopupMenuItem(
                                  value: 'approve',
                                  child: ListTile(
                                      leading: Icon(Icons.check_circle,
                                          color: Colors.green),
                                      title: Text('Approve Vendor'))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserStatCard(
      {required String title, required String value, required Color color}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'vendor':
        return Colors.blue;
      case 'tourist':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _handleUserAction(BuildContext context, String action, User user,
      LocaleProvider locale) async {
    final provider = Provider.of<AdminProvider>(context, listen: false);
    switch (action) {
      case 'edit':
        _showEditUserDialog(context, locale, user);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: Text(
                        locale.translate('Delete User', 'Hlakola Mosebelisi')),
                    content: Text(locale.translate(
                        'Are you sure you want to delete ${user.name}? This action cannot be undone.',
                        'Na u netefatsa hore u batla ho hlakola ${user.name}? Ketso ena e ke ke ea khutlisoa.')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(locale.translate('Cancel', 'Hlakola'))),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: Text(locale.translate('Delete', 'Hlakola')))
                    ]));
        if (confirm == true) {
          final success = await provider.deleteUser(user.id);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(success
                  ? locale.translate('User deleted', 'Mosebelisi o hlakotsoe')
                  : locale.translate(
                      'Delete failed', 'Ho hlakola ho hlolehile')),
              backgroundColor: success ? Colors.red : Colors.grey));
        }
        break;
      case 'suspend':
        final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: Text(locale.translate(
                        user.isSuspended ? 'Activate User' : 'Suspend User',
                        user.isSuspended
                            ? 'Aktifatsa Mosebelisi'
                            : 'Emisa Mosebelisi')),
                    content: Text(locale.translate(
                        user.isSuspended
                            ? 'Are you sure you want to activate ${user.name}?'
                            : 'Are you sure you want to suspend ${user.name}?',
                        user.isSuspended
                            ? 'Na u netefatsa hore u batla ho aktifatsa ${user.name}?'
                            : 'Na u netefatsa hore u batla ho emisa ${user.name}?')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(locale.translate('Cancel', 'Hlakola'))),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.orange),
                          child: Text(locale.translate(
                              user.isSuspended ? 'Activate' : 'Suspend',
                              user.isSuspended ? 'Aktifatsa' : 'Emisa')))
                    ]));
        if (confirm == true) {
          final success = await provider.suspendUser(user.id);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(success
                  ? locale.translate(
                      user.isSuspended ? 'User activated' : 'User suspended',
                      user.isSuspended
                          ? 'Mosebelisi o aktifisitsoe'
                          : 'Mosebelisi o emisitsoe')
                  : locale.translate('Action failed', 'Ketso e hlolehile')),
              backgroundColor: success ? Colors.orange : Colors.grey));
        }
        break;
      case 'approve':
        final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: Text(
                        locale.translate('Approve Vendor', 'Lumela Morekisi')),
                    content: Text(locale.translate(
                        'Are you sure you want to approve ${user.name} as a vendor?',
                        'Na u netefatsa hore u batla ho lumela ${user.name} joalo ka morekisi?')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(locale.translate('Cancel', 'Hlakola'))),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.green),
                          child: Text(locale.translate('Approve', 'Lumela')))
                    ]));
        if (confirm == true) {
          final success = await provider.approveVendor(user.id);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(success
                  ? locale.translate('Vendor approved', 'Morekisi o amohetsoe')
                  : locale.translate(
                      'Approval failed', 'Ho amohela ho hlolehile')),
              backgroundColor: success ? Colors.green : Colors.grey));
        }
        break;
    }
  }

  Widget _buildVendorsTab(
      BuildContext context, LocaleProvider locale, AdminProvider provider) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await provider.fetchVendors();
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(locale.translate(
                              'Refreshing vendors...',
                              'Ho nchafatsa barekisi...')),
                          duration: const Duration(seconds: 1)));
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(locale.translate('Refresh', 'Nchafatsa')),
                ),
              ],
            ),
          ),
          TabBar(
            tabs: [
              Tab(text: locale.translate('All Vendors', 'Barekisi Bohle')),
              Tab(text: locale.translate('Pending Approval', 'Ba Emaetseng')),
              Tab(text: locale.translate('Approved Vendors', 'Ba Amohetsoeng')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildVendorList(provider.vendors, locale, context, provider),
                _buildVendorList(
                    provider.vendors.where((v) => !v.isVerified).toList(),
                    locale,
                    context,
                    provider,
                    pendingOnly: true),
                _buildVendorList(
                    provider.vendors.where((v) => v.isVerified).toList(),
                    locale,
                    context,
                    provider,
                    approvedOnly: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorList(List<Vendor> vendors, LocaleProvider locale,
      BuildContext context, AdminProvider provider,
      {bool pendingOnly = false, bool approvedOnly = false}) {
    final vendorList = vendors ?? [];

    if (vendorList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              pendingOnly
                  ? locale.translate(
                      'No pending vendors', 'Ha ho barekisi ba emetseng')
                  : approvedOnly
                      ? locale.translate('No approved vendors',
                          'Ha ho barekisi ba amohetsoeng')
                      : locale.translate('No vendors found', 'Ha ho barekisi'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Try tapping Refresh',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vendorList.length,
      itemBuilder: (context, index) {
        final vendor = vendorList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
                backgroundColor:
                    vendor.isVerified ? Colors.green : Colors.orange,
                child: Text(vendor.businessName[0])),
            title: Text(vendor.businessName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle:
                Text(vendor.businessEmail ?? vendor.ownerEmail ?? 'No email'),
            trailing: vendor.isVerified
                ? const Icon(Icons.verified, color: Colors.green)
                : const Icon(Icons.pending, color: Colors.orange),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(Icons.category,
                        '${locale.translate('Type', 'Mofuta')}: ${vendor.businessType ?? 'N/A'}'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.phone,
                        '${locale.translate('Phone', 'Mohala')}: ${vendor.businessPhone ?? 'N/A'}'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.location_on,
                        '${locale.translate('Address', 'Aterese')}: ${vendor.businessAddress ?? 'N/A'}'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.person,
                        '${locale.translate('Owner', 'Mong\'a Khoebo')}: ${vendor.ownerName}'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.calendar_today,
                        '${locale.translate('Joined', 'Kene')}: ${_formatDate(vendor.joinedAt)}'),
                    if (vendor.userId > 0) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final started = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewMessageScreen(
                                  title: locale.translate(
                                    'Message Vendor',
                                    'Romela molaetsa ho morekisi',
                                  ),
                                  allowedRoles: const {'vendor'},
                                  initialRecipientId: vendor.userId.toString(),
                                  initialRecipientName: vendor.businessName,
                                  lockRecipient: true,
                                ),
                              ),
                            );
                            if (!context.mounted || started != true) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  locale.translate(
                                    'Conversation started with vendor',
                                    'Puisano e qalile le morekisi',
                                  ),
                                ),
                                backgroundColor: ColorPalette.primaryGreen,
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_outlined),
                          label: Text(
                            locale.translate(
                              'Message Vendor',
                              'Romela molaetsa',
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (!vendor.isVerified) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              onPressed: () async {
                                final success =
                                    await provider.approveVendor(vendor.id);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                        SnackBar(
                                            content: Text(success
                                                ? locale.translate(
                                                    'Vendor approved',
                                                    'Morekisi o amohetsoe')
                                                : locale.translate(
                                                    'Approval failed',
                                                    'Ho amohela ho hlolehile')),
                                            backgroundColor: success
                                                ? Colors.green
                                                : Colors.grey));
                              },
                              text: locale.translate('Approve', 'Lumela'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final success =
                                    await provider.rejectVendor(vendor.id);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                        SnackBar(
                                            content: Text(success
                                                ? locale.translate(
                                                    'Vendor rejected',
                                                    'Morekisi o hanngoe')
                                                : locale.translate(
                                                    'Rejection failed',
                                                    'Ho hana ho hlolehile')),
                                            backgroundColor: success
                                                ? Colors.red
                                                : Colors.grey));
                              },
                              child: Text(locale.translate('Reject', 'Hana')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Widget _buildReviewsTab(
      BuildContext context, LocaleProvider locale, AdminProvider provider) {
    if (provider.reviews.isEmpty && !provider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdminProvider>().fetchReviewsSafe();
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await provider.fetchReviewsSafe();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(locale.translate('Refreshing reviews...',
                            'Ho nchafatsa maikutlo...')),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(locale.translate('Refresh', 'Nchafatsa')),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildReviewsList(provider.reviews, locale, context),
        ),
      ],
    );
  }

  Widget _buildReviewsList(
      List<Review> reviews, LocaleProvider locale, BuildContext context) {
    final reviewList = reviews ?? [];

    if (reviewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              locale.translate('No reviews found', 'Ha ho maikutlo'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Click Refresh to load reviews',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reviewList.length,
      itemBuilder: (context, index) {
        final review = reviewList[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        review.userName.isNotEmpty
                            ? review.userName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            review.listingTitle ?? 'Unknown Listing',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            locale.translate('LIVE', 'PHELA'),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < review.rating.floor()
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  review.comment,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(review.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const Spacer(),
                    if (review.vendorReply?.trim().isNotEmpty == true)
                      Text(
                        locale.translate(
                            'Vendor replied', 'Morekisi o arabile'),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportsTab(
      BuildContext context, LocaleProvider locale, AdminProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildReportCard(
            icon: Icons.assessment,
            title: locale.translate('User Report', 'Tlaleho ea Basebelisi'),
            subtitle: locale.translate('Total users, growth, demographics',
                'Basebelisi, kholo, lipalopalo'),
            color: Colors.blue,
            onTap: () {}),
        _buildReportCard(
            icon: Icons.store,
            title: locale.translate('Vendor Report', 'Tlaleho ea Barekisi'),
            subtitle: locale.translate('Active vendors, approvals, revenue',
                'Barekisi ba sebetsang, tumello, lekeno'),
            color: Colors.green,
            onTap: () {}),
        _buildReportCard(
            icon: Icons.book_online,
            title: locale.translate('Booking Report', 'Tlaleho ea Lipehelo'),
            subtitle: locale.translate('Booking trends, revenue, occupancy',
                'Mekhoa ea lipehelo, lekeno, ho tlala'),
            color: Colors.orange,
            onTap: () {}),
        _buildReportCard(
            icon: Icons.trending_up,
            title: locale.translate('Revenue Report', 'Tlaleho ea Lekeno'),
            subtitle: locale.translate('Monthly revenue, projections',
                'Lekeno la khoeli le khoeli, likhakanyo'),
            color: Colors.purple,
            onTap: () {}),
        _buildReportCard(
            icon: Icons.rate_review,
            title: locale.translate('Reviews Report', 'Tlaleho ea Maikutlo'),
            subtitle: locale.translate('Sentiment analysis, ratings',
                'Tlhahlobo ea maikutlo, litekanyo'),
            color: Colors.teal,
            onTap: () {}),
      ],
    );
  }

  Widget _buildReportCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.download),
        onTap: onTap,
      ),
    );
  }
}
