import 'package:flutter/material.dart';

import '../../models/culture_vendor.dart';
import '../../services/social_service.dart';
import '../chat/new_message_screen.dart';
import 'listing_detail_screen.dart';

class CultureVendorDetailScreen extends StatelessWidget {
  final CultureVendor vendor;

  const CultureVendorDetailScreen({
    super.key,
    required this.vendor,
  });

  @override
  Widget build(BuildContext context) {
    final callableContacts = vendor.contacts.where(_isCallableContact).toList();
    final profileNotes = vendor.contacts.where((contact) => !_isCallableContact(contact)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(vendor.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vendor.isClaimed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.18),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This culture profile has been claimed by a registered vendor account.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (vendor.linkedListingId != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(
                            listingId: vendor.linkedListingId!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('View Portfolio, Products & Services'),
                ),
              ),
            _sectionTitle('Products / Services'),
            const SizedBox(height: 8),
            _sectionBody(vendor.productRange),
            const SizedBox(height: 18),
            _sectionTitle('Location'),
            const SizedBox(height: 8),
            _sectionBody(
                vendor.location.isEmpty ? 'Not specified' : vendor.location),
            const SizedBox(height: 18),
            _sectionTitle('Contact'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: callableContacts.isEmpty
                  ? [const Text('No contacts available')]
                  : callableContacts.map((contact) {
                      return OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await SocialService.callPhone(contact);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not open dialer'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.call, size: 16),
                        label: Text(contact),
                      );
                    }).toList(),
            ),
            if (vendor.linkedVendorUserId?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final started = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NewMessageScreen(
                          title: 'Message Vendor',
                          allowedRoles: const {'vendor'},
                          initialRecipientId: vendor.linkedVendorUserId,
                          initialRecipientName: vendor.name,
                          lockRecipient: true,
                        ),
                      ),
                    );
                    if (started == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Conversation started with vendor'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Message Vendor'),
                ),
              ),
            ],
            if (profileNotes.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle('Profile Notes'),
              const SizedBox(height: 8),
              ...profileNotes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _sectionBody(note),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isCallableContact(String contact) {
    final digits = contact.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 7;
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  Widget _sectionBody(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Text(value),
    );
  }
}
