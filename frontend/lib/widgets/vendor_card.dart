
// lib/widgets/vendor_card.dart
import 'package:flutter/material.dart';
import '../data/models/vendor.dart';
import '../services/social_service.dart';

class VendorCard extends StatelessWidget {
  final Vendor vendor;
  final VoidCallback? onTap;

  const VendorCard({
    super.key,
    required this.vendor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      vendor.businessName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor.businessName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (vendor.businessType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              vendor.businessType!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (vendor.isVerified)
                    const Icon(
                      Icons.verified,
                      color: Colors.green,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Contact Info
              if (vendor.businessPhone != null ||
                  vendor.businessEmail != null) ...[
                const SizedBox(height: 8),
                if (vendor.businessPhone != null)
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vendor.businessPhone!,
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                if (vendor.businessEmail != null)
                  const SizedBox(height: 4),
                if (vendor.businessEmail != null)
                  Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vendor.businessEmail!,
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
              ],
              
              const SizedBox(height: 12),
              
              // Social Media Buttons
              if (vendor.whatsapp != null ||
                  vendor.facebook != null ||
                  vendor.instagram != null ||
                  vendor.twitter != null ||
                  vendor.website != null) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Connect With Us',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (vendor.whatsapp != null && vendor.whatsapp!.isNotEmpty)
                      _buildSocialButton(
                        icon: Icons.chat,
                        color: Colors.green,
                        label: 'WhatsApp',
                        onTap: () => SocialService.launchWhatsApp(vendor.whatsapp!),
                      ),
                    if (vendor.facebook != null && vendor.facebook!.isNotEmpty)
                      _buildSocialButton(
                        icon: Icons.facebook,
                        color: Colors.blue.shade800,
                        label: 'Facebook',
                        onTap: () => SocialService.launchFacebook(vendor.facebook!),
                      ),
                    if (vendor.instagram != null && vendor.instagram!.isNotEmpty)
                      _buildSocialButton(
                        icon: Icons.camera_alt,
                        color: Colors.purple,
                        label: 'Instagram',
                        onTap: () => SocialService.launchInstagram(vendor.instagram!),
                      ),
                    if (vendor.twitter != null && vendor.twitter!.isNotEmpty)
                      _buildSocialButton(
                        icon: Icons.abc,
                        color: Colors.blue.shade400,
                        label: 'Twitter',
                        onTap: () => SocialService.launchTwitter(vendor.twitter!),
                      ),
                    if (vendor.website != null && vendor.website!.isNotEmpty)
                      _buildSocialButton(
                        icon: Icons.language,
                        color: Colors.teal,
                        label: 'Website',
                        onTap: () => SocialService.launchWebsite(vendor.website!),
                      ),
                    if (vendor.businessPhone != null && vendor.businessPhone!.isNotEmpty)
                      _buildSocialButton(
                        icon: Icons.phone,
                        color: Colors.blue,
                        label: 'Call',
                        onTap: () => SocialService.callPhone(vendor.businessPhone!),
                      ),
                    if (vendor.businessEmail != null && vendor.businessEmail!.isNotEmpty)
                      _buildSocialButton(
                        icon: Icons.email,
                        color: Colors.red,
                        label: 'Email',
                        onTap: () => SocialService.sendEmail(vendor.businessEmail!),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}