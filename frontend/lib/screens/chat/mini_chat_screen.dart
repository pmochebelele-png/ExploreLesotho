
// lib/screens/chat/mini_chat_screen.dart
import 'package:flutter/material.dart';
import '../../core/themes/color_palette.dart';

class MiniChatScreen extends StatelessWidget {
  const MiniChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print('✅ MiniChatScreen built successfully');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini Chat Test'),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            print('⬅️ Back button pressed');
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            const Text(
              'Navigation is Working!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'You successfully navigated to this screen',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                print('⬅️ Go Back button pressed');
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorPalette.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}