import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/themes/color_palette.dart';
import '../../providers/booking_provider.dart';
import '../payments/payment_screen.dart';

class BookingScreen extends StatefulWidget {
  final String listingId;
  final String listingTitle;
  final String vendorId;
  final String vendorName;
  final double pricePerNight;
  final String listingCategory;
  final String? priceUnit;
  final Map<String, dynamic>? additionalDetails;

  const BookingScreen({
    super.key,
    required this.listingId,
    required this.listingTitle,
    required this.vendorId,
    required this.vendorName,
    required this.pricePerNight,
    required this.listingCategory,
    this.priceUnit,
    this.additionalDetails,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late DateTime _checkIn;
  late DateTime _checkOut;
  int _guests = 1;
  bool _isLoading = false;
  final TextEditingController _specialRequestsController =
      TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _cultureQuantityController =
      TextEditingController();

  String _cultureServiceType = 'Performance';
  String _cultureEngagement = 'Hire';

  final List<String> _selectedAddOns = [];

  String get _category => widget.listingCategory.trim();
  String get _categoryLower => _category.toLowerCase();

  bool get _isAccommodation => _categoryLower == 'accommodation';
  bool get _isRestaurant => _categoryLower == 'restaurant';
  bool get _isTourLike =>
      _categoryLower == 'tour' ||
      _categoryLower == 'adventure' ||
      _categoryLower == 'experience';
  bool get _isCulture =>
      _categoryLower == 'culture' || _categoryLower == 'cultural';

  @override
  void initState() {
    super.initState();
    _checkIn = DateTime.now().add(const Duration(days: 1));
    _checkOut = DateTime.now().add(const Duration(days: 2));
    _durationController.text =
        widget.additionalDetails?['duration']?.toString() ?? '2 hours';
  }

  @override
  void dispose() {
    _specialRequestsController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    _cultureQuantityController.dispose();
    super.dispose();
  }

  int get _nights => _checkOut.difference(_checkIn).inDays > 0
      ? _checkOut.difference(_checkIn).inDays
      : 1;

  int get _billableUnits {
    if (_isAccommodation) return _nights;
    return _guests;
  }

  String get _billableLabel {
    if (_isAccommodation) return 'nights';
    if (_isRestaurant) return 'guests';
    if (_isTourLike) return 'participants';
    if (_isCulture) return 'visitors';
    return 'units';
  }

  double get _serviceFeeRate {
    if (_isRestaurant) return 0.03;
    if (_isTourLike) return 0.06;
    return 0.05;
  }

  List<String> get _categoryAddOns {
    if (_isAccommodation) {
      return const [
        'Breakfast (+M150/day)',
        'Airport Transfer (+M300)',
        'Guide Service (+M500/day)',
        'Photography Package (+M200)',
      ];
    }
    if (_isRestaurant) {
      return const [
        'Private Table Setup (+M180)',
        'Birthday Decor (+M250)',
        'Live Music Seating (+M120)',
      ];
    }
    if (_isTourLike) {
      return const [
        'Transport Pickup (+M300)',
        'Professional Guide (+M450)',
        'Photo Package (+M220)',
      ];
    }
    if (_isCulture) {
      return const [
        'Local Story Guide (+M180)',
        'Craft Demonstration (+M220)',
      ];
    }
    return const [];
  }

  double get _subtotal => widget.pricePerNight * _billableUnits;
  double get _addOnsTotal => _calculateAddOnsPrice();
  double get _serviceFee => _subtotal * _serviceFeeRate;
  double get _grandTotal => _subtotal + _addOnsTotal + _serviceFee;

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _checkIn, end: _checkOut),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ColorPalette.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _checkIn = picked.start;
        _checkOut = picked.end;
      });
    }
  }

  Future<void> _selectSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _checkIn,
    );
    if (picked != null) {
      setState(() {
        _checkIn = DateTime(picked.year, picked.month, picked.day);
        _checkOut = _checkIn.add(const Duration(days: 1));
      });
    }
  }

  Map<String, dynamic> _buildBookingMeta() {
    final meta = <String, dynamic>{
      'category': _category,
      'priceUnit': widget.priceUnit,
      'billableUnits': _billableUnits,
      'billableLabel': _billableLabel,
      'selectedDate': '${_checkIn.day}/${_checkIn.month}/${_checkIn.year}',
    };

    if (_timeController.text.trim().isNotEmpty) {
      meta['preferredTime'] = _timeController.text.trim();
    }
    if (_durationController.text.trim().isNotEmpty) {
      meta['duration'] = _durationController.text.trim();
    }
    if (_selectedAddOns.isNotEmpty) {
      meta['addOns'] = _selectedAddOns;
    }
    if (_notesController.text.trim().isNotEmpty) {
      meta['categoryNotes'] = _notesController.text.trim();
    }
    if (_isCulture) {
      meta['cultureType'] = widget.additionalDetails?['cultureType'];
      meta['cultureServiceType'] = _cultureServiceType;
      meta['cultureEngagement'] = _cultureEngagement;
      if (_cultureEngagement == 'Buy' &&
          _cultureQuantityController.text.trim().isNotEmpty) {
        meta['cultureQuantity'] = _cultureQuantityController.text.trim();
      }
    }

    return meta;
  }

  Future<void> _proceedToPayment() async {
    setState(() => _isLoading = true);

    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);
    final success = await bookingProvider.createBookingIntent(
      listingId: widget.listingId,
      listingTitle: widget.listingTitle,
      vendorId: widget.vendorId,
      vendorName: widget.vendorName,
      checkIn: _checkIn,
      checkOut: _checkOut,
      guests: _guests,
      pricePerNight: widget.pricePerNight,
      currency: 'LSL',
      category: _category,
      billableUnits: _billableUnits,
      billableUnitLabel: _billableLabel,
      addOnsPriceOverride: _addOnsTotal,
      serviceFeeRate: _serviceFeeRate,
      bookingMeta: _buildBookingMeta(),
      specialRequests: _specialRequestsController.text.trim().isEmpty
          ? null
          : {'notes': _specialRequestsController.text.trim()},
      addOns: List<String>.from(_selectedAddOns),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookingProvider.error ?? 'Failed to start booking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bookingId =
        bookingProvider.bookingIntent?['bookingIntentId']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: _grandTotal,
          currency: 'LSL',
          bookingId: bookingId,
          bookingDetails: {
            'listingTitle': widget.listingTitle,
            'category': _category,
            'checkIn': '${_checkIn.day}/${_checkIn.month}/${_checkIn.year}',
            'checkOut': '${_checkOut.day}/${_checkOut.month}/${_checkOut.year}',
            'guests': _guests,
            'nights': _nights,
            'billableUnits': _billableUnits,
            'billableUnitLabel': _billableLabel,
            'subtotal': _subtotal,
            'serviceFee': _serviceFee,
            'addOnsPrice': _addOnsTotal,
            'total': _grandTotal,
          },
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    if (_isAccommodation) {
      return _buildSectionCard(
        title: 'Stay Dates',
        child: InkWell(
          onTap: _selectDateRange,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _dateItem('Check-in', _checkIn),
                ),
                const Icon(Icons.arrow_forward),
                Expanded(
                  child: _dateItem('Check-out', _checkOut, endAligned: true),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildSectionCard(
      title: _isRestaurant ? 'Reservation Date' : 'Service Date',
      child: InkWell(
        onTap: _selectSingleDate,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.event, color: ColorPalette.primaryGreen),
              const SizedBox(width: 10),
              Text(
                '${_checkIn.day}/${_checkIn.month}/${_checkIn.year}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const Icon(Icons.edit_calendar),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateItem(String label, DateTime date, {bool endAligned = false}) {
    return Column(
      crossAxisAlignment:
          endAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '${date.day}/${date.month}/${date.year}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildGuestCard() {
    final title = _isRestaurant
        ? 'Party Size'
        : _isAccommodation
            ? 'Guests'
            : 'Participants';
    return _buildSectionCard(
      title: title,
      child: Row(
        children: [
          Text('Number of ${title.toLowerCase()}:'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
          ),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '$_guests',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _guests < 20 ? () => setState(() => _guests++) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFields() {
    if (!_isRestaurant && !_isTourLike && !_isCulture) {
      return const SizedBox.shrink();
    }

    return _buildSectionCard(
      title: 'Service Preferences',
      child: Column(
        children: [
          if (_isRestaurant || _isTourLike)
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: 'Preferred Time',
                hintText: 'e.g. 14:00',
              ),
            ),
          if (_isTourLike) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Expected Duration',
                hintText: 'e.g. 3 hours',
              ),
            ),
          ],
          if (_isCulture) ...[
            DropdownButtonFormField<String>(
              value: _cultureServiceType,
              decoration: const InputDecoration(
                labelText: 'Culture service type',
              ),
              items: const [
                DropdownMenuItem(value: 'Performance', child: Text('Performance')),
                DropdownMenuItem(value: 'Workshop', child: Text('Workshop')),
                DropdownMenuItem(value: 'Crafts', child: Text('Crafts')),
                DropdownMenuItem(value: 'Exhibition', child: Text('Exhibition')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _cultureServiceType = value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _cultureEngagement,
              decoration: const InputDecoration(
                labelText: 'Engagement',
              ),
              items: const [
                DropdownMenuItem(value: 'Hire', child: Text('Hire')),
                DropdownMenuItem(value: 'Buy', child: Text('Buy')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _cultureEngagement = value);
              },
            ),
            if (_cultureEngagement == 'Buy') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _cultureQuantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'e.g. 3',
                ),
              ),
            ],
            if ((widget.additionalDetails?['cultureType'] ?? '')
                .toString()
                .trim()
                .isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    'Culture Type: ${widget.additionalDetails?['cultureType']}',
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Category-specific notes',
              hintText: 'Any specific request for this service type',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOnsCard() {
    if (_categoryAddOns.isEmpty) return const SizedBox.shrink();
    return _buildSectionCard(
      title: 'Add-ons (Optional)',
      child: Column(
        children: _categoryAddOns
            .map(
              (addon) => CheckboxListTile(
                title: Text(addon),
                value: _selectedAddOns.contains(addon),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedAddOns.add(addon);
                    } else {
                      _selectedAddOns.remove(addon);
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSpecialRequestsCard() {
    return _buildSectionCard(
      title: 'General Special Requests',
      child: TextField(
        controller: _specialRequestsController,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Any special requests?',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _buildPriceCard() {
    final unitLabel = _isAccommodation
        ? 'M${widget.pricePerNight.toStringAsFixed(0)} x $_nights nights'
        : 'M${widget.pricePerNight.toStringAsFixed(0)} x $_billableUnits $_billableLabel';
    return _buildSectionCard(
      title: 'Price Breakdown',
      child: Column(
        children: [
          _buildPriceRow(unitLabel, 'M${_subtotal.toStringAsFixed(0)}'),
          const Divider(),
          _buildPriceRow(
            'Service fee (${(_serviceFeeRate * 100).toStringAsFixed(0)}%)',
            'M${_serviceFee.toStringAsFixed(0)}',
          ),
          if (_selectedAddOns.isNotEmpty) ...[
            const Divider(),
            _buildPriceRow('Add-ons', 'M${_addOnsTotal.toStringAsFixed(0)}'),
          ],
          const Divider(),
          _buildPriceRow('Total', 'M${_grandTotal.toStringAsFixed(0)}',
              isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book ${widget.listingCategory}'),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            widget.listingTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hosted by ${widget.vendorName}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 6),
                          Chip(
                            label: Text(widget.listingCategory),
                            backgroundColor: ColorPalette.primaryGreen
                                .withValues(alpha: 0.12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDateCard(),
                  const SizedBox(height: 16),
                  _buildGuestCard(),
                  const SizedBox(height: 16),
                  _buildCategoryFields(),
                  if (_isRestaurant || _isTourLike || _isCulture)
                    const SizedBox(height: 16),
                  _buildAddOnsCard(),
                  if (_categoryAddOns.isNotEmpty) const SizedBox(height: 16),
                  _buildSpecialRequestsCard(),
                  const SizedBox(height: 16),
                  _buildPriceCard(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _proceedToPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorPalette.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Continue to Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPriceRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? ColorPalette.primaryGreen : null,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateAddOnsPrice() {
    double total = 0;
    for (final addon in _selectedAddOns) {
      final lower = addon.toLowerCase();
      if (lower.contains('day')) {
        if (_isAccommodation) {
          total += (addon.contains('M150') ? 150 : 500) * _nights;
        } else {
          total += (addon.contains('M150') ? 150 : 500) * _billableUnits;
        }
      } else if (addon.contains('M300')) {
        total += 300;
      } else if (addon.contains('M250')) {
        total += 250;
      } else if (addon.contains('M220')) {
        total += 220;
      } else if (addon.contains('M200')) {
        total += 200;
      } else if (addon.contains('M180')) {
        total += 180;
      } else if (addon.contains('M120')) {
        total += 120;
      } else if (addon.contains('M450')) {
        total += 450;
      }
    }
    return total;
  }
}
