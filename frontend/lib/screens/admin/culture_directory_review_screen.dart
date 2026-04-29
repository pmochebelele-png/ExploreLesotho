import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class CultureDirectoryReviewScreen extends StatefulWidget {
  const CultureDirectoryReviewScreen({super.key});

  @override
  State<CultureDirectoryReviewScreen> createState() =>
      _CultureDirectoryReviewScreenState();
}

class _CultureDirectoryReviewScreenState
    extends State<CultureDirectoryReviewScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String _statusFilter = 'all';
  String _subcategoryFilter = 'all';
  List<Map<String, dynamic>> _subcategories = [];
  List<Map<String, dynamic>> _vendors = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final subRes = await _api.get('/admin/culture/subcategories');
      final venRes = await _api.get(_buildVendorEndpoint());

      if (subRes.statusCode == 200) {
        final data = json.decode(subRes.body);
        _subcategories = List<Map<String, dynamic>>.from(
          data['subcategories'] ?? const [],
        );
      }

      if (venRes.statusCode == 200) {
        final data = json.decode(venRes.body);
        _vendors = List<Map<String, dynamic>>.from(data['vendors'] ?? const []);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load culture directory'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _buildVendorEndpoint() {
    final params = <String>[];
    final search = _searchController.text.trim();
    if (search.isNotEmpty) {
      params.add('search=${Uri.encodeQueryComponent(search)}');
    }
    if (_statusFilter != 'all') {
      params.add('status=${Uri.encodeQueryComponent(_statusFilter)}');
    }
    if (_subcategoryFilter != 'all') {
      params.add('subcategory=${Uri.encodeQueryComponent(_subcategoryFilter)}');
    }
    return params.isEmpty
        ? '/admin/culture/vendors'
        : '/admin/culture/vendors?${params.join('&')}';
  }

  Future<void> _saveVendor(Map<String, dynamic> payload) async {
    final id = payload['id']?.toString();
    if (id == null || id.isEmpty) return;

    try {
      final response = await _api.patch('/admin/culture/vendors/$id', payload);
      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context);
        await _loadAll();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Culture vendor updated'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error while updating vendor'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditDialog(Map<String, dynamic> vendor) {
    final nameController =
        TextEditingController(text: vendor['name']?.toString() ?? '');
    final productController =
        TextEditingController(text: vendor['productRange']?.toString() ?? '');
    final locationController =
        TextEditingController(text: vendor['location']?.toString() ?? '');
    final contactsController = TextEditingController(
      text: ((vendor['contacts'] as List?) ?? const [])
          .map((item) => item.toString())
          .join(', '),
    );
    String status =
        vendor['status']?.toString() == 'inactive' ? 'inactive' : 'active';
    final selectedSubcats = <String>{
      ...((vendor['subcategorySlugs'] as List?) ?? const [])
          .map((item) => item.toString()),
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review Culture Vendor'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Vendor name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: productController,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Products / Services'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contactsController,
                    decoration: const InputDecoration(
                      labelText: 'Contacts (comma separated)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Subcategories',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _subcategories.map((subcategory) {
                      final slug = subcategory['slug']?.toString() ?? '';
                      final selected = selectedSubcats.contains(slug);
                      return FilterChip(
                        label: Text(subcategory['name']?.toString() ?? slug),
                        selected: selected,
                        onSelected: (value) {
                          setDialogState(() {
                            if (value) {
                              selectedSubcats.add(slug);
                            } else {
                              selectedSubcats.remove(slug);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final payload = <String, dynamic>{
                  'id': vendor['id']?.toString(),
                  'name': nameController.text.trim(),
                  'productRange': productController.text.trim(),
                  'location': locationController.text.trim(),
                  'contacts': contactsController.text
                      .split(RegExp(r'[\n,]'))
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toList(),
                  'status': status,
                  'subcategorySlugs': selectedSubcats.toList(),
                };
                _saveVendor(payload);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search vendor/products/location',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All status')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _statusFilter = value);
                  _loadAll();
                },
              ),
              DropdownButton<String>(
                value: _subcategoryFilter,
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('All subtypes')),
                  ..._subcategories.map(
                    (item) => DropdownMenuItem(
                      value: item['slug']?.toString() ?? '',
                      child: Text(item['name']?.toString() ?? ''),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _subcategoryFilter = value);
                  _loadAll();
                },
              ),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _vendors.length,
                  itemBuilder: (context, index) {
                    final vendor = _vendors[index];
                    final subcats =
                        ((vendor['subcategories'] as List?) ?? const [])
                            .map((item) => item.toString())
                            .toList();
                    final contacts = ((vendor['contacts'] as List?) ?? const [])
                        .map((item) => item.toString())
                        .toList();

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(
                          vendor['name']?.toString() ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              vendor['productRange']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Location: ${vendor['location']?.toString() ?? '-'}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Contacts: ${contacts.join(' | ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: subcats
                                  .map(
                                    (item) => Chip(
                                      label: Text(
                                        item,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            if (vendor['isClaimed'] == true)
                              Chip(
                                label: const Text(
                                  'CLAIMED',
                                  style: TextStyle(fontSize: 10),
                                ),
                                backgroundColor:
                                    Colors.blue.withValues(alpha: 0.12),
                              ),
                            Chip(
                              label: Text(
                                (vendor['status']?.toString() ?? 'active')
                                    .toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              ),
                              backgroundColor:
                                  vendor['status']?.toString() == 'inactive'
                                      ? Colors.red.withValues(alpha: 0.12)
                                      : Colors.green.withValues(alpha: 0.12),
                            ),
                            IconButton(
                              onPressed: () => _showEditDialog(vendor),
                              icon: const Icon(Icons.edit),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
