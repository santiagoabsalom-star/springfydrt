import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:springfydrt/features/yourdata/api/usageApi.dart';

import '../../../core/log.dart';

class UsageLocalStorage {
  static const String _key = 'pending_usage_data';


  static Future<void> saveUsageLocal(int segundos, bool esPrimerPlano) async {

    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList(_key) ?? [];

    Map<String, dynamic> data = {
      'usoDiario': segundos,
      'uso': DateTime.now().toIso8601String(),
      'esPrimerPlano': esPrimerPlano,
    };

    String encoded = jsonEncode(data);
    if (encoded.isNotEmpty) {
      pending.add(encoded);
      await prefs.setStringList(_key, pending);
      Log.d("Guardado local: $data");
    }
    await prefs.setStringList(_key, pending);
  }
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Log.d("Todos los datos de SharedPreferences han sido borrados.");
  }
  static Future<void> syncPendingUsage() async {

    final prefs = await SharedPreferences.getInstance();
    List<String> pending = (prefs.getStringList(_key) ?? [])
        .where((item) => item.trim().isNotEmpty)
        .toList();

    if (pending.isEmpty) return;

    Log.d("Sincronizando ${pending.length} registros locales...");

    for (String item in List.from(pending)) {
      Map<String, dynamic> data = jsonDecode(item);

      bool esPrimerPlano = data['esPrimerPlano'] ?? false;
      try {
      Map<String, dynamic> dtoData = Map.from(data);
      dtoData.remove('esPrimerPlano');

      UsoDiarioDTO usuariodto = UsoDiarioDTO.fromJsonWithDateTime(dtoData);

        if (esPrimerPlano) {
          await registrarUsoDiarioPrimerPlanoPlano(usuariodto);
        } else {
          await registrarUsoDiarioSegundoPlano(usuariodto);
        }

        if(pending.remove(item)){
        Log.d("Sincronizacion de registros locales exitosa");
        }
        else{
          Log.d("Error al sincronizar registros locales");
        }
      } catch (e) {
        Log.d("Error enviando registro local, se reintentará luego: $e");
        break;
      }
    }

    await prefs.setStringList(_key, pending);
  }
}