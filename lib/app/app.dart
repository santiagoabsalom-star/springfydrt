
import 'package:flutter/material.dart';
import 'package:springfydrt/features/login/loginpage.dart';

import 'package:springfydrt/features/navigation/presentation/pages/screenpash.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});




  @override
  Widget build(BuildContext context)  {
    return MaterialApp(
      title: 'Springfy',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
      ),
      themeMode: ThemeMode.dark,

      debugShowCheckedModeBanner: false,

      home:  const SplashScreen(),
    );
  }
}
