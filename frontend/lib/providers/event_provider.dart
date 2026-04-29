// lib/providers/event_provider.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../models/payment.dart';

class EventProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Event> _allEvents = [];
  List<Event> _myEvents = [];
  List<Event> _upcomingEvents = [];
  bool _isLoading = false;
  bool _isUpcomingLoading = false;
  bool _isMyEventsLoading = false;
  bool _isOfflineMode = false;
  DateTime? _lastSyncedAt;
  String? _error;
  String? _selectedCategory;
  String? _selectedStatus;
  final Set<int> _interestedEventIds = <int>{};
  CacheService? _cacheService;

  List<Event> get allEvents => _allEvents;
  List<Event> get myEvents => _myEvents;
  List<Event> get upcomingEvents => _upcomingEvents;
  bool get isLoading => _isLoading;
  bool get isUpcomingLoading => _isUpcomingLoading;
  bool get isMyEventsLoading => _isMyEventsLoading;
  bool get isOfflineMode => _isOfflineMode;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  String? get selectedStatus => _selectedStatus;
  Set<int> get interestedEventIds => Set<int>.from(_interestedEventIds);

  int get totalEvents => _allEvents.length;
  int get totalUpcoming => _upcomingEvents.length;
  int get totalMyEvents => _myEvents.length;

  List<Event> get trendingEvents {
    return _upcomingEvents.where((e) => e.price > 100).toList();
  }

  Future<void> _initCache() async {
    final prefs = await SharedPreferences.getInstance();
    _cacheService = CacheService(prefs);
    _lastSyncedAt ??= _cacheService?.getEventsLastUpdated();
  }

  // Fetch all events (for admin)
  Future<bool> fetchAllEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/admin/events');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _allEvents =
              (data['events'] as List).map((e) => Event.fromJson(e)).toList();
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      _error = 'Failed to fetch events: ${response.statusCode}';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch upcoming events (for tourists)
  Future<bool> fetchUpcomingEvents() async {
    _isUpcomingLoading = true;
    _error = null;
    notifyListeners();

    await _initCache();
    try {
      final response = await _apiService.get('/events?upcoming=true');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _upcomingEvents =
              (data['events'] as List).map((e) => Event.fromJson(e)).toList();
          _isOfflineMode = false;
          await _cacheService?.saveUpcomingEvents(_upcomingEvents);
          _lastSyncedAt = _cacheService?.getEventsLastUpdated();
          _isUpcomingLoading = false;
          notifyListeners();
          return true;
        }
      }
      final cachedEvents = await _cacheService?.loadUpcomingEvents() ?? [];
      if (cachedEvents.isNotEmpty) {
        _upcomingEvents = cachedEvents;
        _isOfflineMode = true;
        _error = 'Offline mode: showing cached events';
        _lastSyncedAt = _cacheService?.getEventsLastUpdated();
      } else {
        _error = 'Failed to fetch upcoming events: ${response.statusCode}';
      }
      _isUpcomingLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      final cachedEvents = await _cacheService?.loadUpcomingEvents() ?? [];
      if (cachedEvents.isNotEmpty) {
        _upcomingEvents = cachedEvents;
        _isOfflineMode = true;
        _error = 'Offline mode: showing cached events';
        _lastSyncedAt = _cacheService?.getEventsLastUpdated();
      } else {
        _error = e.toString();
      }
      _isUpcomingLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch vendor's own events
  Future<bool> fetchMyEvents(int vendorId) async {
    _isMyEventsLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/events?vendor_id=$vendorId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _myEvents =
              (data['events'] as List).map((e) => Event.fromJson(e)).toList();
          _isMyEventsLoading = false;
          notifyListeners();
          return true;
        }
      }
      _error = 'Failed to fetch your events: ${response.statusCode}';
      _isMyEventsLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isMyEventsLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Event?> fetchEventById(int eventId) async {
    try {
      final response = await _apiService.get('/events/$eventId');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['event'] != null) {
          return Event.fromJson(data['event']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> purchaseTickets({
    required int eventId,
    required int quantity,
    required String paymentId,
    required PaymentMethod paymentMethod,
    required double totalAmount,
    required double serviceFee,
    String currency = 'LSL',
    String? buyerPhone,
  }) async {
    try {
      final response = await _apiService.post(
        '/events/$eventId/tickets/purchase',
        {
          'quantity': quantity,
          'paymentId': paymentId,
          'paymentStatus': 'paid',
          'paymentMethod': paymentMethod.name,
          'totalAmount': totalAmount,
          'serviceFee': serviceFee,
          'currency': currency,
          'buyerPhone': buyerPhone,
        },
      );

      final data = json.decode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true &&
          data['event'] != null) {
        final updatedEvent = Event.fromJson(data['event']);
        _replaceEvent(updatedEvent);
        notifyListeners();
        return {
          'event': updatedEvent,
          'orderId': data['orderId']?.toString(),
          'receiptNumber': data['receiptNumber']?.toString(),
        };
      }

      _error = data['message'] ?? data['error'] ?? 'Failed to reserve tickets';
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Create event
  Future<bool> createEvent(Map<String, dynamic> eventData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/admin/events', eventData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        _isLoading = false;
        notifyListeners();

        if (data['success'] == true) {
          return true;
        } else {
          _error = data['message'] ?? 'Failed to create event';
          return false;
        }
      }
      _error = 'Failed to create event: ${response.statusCode}';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update event
  Future<bool> updateEvent(int eventId, Map<String, dynamic> eventData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response =
          await _apiService.put('/admin/events/$eventId', eventData);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _isLoading = false;
        final success = data['success'] ?? false;
        if (success) {
          final refreshedEvent = await fetchEventById(eventId);
          if (refreshedEvent != null) {
            _replaceEvent(refreshedEvent);
          }
        }
        notifyListeners();
        return success;
      }
      _error = 'Failed to update event: ${response.statusCode}';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete event
  Future<bool> deleteEvent(int eventId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.delete('/admin/events/$eventId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _isLoading = false;
        notifyListeners();

        if (data['success'] == true) {
          _myEvents.removeWhere((e) => e.eventId == eventId);
          _upcomingEvents.removeWhere((e) => e.eventId == eventId);
          _allEvents.removeWhere((e) => e.eventId == eventId);
          notifyListeners();
          return true;
        }
        return false;
      }
      _error = 'Failed to delete event: ${response.statusCode}';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Mark interest in event (local state only)
  void markInterested(int eventId) {
    if (_upcomingEvents.any((e) => e.eventId == eventId)) {
      _interestedEventIds.add(eventId);
      notifyListeners();
    }
  }

  bool isInterested(int eventId) => _interestedEventIds.contains(eventId);

  void toggleInterest(int eventId) {
    if (_interestedEventIds.contains(eventId)) {
      _interestedEventIds.remove(eventId);
    } else {
      _interestedEventIds.add(eventId);
    }
    notifyListeners();
  }

  // Filter by category
  void filterByCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Filter by status
  void filterByStatus(String? status) {
    _selectedStatus = status;
    notifyListeners();
  }

  // Get filtered upcoming events
  List<Event> getFilteredUpcomingEvents() {
    var filtered = List<Event>.from(_upcomingEvents);

    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered =
          filtered.where((e) => e.category == _selectedCategory).toList();
    }

    if (_selectedStatus != null && _selectedStatus != 'All') {
      filtered = filtered.where((e) => e.status == _selectedStatus).toList();
    }

    return filtered;
  }

  // Clear filters
  void clearFilters() {
    _selectedCategory = null;
    _selectedStatus = null;
    notifyListeners();
  }

  // Refresh all data
  Future<void> refresh(int? vendorId) async {
    await fetchUpcomingEvents();
    if (vendorId != null && vendorId > 0) {
      await fetchMyEvents(vendorId);
    }
  }

  void _replaceEvent(Event updatedEvent) {
    _allEvents = _allEvents
        .map((event) =>
            event.eventId == updatedEvent.eventId ? updatedEvent : event)
        .toList();
    _myEvents = _myEvents
        .map((event) =>
            event.eventId == updatedEvent.eventId ? updatedEvent : event)
        .toList();
    _upcomingEvents = _upcomingEvents
        .map((event) =>
            event.eventId == updatedEvent.eventId ? updatedEvent : event)
        .toList();
  }
}
