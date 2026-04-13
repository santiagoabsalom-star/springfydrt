import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:springfydrt/features/cloud/cloud.dart';
import 'package:springfydrt/features/download/downloads.dart';
import 'package:springfydrt/features/playerpage/playerminiglobal.dart';
import 'package:springfydrt/features/session/sessionpage.dart';
import 'package:springfydrt/features/streaming/streaming.dart';

import '../../../home/home_page.dart';
import '../../navigation_controller.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final PreloadPageController _pageController = PreloadPageController();
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  final NavigationController _controller = NavigationController();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();

    _initConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    setState(() {
      _isConnected = !result.contains(ConnectivityResult.none);
      if (!_isConnected) {
        _controller.value = 2;
        _pageController.animateToPage(
          2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease);
            }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(

      valueListenable: _controller,
      builder: (context, index, _) {


        return Scaffold(

          body: Column(

            children: [
              Expanded(
                child: PreloadPageView(
                  preloadPagesCount: 4,
                  controller: _pageController,
                  physics: _isConnected ?
                  const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                  onPageChanged: (newIndex) {
                    if(_isConnected){
                    _controller.changeTab(newIndex);}
                    else{
                      showTopNotification(context, "Tienes que tener internet para navegar");
                    }
                  },
                  children: const [
                    HomePage(),
                    CloudPage(),
                    DownloadedSongsPage(),
                    StreamingPage(),
                    SessionPage(),
                  ],
                )
              ),
              const MiniPlayer(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: index,
            onTap: (tappedIndex) {
              if (!_isConnected && tappedIndex != 2) {
              showTopNotification(context, "Tienes que tener internet para navegar");
              return;
              }

              _controller.changeTab(tappedIndex);

              _pageController.animateToPage(
                tappedIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.ease,
              );
            },
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.search, color: _isConnected ? null : Colors.grey),
                label: 'Buscar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.cloud, color: _isConnected ? null : Colors.grey),
                label: 'Cloud',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.library_music),
                label: 'Biblioteca',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people, color: _isConnected ? null : Colors.grey),
                label: 'Duo',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person, color: _isConnected ? null : Colors.grey),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}