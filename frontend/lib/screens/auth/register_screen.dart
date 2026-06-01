// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/themes/color_palette.dart';
import '../../utils/input_rules.dart';
import '../../utils/responsive_layout.dart';
import '../../utils/vendor_facility.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Vendor specific fields
  final _businessNameController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _districtController = TextEditingController();
  final _previousExperienceController = TextEditingController(text: '0');

  String _selectedRole = 'tourist';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _hasLicense = false;
  bool _licenseValid = false;
  bool _taxClearance = false;
  String _selectedFacilityKey = VendorFacilityTaxonomy.facilities.first.key;

  final List<String> _districts = [
    'Maseru',
    'Berea',
    'Leribe',
    'Butha-Buthe',
    'Mokhotlong',
    'Thaba-Tseka',
    'Mafeteng',
    'Mohale\'s Hoek',
    'Quthing',
    'Qacha\'s Nek',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessPhoneController.dispose();
    _businessAddressController.dispose();
    _businessTypeController.dispose();
    _districtController.dispose();
    _previousExperienceController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Conditions'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success;

    if (_selectedRole == 'tourist') {
      success = await authProvider.registerTourist(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );
    } else {
      final selectedFacility = VendorFacilityTaxonomy.facilities
          .firstWhere((item) => item.key == _selectedFacilityKey);
      final resolvedBusinessType = _businessTypeController.text.trim().isEmpty
          ? selectedFacility.businessTypes.first
          : _businessTypeController.text.trim();
      success = await authProvider.registerVendor(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        businessName: _businessNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        businessPhone: _businessPhoneController.text.trim().isEmpty
            ? null
            : _businessPhoneController.text.trim(),
        businessAddress: _businessAddressController.text.trim().isEmpty
            ? null
            : _businessAddressController.text.trim(),
        businessType: resolvedBusinessType,
        district: _districtController.text.trim().isEmpty
            ? null
            : _districtController.text.trim(),
        hasLicense: _hasLicense,
        licenseValid: _licenseValid,
        taxClearance: _taxClearance,
        previousExperience:
            int.tryParse(_previousExperienceController.text.trim()) ?? 0,
        rating: 3,
      );
    }

    if (success && mounted) {
      final user = authProvider.user;
      if (user != null) {
        if (user.emailVerificationSent) {
          final verified = await _showEmailVerificationDialog(user.email);
          if (!mounted || !verified) return;
        }

        if (user.isVendor) {
          final matchedCultureProfile = user.linkedCultureVendorId != null &&
              user.linkedCultureVendorId!.isNotEmpty;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                matchedCultureProfile
                    ? 'Registration successful! Your business was matched to an existing culture profile and is pending approval.'
                    : 'Registration successful! Your account is pending approval.',
              ),
              backgroundColor:
                  matchedCultureProfile ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        if (user.isAdmin) {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        } else if (user.isVendor) {
          if (user.isPendingVendor) {
            Navigator.pushReplacementNamed(context, '/login');
            return;
          }
          Navigator.pushReplacementNamed(context, '/vendor-dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/tourist-dashboard');
        }
      }
    }
  }

  Future<bool> _showEmailVerificationDialog(String email) async {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSubmitting = false;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Verify your email'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enter the 6-digit code we sent to $email.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: InputRules.digits,
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                        prefixIcon: Icon(Icons.mark_email_read_outlined),
                      ),
                      validator: (value) {
                        final code = value?.trim() ?? '';
                        if (code.length < 6) {
                          return 'Enter the code from your email';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Verify later'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);
                          final authProvider = Provider.of<AuthProvider>(
                            this.context,
                            listen: false,
                          );
                          final success = await authProvider.verifyEmail(
                            email: email,
                            code: codeController.text.trim(),
                          );
                          if (success && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                            return;
                          }
                          setDialogState(() => isSubmitting = false);
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    return verified ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final size = MediaQuery.of(context).size;
    final isVendor = _selectedRole == 'vendor';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/tourism_seed/katse_dam_1.jpg',
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorPalette.primaryGreen.withValues(alpha: 0.88),
                  const Color(0xFF0D3E43).withValues(alpha: 0.76),
                  Colors.white.withValues(alpha: 0.28),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : size.width * 0.2,
                vertical: 20,
              ),
              child: Column(
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Registration Form Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Role Selection
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _selectedRole = 'tourist'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _selectedRole == 'tourist'
                                            ? ColorPalette.primaryGreen
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Tourist',
                                          style: TextStyle(
                                            color: _selectedRole == 'tourist'
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _selectedRole = 'vendor'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _selectedRole == 'vendor'
                                            ? ColorPalette.primaryGreen
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Vendor',
                                          style: TextStyle(
                                            color: _selectedRole == 'vendor'
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Full Name
                          TextFormField(
                            controller: _nameController,
                            inputFormatters: InputRules.name,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: ColorPalette.primaryGreen,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                InputRules.requiredName(value, 'your name'),
                          ),
                          const SizedBox(height: 12),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            inputFormatters: InputRules.email,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: ColorPalette.primaryGreen,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: InputRules.requiredEmail,
                          ),
                          const SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: ColorPalette.primaryGreen,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Confirm Password
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_isConfirmPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: ColorPalette.primaryGreen,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Phone (Optional)
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: InputRules.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone (Optional)',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: ColorPalette.primaryGreen,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: InputRules.optionalPhone,
                          ),

                          // Vendor Specific Fields
                          if (isVendor) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text(
                              'Business Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: ColorPalette.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Business Name
                            TextFormField(
                              controller: _businessNameController,
                              inputFormatters: InputRules.businessName,
                              decoration: InputDecoration(
                                labelText: 'Business Name *',
                                prefixIcon: const Icon(Icons.store_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: ColorPalette.primaryGreen,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  InputRules.requiredBusinessText(
                                value,
                                'your business name',
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Business Phone
                            TextFormField(
                              controller: _businessPhoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: InputRules.phone,
                              decoration: InputDecoration(
                                labelText: 'Business Phone (Optional)',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: ColorPalette.primaryGreen,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              initialValue: _selectedFacilityKey,
                              decoration: InputDecoration(
                                labelText: 'Vendor Facility',
                                prefixIcon:
                                    const Icon(Icons.account_tree_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: ColorPalette.primaryGreen,
                                    width: 2,
                                  ),
                                ),
                              ),
                              items: VendorFacilityTaxonomy.facilities
                                  .map((facility) => DropdownMenuItem(
                                        value: facility.key,
                                        child: Text(facility.label),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                final facility = VendorFacilityTaxonomy
                                    .facilities
                                    .firstWhere((item) => item.key == value);
                                setState(() {
                                  _selectedFacilityKey = facility.key;
                                  _businessTypeController.text =
                                      facility.businessTypes.first;
                                });
                              },
                            ),
                            const SizedBox(height: 12),

                            // Business Type
                            DropdownButtonFormField<String>(
                              initialValue: _businessTypeController.text.isEmpty
                                  ? VendorFacilityTaxonomy.facilities
                                      .firstWhere((item) =>
                                          item.key == _selectedFacilityKey)
                                      .businessTypes
                                      .first
                                  : _businessTypeController.text,
                              decoration: InputDecoration(
                                labelText: 'Facility Subtype',
                                prefixIcon: const Icon(Icons.category_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: ColorPalette.primaryGreen,
                                    width: 2,
                                  ),
                                ),
                              ),
                              items: VendorFacilityTaxonomy.facilities
                                  .firstWhere((item) =>
                                      item.key == _selectedFacilityKey)
                                  .businessTypes
                                  .map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _businessTypeController.text = value ?? '';
                                });
                              },
                            ),
                            const SizedBox(height: 12),

                            // Business Address
                            TextFormField(
                              controller: _businessAddressController,
                              maxLines: 2,
                              inputFormatters: InputRules.address,
                              decoration: InputDecoration(
                                labelText: 'Business Address (Optional)',
                                prefixIcon:
                                    const Icon(Icons.location_on_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: ColorPalette.primaryGreen,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: InputRules.optionalPhone,
                            ),
                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              initialValue: _districtController.text.isEmpty
                                  ? null
                                  : _districtController.text,
                              decoration: InputDecoration(
                                labelText: 'District *',
                                prefixIcon:
                                    const Icon(Icons.location_city_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: ColorPalette.primaryGreen,
                                    width: 2,
                                  ),
                                ),
                              ),
                              items: _districts.map((district) {
                                return DropdownMenuItem(
                                  value: district,
                                  child: Text(district),
                                );
                              }).toList(),
                              onChanged: (value) {
                                _districtController.text = value ?? '';
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please select your district';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _previousExperienceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: InputRules.digits,
                              decoration: InputDecoration(
                                labelText: 'Years of Experience *',
                                prefixIcon: const Icon(Icons.timeline_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: ColorPalette.primaryGreen,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final years = int.tryParse(value?.trim() ?? '');
                                if (years == null || years < 0) {
                                  return 'Enter valid years of experience';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: ColorPalette.primaryGreen,
                              title: const Text('I have a business license'),
                              value: _hasLicense,
                              onChanged: (value) {
                                setState(() {
                                  _hasLicense = value ?? false;
                                  if (!_hasLicense) _licenseValid = false;
                                });
                              },
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: ColorPalette.primaryGreen,
                              title: const Text('My license is valid'),
                              value: _licenseValid,
                              onChanged: _hasLicense
                                  ? (value) {
                                      setState(() {
                                        _licenseValid = value ?? false;
                                      });
                                    }
                                  : null,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: ColorPalette.primaryGreen,
                              title: const Text('I have tax clearance'),
                              value: _taxClearance,
                              onChanged: (value) {
                                setState(() {
                                  _taxClearance = value ?? false;
                                });
                              },
                            ),
                            Text(
                              'These fields feed the ML verifier for automatic vendor approval. Vendors with missing documents can still register, but may remain pending for admin review.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],

                          if (authProvider.error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      authProvider.error!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Terms and Conditions
                          Row(
                            children: [
                              Checkbox(
                                value: _agreeToTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _agreeToTerms = value ?? false;
                                  });
                                },
                                activeColor: ColorPalette.primaryGreen,
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _agreeToTerms = !_agreeToTerms;
                                    });
                                  },
                                  child: RichText(
                                    text: const TextSpan(
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                      children: [
                                        TextSpan(text: 'I agree to the '),
                                        TextSpan(
                                          text: 'Terms of Service',
                                          style: TextStyle(
                                            color: ColorPalette.primaryGreen,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(text: ' and '),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: TextStyle(
                                            color: ColorPalette.primaryGreen,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Register Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorPalette.primaryGreen,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Sign Up',
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
                  ),

                  const SizedBox(height: 20),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
