import 'package:flutter/material.dart';
import '../features/navigation/presentation/pages/main_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Springfy',

      debugShowCheckedModeBanner: false,
      home: const MainPage(),
    );
  }
}
