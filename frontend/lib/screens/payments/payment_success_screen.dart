// lib/screens/payments/payment_success_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../core/themes/color_palette.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String transactionId;
  final double amount;
  final String currency;
  final String bookingId;
  final String successTitle;
  final String successMessage;
  final String recordLabel;
  final String viewRoute;
  final String viewButtonText;

  const PaymentSuccessScreen({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.currency,
    required this.bookingId,
    this.successTitle = 'Payment Successful!',
    this.successMessage =
        'Your payment was successful. The vendor will review your booking shortly.',
    this.recordLabel = 'Booking ID',
    this.viewRoute = '/my-bookings',
    this.viewButtonText = 'View My Bookings',
  });

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Animation
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Success Message
                Text(
                  locale.translate(successTitle, successTitle),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  locale.translate(successMessage, successMessage),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Payment Details Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildDetailRow(locale.translate('Amount', 'Chelete'), '$currency ${amount.toStringAsFixed(2)}'),
                        const Divider(height: 24),
                        _buildDetailRow(locale.translate('Transaction ID', "ID ea Ts'ebetso"), transactionId),
                        const Divider(height: 24),
                        _buildDetailRow(locale.translate(recordLabel, recordLabel), bookingId),
                        const Divider(height: 24),
                        _buildDetailRow(locale.translate('Date', 'Letsatsi'), _getCurrentDate()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            viewRoute,
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: ColorPalette.primaryGreen),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          locale.translate(viewButtonText, viewButtonText),
                          style: const TextStyle(
                            color: ColorPalette.primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/tourist-dashboard',
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorPalette.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          locale.translate('Back to Home', 'Khutlela Lehae'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Note
                Text(
                  locale.translate(
                    'A confirmation email has been sent to your registered email',
                    'Imeile ea netefatso e rometsoe lengolong la hau le ngolisitsoeng',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }
}
