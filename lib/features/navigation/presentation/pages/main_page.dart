import 'package:flutter/material.dart';
import 'package:springfydrt/features/cloud/cloud.dart';
import 'package:springfydrt/features/download/downloads.dart';
import 'package:springfydrt/features/playerpage/playerminiglobal.dart';
import '../../../home/home_page.dart';
import '../../navigation_controller.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final NavigationController _controller = NavigationController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _controller,
      builder: (context, index, _) {
        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: index,
                  children: const [
                    HomePage(),
                    CloudPage(),
                    DownloadedSongsPage()
                  ],
                ),
              ),
              const MiniPlayer(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: index,
            onTap: _controller.changeTab,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.cloud),
                label: 'Cloud',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.arrow_circle_down),
                label: 'Descargas',
              )
            ],
          ),
        );
      },
    );
  }

}
