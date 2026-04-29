import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/themes/color_palette.dart';
import '../../services/api_service.dart';

class MyEventTicketsScreen extends StatefulWidget {
  const MyEventTicketsScreen({super.key});

  @override
  State<MyEventTicketsScreen> createState() => _MyEventTicketsScreenState();
}

class _MyEventTicketsScreenState extends State<MyEventTicketsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.get('/events/tickets/my');
      final body = json.decode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(
            (body['orders'] as List?) ?? const [],
          );
        });
      } else {
        setState(() {
          _error = body['message']?.toString() ??
              body['error']?.toString() ??
              'Could not load your event tickets.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not load your event tickets.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Event Tickets'),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _orders.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          return _buildOrderCard(_orders[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Could not load your event tickets.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.confirmation_number_outlined,
                size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No event tickets yet.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Your paid event tickets will show here with receipt details.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final event = Map<String, dynamic>.from(
      (order['event'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final purchasedAt =
        DateTime.tryParse(order['purchasedAt']?.toString() ?? '');
    final totalAmount = (order['totalAmount'] is num)
        ? (order['totalAmount'] as num).toDouble()
        : double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0;
    final serviceFee = (order['serviceFee'] is num)
        ? (order['serviceFee'] as num).toDouble()
        : double.tryParse(order['serviceFee']?.toString() ?? '0') ?? 0;
    final subtotal = (order['subtotal'] is num)
        ? (order['subtotal'] as num).toDouble()
        : double.tryParse(order['subtotal']?.toString() ?? '0') ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event['title']?.toString() ?? 'Event Ticket',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ColorPalette.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${order['quantity'] ?? 0} ticket(s)',
                    style: const TextStyle(
                      color: ColorPalette.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _detailRow('Receipt', order['receiptNumber']?.toString() ?? '-'),
            _detailRow('Order ID', order['orderId']?.toString() ?? '-'),
            _detailRow('Payment ID', order['paymentId']?.toString() ?? '-'),
            _detailRow('Payment Method',
                order['paymentMethod']?.toString().toUpperCase() ?? '-'),
            _detailRow(
                'Status', order['paymentStatus']?.toString().toUpperCase() ?? '-'),
            _detailRow('Host', event['organizer']?.toString() ?? '-'),
            _detailRow('Location', event['location']?.toString() ?? '-'),
            if (purchasedAt != null)
              _detailRow('Purchased',
                  '${purchasedAt.day}/${purchasedAt.month}/${purchasedAt.year} ${purchasedAt.hour.toString().padLeft(2, '0')}:${purchasedAt.minute.toString().padLeft(2, '0')}'),
            const Divider(height: 24),
            _detailRow('Subtotal',
                '${order['currency'] ?? 'LSL'} ${subtotal.toStringAsFixed(2)}'),
            _detailRow('Service Fee',
                '${order['currency'] ?? 'LSL'} ${serviceFee.toStringAsFixed(2)}'),
            _detailRow(
              'Total Paid',
              '${order['currency'] ?? 'LSL'} ${totalAmount.toStringAsFixed(2)}',
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
                color: emphasize ? ColorPalette.primaryGreen : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
