// lib/screens/vendor/vendor_listings_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/listing.dart';
import '../../providers/listing_provider.dart';
import '../../providers/locale_provider.dart';
import '../../core/themes/color_palette.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';

class _CategoryFieldConfig {
  final String key;
  final String label;
  final String hint;
  final List<String>? options;

  const _CategoryFieldConfig({
    required this.key,
    required this.label,
    required this.hint,
    this.options,
  });
}

class _CategoryFormConfig {
  final String titleLabel;
  final String titleHint;
  final String descriptionLabel;
  final String descriptionHint;
  final String priceLabel;
  final String priceUnit;
  final String locationLabel;
  final String locationHint;
  final String sectionTitle;
  final String sectionDescription;
  final List<_CategoryFieldConfig> fields;

  const _CategoryFormConfig({
    required this.titleLabel,
    required this.titleHint,
    required this.descriptionLabel,
    required this.descriptionHint,
    required this.priceLabel,
    required this.priceUnit,
    required this.locationLabel,
    required this.locationHint,
    required this.sectionTitle,
    required this.sectionDescription,
    required this.fields,
  });
}

class _ListingMediaItem {
  final String id;
  final String? existingUrl;
  final Uint8List? bytes;

  const _ListingMediaItem({
    required this.id,
    this.existingUrl,
    this.bytes,
  });
}

class VendorListingsScreen extends StatefulWidget {
  final String initialCategory;

  const VendorListingsScreen({
    super.key,
    this.initialCategory = 'Accommodation',
  });

  @override
  State<VendorListingsScreen> createState() => _VendorListingsScreenState();
}

class _VendorListingsScreenState extends State<VendorListingsScreen> {
  bool _isLoading = false;
  bool _isPickingImages = false;

  // Form controllers for add/edit
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _districtController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _videoLinksController = TextEditingController();
  final Map<String, TextEditingController> _detailControllers = {
    'stayType': TextEditingController(),
    'amenities': TextEditingController(),
    'checkInOut': TextEditingController(),
    'duration': TextEditingController(),
    'skillLevel': TextEditingController(),
    'whatToBring': TextEditingController(),
    'cultureType': TextEditingController(),
    'heritageFocus': TextEditingController(),
    'openingHours': TextEditingController(),
    'dressCode': TextEditingController(),
    'difficulty': TextEditingController(),
    'safetyNotes': TextEditingController(),
    'requirements': TextEditingController(),
    'cuisineType': TextEditingController(),
    'signatureDish': TextEditingController(),
    'reservationInfo': TextEditingController(),
    'meetingPoint': TextEditingController(),
    'groupSize': TextEditingController(),
    'includes': TextEditingController(),
  };
  String _selectedCategory = 'Accommodation';
  String _selectedPriceUnit = '/night';
  bool _isEditing = false;
  String? _editingId;
  List<_ListingMediaItem> _mediaItems = [];
  int _mediaSeed = 0;
  final LocationService _locationService = LocationService();

  final List<String> _categories = [
    'Accommodation',
    'Experience',
    'Culture',
    'Adventure',
    'Restaurant',
    'Tour',
  ];

