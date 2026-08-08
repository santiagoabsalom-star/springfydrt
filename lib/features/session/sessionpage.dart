import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:springfydrt/core/network/api_connect.dart';
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
        leading: IconButton(
          icon: const Icon(Icons.info, size: 30),
          onPressed: () async {
          await parameditDialog();
          }
          ),

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
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text(
                "Tiempo de uso",
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
                child: Icon(Icons.analytics_outlined),
              ),
              title: const Text(
                'Tiempo de uso',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Tiempo de uso de la aplicación"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const YourDataPage()),
                );})),

            const SizedBox(height: 220),
            SizedBox(
              width: double.infinity,
              height: 45,

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
  ValueNotifier<String?> selectedValue=ValueNotifier<String?>(ApiConnect.baseUrl);

  Future<void> parameditDialog() {
    final TextEditingController ipController = TextEditingController(text: ApiConnect.baseUrl);
    
    // Lista de IPs predefinidas para validar contra el dropdown
    const presets = [
      'http://springfy.tplinkdns.com:3051',
      'http://192.168.0.104:3050',
    ];

    return showDialog<String?>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Configuración de API",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Presets rápidos",
                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: selectedValue,
                  builder: (_, sValue, __) {
                    final dropdownValue = presets.contains(sValue) ? sValue : null;
                    
                    return DropdownButtonFormField<String>(
                      value: dropdownValue,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      hint: const Text("Selecciona un preset"),
                      items: const [
                        DropdownMenuItem(
                          value: 'http://springfy.tplinkdns.com:3051',
                          child: Text("Ip externa"),
                        ),
                        DropdownMenuItem(
                          value: 'http://192.168.0.104:3050',
                          child: Text("Ip Local"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          selectedValue.value = value;
                          ipController.text = value;
                          ApiConnect.baseUrl = value;
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  "IP Manual",
                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ipController,
                  decoration: InputDecoration(
                    hintText: "http://tu-ip:puerto",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.link),
                  ),
                  onChanged: (value) {
                    ApiConnect.baseUrl = value;
                    selectedValue.value = value;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("ACEPTAR"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}