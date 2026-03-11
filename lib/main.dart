import 'package:flutter/material.dart';
import 'home.dart';

const String apiUrl = 'https://podfriendsapi.raphaelmoynat.com/api';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.white,
          ),
        ),
      ),
      title: 'PodFriends App',
      home: const HomePage(),

    );
  }
}
