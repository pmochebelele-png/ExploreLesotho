
import '../config/api_config.dart';

class Constants {
  // 👇 UPDATED: Now uses ApiConfig for base URL
  static String get baseUrl => ApiConfig.baseUrl;
  
  // Keep your existing keys
  static const String userKey = "user_data";
  static const String tokenKey = "auth_token";

  // Auth Endpoints
  static const String registerEndpoint = '/api/auth/register';
  static const String loginEndpoint = '/api/auth/login';

  // Booking Endpoints
  static const String bookingsEndpoint = '/api/bookings';

  // ✅ KEEP THESE - your app constants
  static const String appName = 'Explore Lesotho';
  static const String defaultLanguage = 'en';
  
  // Optional: Add more endpoints as needed
  static const String listingsEndpoint = '/api/listings';
  static const String reviewsEndpoint = '/api/reviews';
  static const String usersEndpoint = '/api/users';
}