import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/localizations/app_localizations_delegate.dart';
import 'core/themes/color_palette.dart';
import 'data/providers/admin_provider.dart';
import 'data/providers/vendor_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/culture_provider.dart';
import 'providers/event_provider.dart';
import 'providers/listing_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/review_provider.dart';
import 'providers/test_chat_provider.dart';
import 'providers/wishlist_provider.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/bookings/my_bookings_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/events/my_event_tickets_screen.dart';
import 'screens/home/tourist_dashboard.dart';
import 'screens/onboarding/onboarding_gate.dart';
import 'screens/unauthorized_screen.dart';
import 'screens/vendor/vendor_dashboard.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ListingProvider()),
        ChangeNotifierProvider(create: (_) => CultureProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => VendorProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProxyProvider<AuthProvider, TestChatProvider>(
          create: (context) => TestChatProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, authProvider, previousChatProvider) {
            previousChatProvider?.updateAuthProvider(authProvider);
            return previousChatProvider ??
                TestChatProvider(authProvider: authProvider);
          },
        ),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProxyProvider<AuthProvider, BookingProvider>(
          create: (context) => BookingProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, authProvider, previousBookingProvider) {
            previousBookingProvider?.updateAuthProvider(authProvider);
            return previousBookingProvider ??
                BookingProvider(authProvider: authProvider);
          },
        ),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp(
            title: Constants.appName,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.green,
              primaryColor: ColorPalette.primaryGreen,
              scaffoldBackgroundColor: ColorPalette.backgroundLight,
              fontFamily: 'Roboto',
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: ColorPalette.primaryGreen,
                brightness: Brightness.light,
                primary: ColorPalette.primaryGreen,
                secondary: ColorPalette.secondaryGreen,
                tertiary: ColorPalette.accentOrange,
                error: ColorPalette.errorRed,
                surface: ColorPalette.surfaceWhite,
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: ColorPalette.textPrimary,
                onError: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: ColorPalette.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorPalette.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: ColorPalette.primaryGreen.withOpacity(0.3),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: ColorPalette.primaryGreen,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorPalette.primaryGreen,
                  side: BorderSide(color: ColorPalette.primaryGreen, width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: ColorPalette.surfaceWhite,
                surfaceTintColor: ColorPalette.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                titleTextStyle: TextStyle(
                  color: ColorPalette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                contentTextStyle: TextStyle(
                  color: ColorPalette.textSecondary,
                  fontSize: 16,
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: ColorPalette.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ColorPalette.secondaryGreen),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: ColorPalette.secondaryGreen.withOpacity(0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: ColorPalette.primaryGreen,
                    width: 2,
                  ),
                ),
                labelStyle: TextStyle(color: ColorPalette.textSecondary),
                hintStyle: TextStyle(color: ColorPalette.textLight),
              ),
              textTheme: TextTheme(
                headlineLarge: TextStyle(
                  color: ColorPalette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                headlineMedium: TextStyle(
                  color: ColorPalette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                bodyLarge: TextStyle(
                  color: ColorPalette.textPrimary,
                ),
                bodyMedium: TextStyle(
                  color: ColorPalette.textSecondary,
                ),
                labelLarge: TextStyle(
                  color: ColorPalette.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('en', ''),
              Locale('st', ''),
            ],
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const OnboardingGate(),
            routes: {
              '/onboarding': (context) => const WelcomeStartScreen(),
              '/login': (context) => const LoginScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/register': (context) => const RegisterScreen(),
              '/tourist-dashboard': (context) => const TouristDashboard(),
              '/vendor-dashboard': (context) => const VendorDashboard(),
              '/admin-dashboard': (context) => const AdminDashboard(),
              '/my-bookings': (context) => const MyBookingsScreen(),
              '/chat': (context) => const ChatListScreen(),
              '/my-event-tickets': (context) => const MyEventTicketsScreen(),
              '/unauthorized': (context) => const UnauthorizedScreen(),
            },
          );
        },
      ),
    );
  }
}