  final Map<String, _CategoryFormConfig> _categoryConfigs = const {
    'Accommodation': _CategoryFormConfig(
      titleLabel: 'Property name',
      titleHint: 'Maliba Mountain Lodge',
      descriptionLabel: 'Stay description',
      descriptionHint: 'Describe the rooms, atmosphere, and guest experience',
      priceLabel: 'Price per night (M)',
      priceUnit: '/night',
      locationLabel: 'Property location',
      locationHint: 'Village, lodge area, or nearby landmark',
      sectionTitle: 'Stay Details',
      sectionDescription: 'Show guests what kind of stay they are booking.',
      fields: [
        _CategoryFieldConfig(
            key: 'stayType',
            label: 'Stay type',
            hint: 'Lodge, guesthouse, chalet'),
        _CategoryFieldConfig(
            key: 'amenities',
            label: 'Amenities',
            hint: 'Wi-Fi, breakfast, mountain view'),
        _CategoryFieldConfig(
            key: 'checkInOut',
            label: 'Check-in / check-out',
            hint: 'Check-in 14:00, check-out 10:00'),
      ],
    ),
    'Experience': _CategoryFormConfig(
      titleLabel: 'Experience title',
      titleHint: 'Basotho cooking class',
      descriptionLabel: 'Experience description',
      descriptionHint: 'Explain what guests will do and feel',
      priceLabel: 'Price per person (M)',
      priceUnit: '/person',
      locationLabel: 'Experience location',
      locationHint: 'Studio, village, farm, or meeting spot',
      sectionTitle: 'Experience Details',
      sectionDescription: 'Help visitors understand the activity at a glance.',
      fields: [
        _CategoryFieldConfig(
            key: 'duration', label: 'Duration', hint: '2 hours'),
        _CategoryFieldConfig(
            key: 'skillLevel', label: 'Skill level', hint: 'Beginner friendly'),
        _CategoryFieldConfig(
            key: 'whatToBring',
            label: 'What to bring',
            hint: 'Comfortable shoes, water'),
      ],
    ),
    'Culture': _CategoryFormConfig(
      titleLabel: 'Cultural venue or activity',
      titleHint: 'Thaba Bosiu heritage walk',
      descriptionLabel: 'Cultural story',
      descriptionHint: 'Explain the heritage, meaning, and visitor journey',
      priceLabel: 'Entry price (M)',
      priceUnit: '/entry',
      locationLabel: 'Cultural site',
      locationHint: 'Museum, village, monument, or heritage site',
      sectionTitle: 'Cultural Details',
      sectionDescription:
          'Make it easy for visitors to understand the cultural value.',
      fields: [
        _CategoryFieldConfig(
          key: 'cultureType',
          label: 'Culture type',
          hint: 'Select culture type',
          options: [
            'Crafts',
            'Music',
            'Dance',
            'Art',
            'Food Heritage',
            'Storytelling',
            'History',
            'Traditional Wear',
            'Architecture',
            'Spiritual Heritage',
            'Festival',
          ],
        ),
        _CategoryFieldConfig(
            key: 'heritageFocus',
            label: 'Heritage focus',
            hint: 'History, crafts, music, storytelling'),
        _CategoryFieldConfig(
            key: 'openingHours',
            label: 'Opening hours',
            hint: 'Mon-Sat 08:00-17:00'),
        _CategoryFieldConfig(
            key: 'dressCode',
            label: 'Visitor notes',
            hint: 'Respectful clothing, no flash photography'),
      ],
    ),
    'Adventure': _CategoryFormConfig(
      titleLabel: 'Adventure title',
      titleHint: 'Sani Pass trail ride',
      descriptionLabel: 'Adventure description',
      descriptionHint: 'Highlight the thrill, route, and safety expectations',
      priceLabel: 'Price per person (M)',
      priceUnit: '/person',
      locationLabel: 'Adventure base',
      locationHint: 'Trailhead, mountain pass, or start point',
      sectionTitle: 'Adventure Details',
      sectionDescription: 'Tell visitors what level of challenge to expect.',
      fields: [
        _CategoryFieldConfig(
            key: 'difficulty',
            label: 'Difficulty level',
            hint: 'Moderate to hard'),
        _CategoryFieldConfig(
            key: 'safetyNotes',
            label: 'Safety notes',
            hint: 'Helmet provided, guide required'),
        _CategoryFieldConfig(
            key: 'requirements',
            label: 'Requirements',
            hint: 'Minimum age, fitness, gear'),
      ],
    ),
    'Restaurant': _CategoryFormConfig(
      titleLabel: 'Restaurant name',
      titleHint: 'Maseru Fireside Kitchen',
      descriptionLabel: 'Dining description',
      descriptionHint: 'Describe the menu, atmosphere, and signature taste',
      priceLabel: 'Average spend (M)',
      priceUnit: '',
      locationLabel: 'Restaurant location',
      locationHint: 'Street, mall, or neighborhood',
      sectionTitle: 'Dining Details',
      sectionDescription: 'Help guests choose the restaurant quickly.',
      fields: [
        _CategoryFieldConfig(
            key: 'cuisineType',
            label: 'Cuisine type',
            hint: 'Basotho, grill, cafe'),
        _CategoryFieldConfig(
            key: 'signatureDish',
            label: 'Signature dish',
            hint: 'Slow-cooked lamb platter'),
        _CategoryFieldConfig(
            key: 'reservationInfo',
            label: 'Reservations',
            hint: 'Walk-ins welcome or booking required'),
      ],
    ),
    'Tour': _CategoryFormConfig(
      titleLabel: 'Tour name',
      titleHint: 'Katse Dam day tour',
      descriptionLabel: 'Tour description',
      descriptionHint: 'Explain stops, timing, and what is included',
      priceLabel: 'Price per group/person (M)',
      priceUnit: '/group',
      locationLabel: 'Starting point',
      locationHint: 'Pickup point or departure location',
      sectionTitle: 'Tour Details',
      sectionDescription: 'Give travelers the key planning details upfront.',
      fields: [
        _CategoryFieldConfig(
            key: 'meetingPoint',
            label: 'Meeting point',
            hint: 'Maseru Mall main gate'),
        _CategoryFieldConfig(
            key: 'groupSize', label: 'Group size', hint: 'Up to 10 people'),
        _CategoryFieldConfig(
            key: 'includes',
            label: 'Includes',
            hint: 'Transport, guide, lunch'),
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    final category = _categoryConfigs.containsKey(widget.initialCategory)
        ? widget.initialCategory
        : 'Accommodation';
    _selectedCategory = category;
    _selectedPriceUnit = _categoryConfigs[category]!.priceUnit;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _districtController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _videoLinksController.dispose();
    for (final controller in _detailControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  _CategoryFormConfig get _currentCategoryConfig =>
      _categoryConfigs[_selectedCategory] ?? _categoryConfigs['Accommodation']!;

  String? get _resolvedVendorId {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.user?.userId?.toString() ?? authProvider.user?.id;
  }

  String? get _resolvedVendorName {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final name = authProvider.user?.name.trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    return name;
  }

  void _clearDetailControllers() {
    for (final controller in _detailControllers.values) {
      controller.clear();
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _locationController.clear();
    _districtController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _videoLinksController.clear();
    _clearDetailControllers();
    final category = _categoryConfigs.containsKey(widget.initialCategory)
        ? widget.initialCategory
        : 'Accommodation';
    _selectedCategory = category;
    _selectedPriceUnit = _categoryConfigs[category]!.priceUnit;
    _isEditing = false;
    _editingId = null;
    _mediaItems = [];
  }

  void _editListing(Listing listing) {
    _titleController.text = listing.title;
    _descriptionController.text = listing.description;
    _priceController.text = listing.price.toString();
    _locationController.text = listing.location;
    _districtController.text = listing.district ?? '';
    _latitudeController.text = listing.latitude?.toString() ?? '';
    _longitudeController.text = listing.longitude?.toString() ?? '';
    final videoLinks = listing.additionalDetails?['videoLinks'];
    if (videoLinks is List) {
      _videoLinksController.text =
          videoLinks.map((v) => v.toString()).join(', ');
    } else if (videoLinks is String) {
      _videoLinksController.text = videoLinks;
    } else {
      _videoLinksController.clear();
    }
    _selectedCategory = listing.category;
    _selectedPriceUnit = (listing.priceUnit?.isNotEmpty ?? false)
        ? listing.priceUnit!
        : (_categoryConfigs[listing.category]?.priceUnit ?? '/night');
    _isEditing = true;
    _editingId = listing.id;
    _clearDetailControllers();
    listing.additionalDetails?.forEach((key, value) {
      if (_detailControllers.containsKey(key)) {
        _detailControllers[key]!.text = value?.toString() ?? '';
      }
    });
    _mediaItems = [];
    final urls = <String>{};
    if (listing.images != null) {
      urls.addAll(
        listing.images!.map((img) => img.trim()).where((img) => img.isNotEmpty),
      );
    }
    if (listing.imageUrl != null && listing.imageUrl!.trim().isNotEmpty) {
      urls.add(listing.imageUrl!.trim());
    }
    for (final url in urls) {
      _mediaItems.add(
        _ListingMediaItem(
          id: 'media_${_mediaSeed++}',
          existingUrl: url,
        ),
      );
    }
    _showAddEditDialog();
  }

  Future<List<XFile>?> _pickImagesWithFilePicker() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files
        .where((file) => file.bytes != null)
        .map((file) => XFile.fromData(file.bytes!, name: file.name))
        .toList();
  }

  Future<void> _pickImages(
      StateSetter setStateDialog, ImageSource source) async {
    if (_isPickingImages) return;

    setStateDialog(() => _isPickingImages = true);

    try {
      List<XFile>? pickedFiles;

      if (source == ImageSource.gallery) {
        if (kIsWeb) {
          pickedFiles = await _pickImagesWithFilePicker();
        } else {
          try {
            pickedFiles = await ImagePicker().pickMultiImage(
              imageQuality: 70,
              maxWidth: 1024,
              maxHeight: 1024,
            );
          } catch (_) {
            final picked = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 70,
              maxWidth: 1024,
              maxHeight: 1024,
            );
            pickedFiles = picked == null ? null : [picked];
          }
        }
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        pickedFiles = picked == null ? null : [picked];
      }

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        final List<Uint8List> newImages = [];
        final remainingSlots = (12 - _mediaItems.length).clamp(0, 12);
        if (remainingSlots == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Portfolio can have up to 12 images.'),
              ),
            );
          }
          return;
        }
        for (final img in pickedFiles.take(remainingSlots)) {
          final bytes = await img.readAsBytes();
          newImages.add(bytes);
        }

        setStateDialog(() {
          _mediaItems.addAll(
            newImages.map(
              (bytes) => _ListingMediaItem(
                id: 'media_${_mediaSeed++}',
                bytes: bytes,
              ),
            ),
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Portfolio now has ${_mediaItems.length} image${_mediaItems.length == 1 ? '' : 's'}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setStateDialog(() => _isPickingImages = false);
    }
  }

  Map<String, dynamic> _collectAdditionalDetails() {
    final details = <String, dynamic>{};
    for (final field in _currentCategoryConfig.fields) {
      final value = _detailControllers[field.key]?.text.trim() ?? '';
      if (value.isNotEmpty) {
        details[field.key] = value;
      }
    }

    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude != null) {
      details['latitude'] = latitude;
    }
    if (longitude != null) {
      details['longitude'] = longitude;
    }

    final rawVideos = _videoLinksController.text.trim();
    if (rawVideos.isNotEmpty) {
      final links = rawVideos
          .split(RegExp(r'[\n,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (links.isNotEmpty) {
        details['videoLinks'] = links;
      }
    }
    return details;
  }

  Future<void> _useCurrentLocation(LocaleProvider locale) async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locale.translate(
                'Could not access your location right now.',
                'Sebaka sa hao ha sea fumaneha hona jwale.',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale.translate(
              'Current coordinates added to this listing.',
              'Dikhokahano tsa sebaka sa jwale di kentsoe mona.',
            ),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale.translate(
              'Location capture failed.',
              'Ho nka sebaka ho hlolehile.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceSheet(
      StateSetter setStateDialog, LocaleProvider locale) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  locale.translate(
                      'Choose Image Source', 'Khetha mohloli oa setšoantšo'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(locale.translate('Gallery', 'Galerie')),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages(setStateDialog, ImageSource.gallery);
                  },
                ),
                if (!kIsWeb)
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: Text(locale.translate('Camera', 'Khamera')),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImages(setStateDialog, ImageSource.camera);
                    },
                  ),
                if (kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      locale.translate(
                        'Camera upload is not supported on web. Use Gallery.',
                        "Palo ea khamera ha e ts'ehetsoe oebo. Sebelisa Galerie.",
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showCategoryPicker({String? initialCategory}) async {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale.translate(
                      'Choose Listing Category', 'Khetha Sehlopha sa Lintlha'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ColorPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._categories.map((category) {
                  final isSelected = category == initialCategory;
                  return ListTile(
                    leading: Icon(
                      _getCategoryIcon(category),
                      color: isSelected
                          ? ColorPalette.primaryGreen
                          : ColorPalette.textSecondary,
                    ),
                    title: Text(category),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: ColorPalette.primaryGreen)
                        : null,
                    onTap: () => Navigator.pop(context, category),
                  );
                }),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startAddListingFlow() async {
    _resetForm();
    final picked =
        await _showCategoryPicker(initialCategory: _selectedCategory);
    if (picked == null) return;
    setState(() {
      _selectedCategory = picked;
      _selectedPriceUnit = _categoryConfigs[picked]?.priceUnit ?? '/night';
      _clearDetailControllers();
    });
    _showAddEditDialog();
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Accommodation':
        return Icons.hotel;
      case 'Experience':
        return Icons.explore;
      case 'Culture':
        return Icons.museum;
      case 'Adventure':
        return Icons.terrain;
      case 'Restaurant':
        return Icons.restaurant;
      case 'Tour':
        return Icons.tour;
      default:
        return Icons.place;
    }
  }

  Future<void> _saveListing() async {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final parsedPrice = double.tryParse(_priceController.text.trim());
    if (parsedPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    if (_selectedCategory == 'Culture' &&
        (_detailControllers['cultureType']?.text.trim().isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a culture type')),
      );
      return;
    }

    if (_selectedCategory == 'Accommodation' && _mediaItems.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accommodation listings need at least 3 photos.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final listingProvider =
        Provider.of<ListingProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final vendorId = _resolvedVendorId;
    final vendorName = _resolvedVendorName;

    if (vendorId == null ||
        vendorId.trim().isEmpty ||
        vendorName == null ||
        vendorName.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale.translate(
              'Could not verify your vendor account. Please log in again.',
              'Akhaonte ea morekisi ha e fumanehe. Kena hape.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      bool success;
      final additionalDetails = _collectAdditionalDetails();

      // Convert images to base64 strings for storage while preserving visual order.
      final List<String> imageUrls = [];
      for (final item in _mediaItems) {
        if (item.existingUrl != null && item.existingUrl!.isNotEmpty) {
          imageUrls.add(item.existingUrl!);
          continue;
        }
        if (item.bytes != null) {
          final base64Image =
              'data:image/jpeg;base64,${base64Encode(item.bytes!)}';
          imageUrls.add(base64Image);
        }
      }

      final String? mainImageUrl =
          imageUrls.isNotEmpty ? imageUrls.first : null;

      if (_isEditing && _editingId != null) {
        final updatedListing = Listing(
          id: _editingId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: parsedPrice,
          priceUnit: _selectedPriceUnit,
          location: _locationController.text.trim(),
          district: _districtController.text.isNotEmpty
              ? _districtController.text.trim()
              : null,
          category: _selectedCategory,
          additionalDetails:
              additionalDetails.isEmpty ? null : additionalDetails,
          vendorId: vendorId,
          vendorName: vendorName,
          imageUrl: mainImageUrl,
          images: imageUrls,
          isAvailable: true,
          isFeatured: false,
          rating: null,
          reviewCount: null,
        );

        success = await listingProvider.updateListing(updatedListing);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locale.translate(
                  'Listing updated', 'Lintlha li ntlafalitsoe')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final newListing = Listing(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: parsedPrice,
          priceUnit: _selectedPriceUnit,
          location: _locationController.text.trim(),
          district: _districtController.text.isNotEmpty
              ? _districtController.text.trim()
              : null,
          category: _selectedCategory,
          additionalDetails:
              additionalDetails.isEmpty ? null : additionalDetails,
          vendorId: vendorId,
          vendorName: vendorName,
          imageUrl: mainImageUrl,
          images: imageUrls,
          isAvailable: true,
          isFeatured: false,
          rating: null,
          reviewCount: null,
        );

        success = await listingProvider.addListing(newListing);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(locale.translate('Listing added', 'Lintlha li kentsoe')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(listingProvider.error ?? 'Failed to save listing'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _resetForm();
      if (!mounted) return;
      Navigator.pop(context);
      unawaited(listingProvider.syncListingsSilently());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddEditDialog() {
    final locale = Provider.of<LocaleProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final config = _currentCategoryConfig;
          return AlertDialog(
            backgroundColor: ColorPalette.lightGreen,
            title: Text(_isEditing
                ? locale.translate('Edit Listing', 'Ntlafatsa Lintlha')
                : locale.translate(
                    'Add New Listing', 'Kenya Lintlha tse Ncha')),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.62,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ColorPalette.primaryGreen
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(_selectedCategory),
                                  size: 18,
                                  color: ColorPalette.primaryGreen,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedCategory,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: ColorPalette.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!_isEditing) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final nextCategory = await _showCategoryPicker(
                                initialCategory: _selectedCategory,
                              );
                              if (nextCategory == null) return;
                              setStateDialog(() {
                                _selectedCategory = nextCategory;
                                _selectedPriceUnit =
                                    _categoryConfigs[nextCategory]!.priceUnit;
                                _clearDetailControllers();
                              });
                            },
                            child: Text(
                              locale.translate('Change', 'Fetola'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: config.titleLabel,
                        hintText: config.titleHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: config.descriptionLabel,
                        hintText: config.descriptionHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Price
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: config.priceLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Location
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: config.locationLabel,
                        hintText: config.locationHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // District
                    TextField(
                      controller: _districtController,
                      decoration: InputDecoration(
                        labelText: locale.translate('District', 'Setereke'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              ColorPalette.primaryGreen.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locale.translate(
                              'Location Services',
                              'Ditshebeletso tsa Sebaka',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ColorPalette.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            locale.translate(
                              'Add coordinates so tourists can calculate distance, open maps, and get directions.',
                              'Kenya dikhokahano hore bahahlauli ba bone sebaka, dimmapa, le tsela.',
                            ),
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _useCurrentLocation(locale),
                              icon: const Icon(Icons.my_location),
                              label: Text(
                                locale.translate(
                                  'Use My Current Location',
                                  'Sebedisa Sebaka sa Ka sa Jwale',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _latitudeController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude',
                                    hintText: '-29.3156',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _longitudeController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude',
                                    hintText: '27.4869',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              ColorPalette.primaryGreen.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.sectionTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ColorPalette.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            config.sectionDescription,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    for (final field in config.fields) ...[
                      if (field.options != null)
                        DropdownButtonFormField<String>(
                          initialValue: (field.options!.contains(
                                  _detailControllers[field.key]?.text.trim()))
                              ? _detailControllers[field.key]?.text.trim()
                              : null,
                          decoration: InputDecoration(
                            labelText: field.label,
                            hintText: field.hint,
                            border: const OutlineInputBorder(),
                          ),
                          items: field.options!
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option,
                                  child: Text(option),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setStateDialog(() {
                              _detailControllers[field.key]?.text = value ?? '';
                            });
                          },
                        )
                      else
                        TextField(
                          controller: _detailControllers[field.key],
                          decoration: InputDecoration(
                            labelText: field.label,
                            hintText: field.hint,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: _videoLinksController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: locale.translate(
                          'Video links (optional)',
                          'Dikgokahanyo tsa video (ha di qobellwe)',
                        ),
                        hintText: 'https://youtube.com/... , https://...',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.ondemand_video),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Photos Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        locale.translate(
                            'Listing Photos', 'Litšoantšo tsa Lintlha'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_mediaItems.isNotEmpty)
                      ..._buildMediaPreview(setStateDialog, locale),

                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isPickingImages
                          ? null
                          : () => _showImageSourceSheet(setStateDialog, locale),
                      icon: _isPickingImages
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined),
                      label: Text(locale.translate(
                          'Choose Photo Source', 'Khetha Moea oa Setšoantšo')),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _mediaItems.isEmpty
                          ? null
                          : () => setStateDialog(() => _mediaItems = []),
                      icon: const Icon(Icons.clear),
                      label: Text(locale.translate(
                          'Clear Pictures', 'Tlosa Litšoantšo')),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _resetForm();
                  Navigator.pop(context);
                },
                child: Text(locale.translate('Cancel', 'Hlakola')),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveListing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorPalette.primaryGreen,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_isEditing
                        ? locale.translate('Update', 'Ntlafatsa')
                        : locale.translate('Add', 'Kenya')),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildMediaPreview(
      StateSetter setStateDialog, LocaleProvider locale) {
    return [
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          locale.translate(
            'Reorder portfolio images',
            'Hlophisa litshwantsho tsa porofolio',
          ),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_mediaItems.length, (index) {
            final media = _mediaItems[index];
            final imageWidget = media.existingUrl != null
                ? _buildPreviewImage(media.existingUrl!)
                : Image.memory(
                    media.bytes!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  );

            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: imageWidget,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: InkWell(
                          onTap: () {
                            setStateDialog(() => _mediaItems.removeAt(index));
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        onPressed: index == 0
                            ? null
                            : () {
                                setStateDialog(() {
                                  final item = _mediaItems.removeAt(index);
                                  _mediaItems.insert(index - 1, item);
                                });
                              },
                        icon: const Icon(Icons.arrow_left),
                        visualDensity: VisualDensity.compact,
                        splashRadius: 16,
                      ),
                      IconButton(
                        onPressed: index == _mediaItems.length - 1
                            ? null
                            : () {
                                setStateDialog(() {
                                  final item = _mediaItems.removeAt(index);
                                  _mediaItems.insert(index + 1, item);
                                });
                              },
                        icon: const Icon(Icons.arrow_right),
                        visualDensity: VisualDensity.compact,
                        splashRadius: 16,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    ];
  }

  Widget _buildPreviewImage(String image) {
    if (image.startsWith('assets/')) {
      return Image.asset(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[200],
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported),
        ),
      );
    }

    if (image.startsWith('data:image')) {
      final parts = image.split(',');
      if (parts.length == 2) {
        return Image.memory(
          base64Decode(parts[1]),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[200],
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported),
          ),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: image,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(
          color: ColorPalette.primaryGreen,
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final listingProvider = Provider.of<ListingProvider>(context);
    final vendorUserId =
        authProvider.user?.userId?.toString() ?? authProvider.user?.id;
    final listings = listingProvider.allListings
        .where((listing) => listing.vendorId == vendorUserId)
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _startAddListingFlow,
        backgroundColor: ColorPalette.primaryGreen,
        child: const Icon(Icons.add),
      ),
      body: listings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    locale.translate('No listings yet', 'Ha ho na lintlha'),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    locale.translate('Tap + to add your first listing',
                        'Tlanya + ho kenya lintlha tsa hao tsa pele'),
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _startAddListingFlow,
                    child:
                        Text(locale.translate('Add Listing', 'Kenya Lintlha')),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                final cultureType = listing.cultureType;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: listing.imageUrl != null &&
                                        listing.imageUrl!.isNotEmpty
                                    ? _buildPreviewImage(listing.imageUrl!)
                                    : (listing.images != null &&
                                            listing.images!.isNotEmpty
                                        ? _buildPreviewImage(
                                            listing.images!.first)
                                        : Icon(Icons.image,
                                            color: Colors.grey[400])),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    listing.title,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'M${listing.price.toStringAsFixed(0)}${listing.priceUnit ?? ''}',
                                    style: const TextStyle(
                                        color: ColorPalette.primaryGreen,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          listing.category,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue[700]),
                                        ),
                                      ),
                                      if (cultureType != null &&
                                          cultureType.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.purple
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            cultureType,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.purple[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      const Icon(Icons.location_on,
                                          size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        listing.location,
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editListing(listing);
                                } else if (value == 'delete') {
                                  _showDeleteDialog(listing);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listing.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showDeleteDialog(Listing listing) {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final listingProvider =
        Provider.of<ListingProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColorPalette.lightGreen,
        title: Text(locale.translate('Delete Listing', 'Hlakola Lintlha')),
        content: Text(locale.translate(
          'Are you sure you want to delete "${listing.title}"?',
          'Na u netefatsa hore u batla ho hlakola "${listing.title}"?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(locale.translate('Cancel', 'Hlakola')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await listingProvider.deleteListing(listing.id);
              if (!mounted) return;
              if (success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(locale.translate(
                        'Listing deleted', 'Lintlha li hlakotsoe')),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(listingProvider.error ??
                        locale.translate('Failed to delete listing',
                            'Ho hlolehile ho hlakola lintlha')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(locale.translate('Delete', 'Hlakola')),
          ),
        ],
      ),
    );
  }
}
