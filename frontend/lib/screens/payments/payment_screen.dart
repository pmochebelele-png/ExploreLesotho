// lib/screens/payments/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/payment_provider.dart';
import '../../core/themes/color_palette.dart';
import '../../models/payment.dart';
import '../../services/notification_service.dart';
import 'payment_success_screen.dart';
import 'payment_history_screen.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String currency;
  final String bookingId;
  final Map<String, dynamic>? bookingDetails;
  final String summaryTitle;
  final Future<Map<String, dynamic>?> Function(
    String transactionId,
    PaymentMethod method,
  )? onPaymentConfirmed;
  final String successTitle;
  final String successMessage;
  final String successRecordLabel;
  final String successViewRoute;
  final String successViewButtonText;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.currency,
    required this.bookingId,
    this.bookingDetails,
    this.summaryTitle = 'Booking Summary',
    this.onPaymentConfirmed,
    this.successTitle = 'Payment Successful!',
    this.successMessage =
        'Your payment was successful. The vendor will review your booking shortly.',
    this.successRecordLabel = 'Booking ID',
    this.successViewRoute = '/my-bookings',
    this.successViewButtonText = 'View My Bookings',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod? _selectedMethod;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _agreeToTerms = false;
  bool _isProcessing = false;
  // ignore: unused_field
  bool _showPinScreen = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'name': 'Credit/Debit Card',
      'nameSt': 'Karete ea Mokitlane / Debit',
      'method': PaymentMethod.creditCard,
      'icon': Icons.credit_card,
      'color': Colors.blue,
      'fee': '2.5%',
      'description': 'Visa, Mastercard, AMEX',
      'descriptionSt': 'Visa, Mastercard, AMEX',
      'requiresPin': false,
    },
    {
      'name': 'M-Pesa',
      'nameSt': 'M-Pesa',
      'method': PaymentMethod.mpesa,
      'icon': Icons.phone_android,
      'color': const Color(0xFF4CAF50),
      'fee': '1.5%',
      'description': 'Vodacom Lesotho',
      'descriptionSt': 'Vodacom Lesotho',
      'requiresPin': true,
      'provider': 'mpesa',
    },
    {
      'name': 'EcoCash',
      'nameSt': 'EcoCash',
      'method': PaymentMethod.ecoCash,
      'icon': Icons.phone_android,
      'color': const Color(0xFFFF9800),
      'fee': '1.5%',
      'description': 'Econet Lesotho',
      'descriptionSt': 'Econet Lesotho',
      'requiresPin': true,
      'provider': 'ecocash',
    },
    {
      'name': 'Flutterwave',
      'nameSt': 'Flutterwave',
      'method': PaymentMethod.flutterwave,
      'icon': Icons.public,
      'color': Colors.purple,
      'fee': '1.9%',
      'description': 'African payment gateway',
      'descriptionSt': 'Sethala sa tefo sa Afrika',
      'requiresPin': false,
    },
    {
      'name': 'PayPal',
      'nameSt': 'PayPal',
      'method': PaymentMethod.paypal,
      'icon': Icons.paypal,
      'color': Colors.blueAccent,
      'fee': '2.9% + \$0.30',
      'description': 'International payments',
      'descriptionSt': 'Liponta tsa machaba',
      'requiresPin': false,
    },
    {
      'name': 'Stripe',
      'nameSt': 'Stripe',
      'method': PaymentMethod.stripe,
      'icon': Icons.credit_score,
      'color': Colors.indigo,
      'fee': '2.9% + \$0.30',
      'description': 'Secure card payments',
      'descriptionSt': 'Liponta tsa karete tse sireletsehileng',
      'requiresPin': false,
    },
  ];

  double get _subtotal =>
      _asDouble(widget.bookingDetails?['subtotal']) ?? widget.amount;

  double get _serviceFee =>
      _asDouble(widget.bookingDetails?['serviceFee']) ?? 0;

  double get _addOnsPrice =>
      _asDouble(widget.bookingDetails?['addOnsPrice']) ?? 0;

  double get _total =>
      _asDouble(widget.bookingDetails?['total']) ?? widget.amount;

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    return ChangeNotifierProvider(
      create: (_) => PaymentProvider(),
      child: Consumer<PaymentProvider>(
        builder: (context, paymentProvider, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(locale.translate('Complete Payment', 'Qetella Tefo')),
              backgroundColor: ColorPalette.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PaymentHistoryScreen(),
                      ),
                    );
                  },
                  tooltip: locale.translate('Payment History', 'Nalane ea Tefo'),
                ),
              ],
            ),
            body: _isProcessing || paymentProvider.isProcessing
                ? _buildProcessingScreen(locale)
                : _buildPaymentScreen(paymentProvider, locale),
          );
        },
      ),
    );
  }

  Widget _buildProcessingScreen(LocaleProvider locale) {
    final isMobileMoney = _selectedMethod == PaymentMethod.mpesa || _selectedMethod == PaymentMethod.ecoCash;
    final providerName = _selectedMethod == PaymentMethod.mpesa ? 'M-Pesa' : 
                         _selectedMethod == PaymentMethod.ecoCash ? 'EcoCash' : '';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            isMobileMoney
                ? locale.translate('Processing $providerName payment...', 'Ho sebetsana le tefo ea $providerName...')
                : locale.translate('Processing payment...', 'Ho sebetsana le tefo...'),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            locale.translate('Please wait', 'Ka kopo emela'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPinScreen(LocaleProvider locale) {
    final isMpesa = _selectedMethod == PaymentMethod.mpesa;
    final providerName = isMpesa ? 'M-Pesa' : 'EcoCash';
    final providerColor = isMpesa 
        ? const Color(0xFF4CAF50) 
        : const Color(0xFFFF9800);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: providerColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock,
              size: 48,
              color: providerColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            locale.translate('Enter $providerName PIN', 'Kenya PIN ea $providerName'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            locale.translate('Phone: ${_phoneController.text}', 'Nomoro: ${_phoneController.text}'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _pinController,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _verifyPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: providerColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                locale.translate('Verify & Pay', 'Netefatsa & Lefa'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _showPinScreen = false;
                _pinController.clear();
              });
            },
            child: Text(locale.translate('Cancel', 'Hlakola')),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentScreen(PaymentProvider paymentProvider, LocaleProvider locale) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking Summary Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.translate(widget.summaryTitle, widget.summaryTitle),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.bookingDetails != null) ...[
                    if (widget.bookingDetails!['summaryRows'] is List) ...[
                      ...(widget.bookingDetails!['summaryRows'] as List)
                          .whereType<Map>()
                          .map((row) => _buildSummaryRow(
                                row['label']?.toString() ?? '',
                                row['value']?.toString() ?? '',
                              )),
                    ] else ...[
                      _buildSummaryRow(
                        locale.translate('Listing', 'Lenane'),
                        widget.bookingDetails!['listingTitle'] ?? 'N/A',
                      ),
                      _buildSummaryRow(
                        locale.translate('Dates', 'Matsatsi'),
                        '${widget.bookingDetails!['checkIn']} - ${widget.bookingDetails!['checkOut']}',
                      ),
                      _buildSummaryRow(
                        locale.translate('Guests', 'Baeti'),
                        '${widget.bookingDetails!['guests']}',
                      ),
                    ],
                    const Divider(),
                  ],
                  _buildSummaryRow(
                    locale.translate('Subtotal', 'Kakaretso ea Pele'),
                    '${widget.currency} ${_subtotal.toStringAsFixed(2)}',
                    isBold: true,
                  ),
                  if (_addOnsPrice > 0)
                    _buildSummaryRow(
                      locale.translate('Add-ons', 'Lintlha tse ekelitsoeng'),
                      '${widget.currency} ${_addOnsPrice.toStringAsFixed(2)}',
                    ),
                  _buildSummaryRow(
                    locale.translate('Service Fee', 'Tefo ea Tšebeletso'),
                    '${widget.currency} ${_serviceFee.toStringAsFixed(2)}',
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    locale.translate('Total', 'Kakaretso'),
                    '${widget.currency} ${_total.toStringAsFixed(2)}',
                    isBold: true,
                    color: ColorPalette.primaryGreen,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Payment Methods
          Text(
            locale.translate('Select Payment Method', 'Khetha Mokhoa oa Tefo'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._paymentMethods.map((method) => _buildPaymentMethodCard(method, locale)),

          // Mobile Money Input (if M-Pesa or EcoCash selected)
          if (_selectedMethod == PaymentMethod.mpesa || _selectedMethod == PaymentMethod.ecoCash) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedMethod == PaymentMethod.mpesa 
                            ? Icons.phone_android 
                            : Icons.phone,
                        color: _selectedMethod == PaymentMethod.mpesa 
                            ? const Color(0xFF4CAF50) 
                            : const Color(0xFFFF9800),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedMethod == PaymentMethod.mpesa 
                            ? locale.translate('M-Pesa Number', 'Nomoro ea M-Pesa') 
                            : locale.translate('EcoCash Number', 'Nomoro ea EcoCash'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      hintText: _selectedMethod == PaymentMethod.mpesa
                          ? locale.translate('Enter your M-Pesa number (e.g., 5888XXXXX)', 'Kenya nomoro ea hao ea M-Pesa (mohlala, 5888XXXXX)')
                          : locale.translate('Enter your EcoCash number', 'Kenya nomoro ea hao ea EcoCash'),
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedMethod == PaymentMethod.mpesa
                        ? locale.translate('You will receive a payment request on your M-Pesa', 'U tla fumana kopo ea tefo ho M-Pesa ea hao')
                        : locale.translate('You will receive a payment request on your EcoCash', 'U tla fumana kopo ea tefo ho EcoCash ea hao'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Terms Agreement
          CheckboxListTile(
            title: Text(
              locale.translate('I agree to the terms and conditions', 'Ke lumellana le melao le maemo'),
              style: const TextStyle(fontSize: 14),
            ),
            value: _agreeToTerms,
            onChanged: (value) {
              setState(() {
                _agreeToTerms = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),

          const SizedBox(height: 16),

          // Pay Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _selectedMethod != null && _agreeToTerms
                  ? () => _processPayment(context, paymentProvider, locale)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorPalette.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                locale.translate('Pay ${widget.currency} ${_total.toStringAsFixed(2)}', 'Lefa ${widget.currency} ${_total.toStringAsFixed(2)}'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Security Note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                locale.translate('Secure payment powered by ', 'Tefo e bolokehileng e sebetsoa ke '),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                _getPaymentProvider(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment(BuildContext context, PaymentProvider paymentProvider, LocaleProvider locale) async {
    if (_selectedMethod == null) return;

    if (_selectedMethod == PaymentMethod.mpesa || _selectedMethod == PaymentMethod.ecoCash) {
      if (_phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale.translate('Please enter your ${_selectedMethod == PaymentMethod.mpesa ? 'M-Pesa' : 'EcoCash'} number', 'Ka kōpo kenya nomoro ea hau ea ${_selectedMethod == PaymentMethod.mpesa ? 'M-Pesa' : 'EcoCash'}')),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    final isEventTicket = widget.bookingId.startsWith('event-');
    final bookingIntent = isEventTicket
        ? null
        : Provider.of<BookingProvider>(context, listen: false).bookingIntent;
    final result = await paymentProvider.initiatePayment(
      context: context,
      amount: _total,
      currency: widget.currency,
      bookingId: widget.bookingId,
      method: _selectedMethod!,
      purpose: isEventTicket ? 'event_ticket' : 'booking',
      relatedId: isEventTicket ? widget.bookingId.split('-')[1] : widget.bookingId,
      serviceFee: _serviceFee,
      paymentDetails: {
        'phone': _phoneController.text.trim(),
        'description': widget.bookingDetails?['listingTitle'] ?? 'Explore Lesotho payment',
      },
      metadata: isEventTicket
          ? {
              'eventId': int.tryParse(widget.bookingId.split('-')[1]),
              'quantity': int.tryParse(widget.bookingId.split('-')[2]),
            }
          : {
              'bookingIntentId': widget.bookingId,
              'bookingIntent': bookingIntent ?? {},
              'bookingDetails': widget.bookingDetails ?? {},
            },
    );

    setState(() {
      _isProcessing = false;
    });

    if (!mounted || !context.mounted) return;

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Payment provider is not configured'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reference = result['paymentReference']?.toString() ?? widget.bookingId;
    final status = result['status']?.toString() ?? 'pending';
    final message = result['customerMessage']?.toString() ??
        'Payment request sent. Confirm it on your phone.';

    if (status == 'paid') {
      await NotificationService().sendPaymentSuccessNotification(
        bookingTitle: widget.bookingDetails?['listingTitle'] ?? locale.translate('Booking', 'Phehelo'),
        amount: _total,
        currency: widget.currency,
      );
    }

    if (!mounted || !context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSuccessScreen(
          transactionId: reference,
          amount: _total,
          currency: widget.currency,
          bookingId: widget.bookingId,
          successTitle: status == 'paid' ? widget.successTitle : 'Payment Request Sent',
          successMessage: status == 'paid'
              ? widget.successMessage
              : '$message Your booking or ticket will confirm after the provider sends payment confirmation.',
          recordLabel: 'Payment Reference',
          viewRoute: widget.successViewRoute,
          viewButtonText: widget.successViewButtonText,
        ),
      ),
    );
  }

  Future<void> _verifyPin() async {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    if (_pinController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locale.translate('Please enter a valid 4-digit PIN', 'Ka kopo kenya PIN e nepahetseng ea linomoro tse 4')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });
    
    // Simulate PIN verification
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _isProcessing = false;
    });
    
    if (mounted) {
      final locale = Provider.of<LocaleProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedMethod == PaymentMethod.mpesa
              ? locale.translate('M-Pesa payment successful!', 'Tefo ea M-Pesa e atlehile!')
              : locale.translate('EcoCash payment successful!', 'Tefo ea EcoCash e atlehile!')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      await _goToSuccess();
    }
  }

  Future<void> _goToSuccess() async {
    // Send payment success notification
    final notificationService = NotificationService();
    await notificationService.sendPaymentSuccessNotification(
      bookingTitle: widget.bookingDetails?['listingTitle'] ?? 'Booking',
      amount: _total,
      currency: widget.currency,
    );
    
    if (!mounted) return;

    final transactionId = transactionIdFromNow();
    final result = await _confirmPaymentAction(transactionId);

    if (!mounted) return;

    if (result == null) {
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookingProvider.error ?? 'Failed to confirm booking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentSuccessScreen(
            transactionId: transactionId,
            amount: _total,
            currency: widget.currency,
            bookingId: result['recordId']?.toString() ?? widget.bookingId,
            successTitle: widget.successTitle,
            successMessage: widget.successMessage,
            recordLabel: widget.successRecordLabel,
            viewRoute: widget.successViewRoute,
            viewButtonText: widget.successViewButtonText,
          ),
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _confirmPaymentAction(String transactionId) async {
    if (widget.onPaymentConfirmed != null && _selectedMethod != null) {
      return widget.onPaymentConfirmed!(transactionId, _selectedMethod!);
    }

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final booking = await bookingProvider.confirmBooking(
      paymentId: transactionId,
      transactionId: transactionId,
    );

    if (booking == null) {
      return null;
    }

    return {'recordId': booking.id};
  }

  String transactionIdFromNow() => 'TXN${DateTime.now().millisecondsSinceEpoch}';

  double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method, LocaleProvider locale) {
    final isSelected = _selectedMethod == method['method'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? ColorPalette.primaryGreen : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = method['method'];
            _showPinScreen = false;
            _pinController.clear();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: method['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  method['icon'],
                  color: method['color'],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.translate(method['name'] as String, method['nameSt'] as String),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      locale.translate(method['description'] as String, method['descriptionSt'] as String),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Radio<PaymentMethod>(
                value: method['method'],
                groupValue: _selectedMethod,
                onChanged: (value) {
                  setState(() {
                    _selectedMethod = value;
                    _showPinScreen = false;
                    _pinController.clear();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPaymentProvider() {
    if (_selectedMethod == PaymentMethod.mpesa) {
      return 'M-Pesa (Vodacom)';
    }
    if (_selectedMethod == PaymentMethod.ecoCash) {
      return 'EcoCash (Econet)';
    }
    switch (_selectedMethod) {
      case PaymentMethod.flutterwave:
        return 'Flutterwave';
      case PaymentMethod.paypal:
        return 'PayPal';
      case PaymentMethod.stripe:
        return 'Stripe';
      case PaymentMethod.creditCard:
        return 'Secure Gateway';
      default:
        return 'Secure Gateway';
    }
  }
}
