import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/locale_provider.dart';

class LanguageSwitcher extends StatelessWidget {
  final bool showAsAppBarAction;

  const LanguageSwitcher({
    super.key,
    this.showAsAppBarAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        final isEnglish = localeProvider.locale.languageCode == 'en';

        if (showAsAppBarAction) {
          return PopupMenuButton<String>(
            onSelected: (value) async {
              await localeProvider.setLocale(value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'en',
                child: Text(
                  'English ${isEnglish ? '✓' : ''}',
                  style: TextStyle(
                    color: isEnglish ? Colors.green : Colors.black87,
                    fontWeight:
                        isEnglish ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'st',
                child: Text(
                  'Sesotho sa Lesotho ${!isEnglish ? '✓' : ''}',
                  style: TextStyle(
                    color: !isEnglish ? Colors.green : Colors.black87,
                    fontWeight:
                        !isEnglish ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
            icon: const Icon(Icons.language),
            tooltip: 'Change Language',
          );
        }

        return Container(
          margin: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Select Language'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text('English'),
                        trailing: isEnglish
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () async {
                          await localeProvider.setLocale('en');
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        title: const Text('Sesotho sa Lesotho'),
                        trailing: !isEnglish
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () async {
                          await localeProvider.setLocale('st');
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.language),
            label: Text(
              isEnglish ? 'English' : 'Sesotho sa Lesotho',
            ),
          ),
        );
      },
    );
  }
}
