// lib/models/event.dart
class Event {
  final int eventId;
  final int vendorId;
  final String title;
  final String description;
  final String location;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? imageUrl;
  final double price;
  final String? category;
  final String status;
  final int? maxCapacity;
  final int ticketsSold;
  final int? ticketsRemaining;
  final String? vendorName;
  final String? organizer;
  final String? organizerName;
  final String? organizerEmail;
  final String? organizerPhone;
  final String? organizerWebsite;
  final String? ticketUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.eventId,
    required this.vendorId,
    required this.title,
    required this.description,
    required this.location,
    required this.startDateTime,
    required this.endDateTime,
    this.imageUrl,
    this.price = 0,
    this.category,
    this.status = 'upcoming',
    this.maxCapacity,
    this.ticketsSold = 0,
    this.ticketsRemaining,
    this.vendorName,
    this.organizer,
    this.organizerName,
    this.organizerEmail,
    this.organizerPhone,
    this.organizerWebsite,
    this.ticketUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    // Handle price that might be string or number
    double parsePrice(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Event(
      eventId: json['event_id'] ?? json['id'] ?? 0,
      vendorId: json['vendor_id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      startDateTime:
          DateTime.tryParse(json['start_datetime'] ?? '') ?? DateTime.now(),
      endDateTime:
          DateTime.tryParse(json['end_datetime'] ?? '') ?? DateTime.now(),
      imageUrl: json['image_url'],
      price: parsePrice(json['price']),
      category: json['category'],
      status: json['status'] ?? 'upcoming',
      maxCapacity: json['max_capacity'],
      ticketsSold: json['tickets_sold'] is int
          ? json['tickets_sold']
          : int.tryParse('${json['tickets_sold'] ?? 0}') ?? 0,
      ticketsRemaining: json['tickets_remaining'] == null
          ? null
          : (json['tickets_remaining'] is int
              ? json['tickets_remaining']
              : int.tryParse('${json['tickets_remaining']}')),
      vendorName: json['vendor_name'],
      organizer: json['organizer'],
      organizerName: json['organizer_name'] ?? json['organizer'],
      organizerEmail: json['organizer_email'],
      organizerPhone: json['organizer_phone'],
      organizerWebsite: json['organizer_website'],
      ticketUrl: json['ticket_url'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'vendor_id': vendorId,
      'title': title,
      'description': description,
      'location': location,
      'start_datetime': startDateTime.toIso8601String(),
      'end_datetime': endDateTime.toIso8601String(),
      'image_url': imageUrl,
      'price': price,
      'category': category,
      'status': status,
      'max_capacity': maxCapacity,
      'tickets_sold': ticketsSold,
      'tickets_remaining': ticketsRemaining,
      'vendor_name': vendorName,
      'organizer': organizer,
      'organizer_name': organizerName,
      'organizer_email': organizerEmail,
      'organizer_phone': organizerPhone,
      'organizer_website': organizerWebsite,
      'ticket_url': ticketUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Event copyWith({
    int? eventId,
    int? vendorId,
    String? title,
    String? description,
    String? location,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? imageUrl,
    double? price,
    String? category,
    String? status,
    int? maxCapacity,
    int? ticketsSold,
    int? ticketsRemaining,
    String? vendorName,
    String? organizer,
    String? organizerName,
    String? organizerEmail,
    String? organizerPhone,
    String? organizerWebsite,
    String? ticketUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      eventId: eventId ?? this.eventId,
      vendorId: vendorId ?? this.vendorId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      category: category ?? this.category,
      status: status ?? this.status,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      ticketsSold: ticketsSold ?? this.ticketsSold,
      ticketsRemaining: ticketsRemaining ?? this.ticketsRemaining,
      vendorName: vendorName ?? this.vendorName,
      organizer: organizer ?? this.organizer,
      organizerName: organizerName ?? this.organizerName,
      organizerEmail: organizerEmail ?? this.organizerEmail,
      organizerPhone: organizerPhone ?? this.organizerPhone,
      organizerWebsite: organizerWebsite ?? this.organizerWebsite,
      ticketUrl: ticketUrl ?? this.ticketUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isFree => price == 0;
  bool get isUpcoming =>
      status == 'upcoming' && startDateTime.isAfter(DateTime.now());
  bool get isOngoing =>
      status == 'ongoing' &&
      startDateTime.isBefore(DateTime.now()) &&
      endDateTime.isAfter(DateTime.now());
  bool get isEnded => status == 'ended' || endDateTime.isBefore(DateTime.now());
  bool get isCancelled => status == 'cancelled';
  bool get hasManagedTickets => (maxCapacity ?? 0) > 0;
  bool get isSoldOut => hasManagedTickets && (ticketsRemaining ?? 0) <= 0;

  String get formattedDate {
    if (startDateTime.year == endDateTime.year &&
        startDateTime.month == endDateTime.month &&
        startDateTime.day == endDateTime.day) {
      return '${startDateTime.day}/${startDateTime.month}/${startDateTime.year}';
    }
    return '${startDateTime.day}/${startDateTime.month} - ${endDateTime.day}/${endDateTime.month}/${endDateTime.year}';
  }

  String get formattedTime {
    final hour = startDateTime.hour;
    final minute = startDateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String get formattedDuration {
    final duration = endDateTime.difference(startDateTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return minutes > 0 ? '$hours hr $minutes min' : '$hours hr';
    }
    return '$minutes min';
  }
}
