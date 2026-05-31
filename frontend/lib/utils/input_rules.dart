import 'package:flutter/services.dart';

class InputRules {
  static final name = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÿ .'-]")),
  ];

  static final businessName = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z0-9À-ÿ .,'&()-]")),
  ];

  static final address = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z0-9À-ÿ .,'/#()-]")),
  ];

  static final email = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9@._%+\-]')),
  ];

  static final phone = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
  ];

  static final digits = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
  ];

  static final decimal = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  ];

  static String? requiredName(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter $label';
    if (!RegExp(r"^[A-Za-zÀ-ÿ .'-]+$").hasMatch(text)) {
      return '$label can only contain letters';
    }
    return null;
  }

  static String? requiredBusinessText(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter $label';
    if (!RegExp(r"^[A-Za-z0-9À-ÿ .,'&()-]+$").hasMatch(text)) {
      return '$label contains unsupported characters';
    }
    return null;
  }

  static String? optionalPhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 8) return 'Enter a valid phone number';
    return null;
  }

  static String? requiredEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your email';
    final valid = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
    if (!valid.hasMatch(text)) return 'Please enter a valid email';
    return null;
  }
}
