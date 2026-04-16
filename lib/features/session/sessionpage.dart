import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:springfydrt/features/login/loginpage.dart';
import 'package:springfydrt/features/notifier/notifier.dart';
import 'package:springfydrt/features/yourdata/yourdata.dart';

import '../../core/log.dart';
import '../login/api/token.dart';
import '../streaming/api/wsconnect.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? username = "Cargando...";
  String? duoName = "Cargando duo...";

  @override
  void initState() {
    super.initState();
    _obtenerUsername();
    _obtenerDuoUsername();
  }

  Future<void> _obtenerUsername() async {
    final token = await TokenStorage.getToken();

    if (token != null) {
      String? user = await TokenStorage.getUsername();
      setState(() {
        username = user;
      });
    } else {
      Log.d("No se pudo obtener el usuario actual.");
    }
  }

  Future<void> _obtenerDuoUsername() async {
    final String? user = await obtainUserConection();
    setState(() {
      duoName = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesión'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text(
                "Perfil",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline),

                ),
                title: Text(
                  username ?? "Usuario",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Usuario actual de Springfy"),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text(
                "Conexión",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const CircleAvatar(
                  child: Icon(Icons.favorite_border, color: Colors.redAccent),
                ),
                title: Text(
                  duoName ?? "Sin conexión",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Dúo vinculado"),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 300),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                 onPressed: () async {
                   if (mounted) {
                     Navigator.push(
                       context,
                       MaterialPageRoute(builder: (_) => const YourDataPage()),
                     );
                   }

                 }
                 ,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text(
                  'TUS DATOS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CupertinoColors.systemGrey,
                  foregroundColor: CupertinoColors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.only(left: 8.0, bottom: 8.0),),
            SizedBox(
              width: double.infinity,
              height: 54,

              child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
                onPressed: () async {
                  await TokenStorage.clear();
                  final directory = await getApplicationDocumentsDirectory();
                  final loginFile = File(p.join(directory.path, 'loginInfo.json'));

                  if (await loginFile.exists()) {
                    loginFile.deleteSync();
                  }
                  PlayerNotifier.instance.notify();
                  StreamFromSessionNotifier.instance.notify();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                    );
                  }
                },


                label: const Text(
                  'CERRAR SESIÓN',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.error,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}