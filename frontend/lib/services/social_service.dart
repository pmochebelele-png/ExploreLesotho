
// lib/services/social_service.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialService {
  // Launch WhatsApp chat
  static Future<void> launchWhatsApp(String phoneNumber) async {
    // Remove any non-digit characters
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // Ensure number has country code
    if (!cleanNumber.startsWith('+')) {
      cleanNumber = '+266$cleanNumber'; // Lesotho country code
    }
    
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');
    
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      rethrow;
    }
  }
  
  // Launch Facebook page/profile
  static Future<void> launchFacebook(String username) async {
    // Clean username (remove @ if present)
    String cleanUsername = username.replaceAll('@', '');
    
    final Uri facebookUri = Uri.parse('https://www.facebook.com/$cleanUsername');
    
    try {
      if (await canLaunchUrl(facebookUri)) {
        await launchUrl(facebookUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Facebook';
      }
    } catch (e) {
      debugPrint('Error launching Facebook: $e');
      rethrow;
    }
  }
  
  // Launch Instagram profile
  static Future<void> launchInstagram(String username) async {
    // Clean username (remove @ if present)
    String cleanUsername = username.replaceAll('@', '');
    
    final Uri instagramUri = Uri.parse('https://www.instagram.com/$cleanUsername');
    
    try {
      if (await canLaunchUrl(instagramUri)) {
        await launchUrl(instagramUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Instagram';
      }
    } catch (e) {
      debugPrint('Error launching Instagram: $e');
      rethrow;
    }
  }
  
  // Launch Twitter/X profile
  static Future<void> launchTwitter(String username) async {
    // Clean username (remove @ if present)
    String cleanUsername = username.replaceAll('@', '');
    
    final Uri twitterUri = Uri.parse('https://twitter.com/$cleanUsername');
    
    try {
      if (await canLaunchUrl(twitterUri)) {
        await launchUrl(twitterUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Twitter';
      }
    } catch (e) {
      debugPrint('Error launching Twitter: $e');
      rethrow;
    }
  }
  
  // Launch website
  static Future<void> launchWebsite(String url) async {
    // Ensure URL has protocol
    String cleanUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      cleanUrl = 'https://$url';
    }
    
    final Uri websiteUri = Uri.parse(cleanUrl);
    
    try {
      if (await canLaunchUrl(websiteUri)) {
        await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch website';
      }
    } catch (e) {
      debugPrint('Error launching website: $e');
      rethrow;
    }
  }
  
  // Launch phone dialer
  static Future<void> callPhone(String phoneNumber) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    final Uri phoneUri = Uri.parse('tel:$cleanNumber');
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch phone dialer';
      }
    } catch (e) {
      debugPrint('Error launching phone: $e');
      rethrow;
    }
  }
  
  // Launch email
  static Future<void> sendEmail(String email, {String? subject, String? body}) async {
    final Uri emailUri = Uri.parse(
      'mailto:$email?subject=${subject ?? ''}&body=${body ?? ''}'
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch email app';
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      rethrow;
    }
  }
}