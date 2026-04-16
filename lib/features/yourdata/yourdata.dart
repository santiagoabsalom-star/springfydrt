import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class YourDataPage extends StatefulWidget {
  const YourDataPage({super.key});

  @override
  State<YourDataPage> createState() => _YourDataPageState();
}

class _YourDataPageState extends State<YourDataPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus datos'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(

        ),
      );


  }
}