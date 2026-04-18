
import 'dart:convert';
import 'dart:ffi';


import 'package:springfydrt/features/login/api/dto.dart';

import '../../../core/log.dart';
import '../../../core/network/api_connect.dart';
import '../../login/api/token.dart';

Future<UsoSemanalDTO> usoSemanalSegundoPlano() async{
  final response = await ApiConnect.instance.get('/api/usage/uso_semanal_segundo_plano');
  if (response.statusCode != 200) {
    throw Exception('Error al obtener uso semanal de la nube');
  }
  Log.d(response.body);
  return UsoSemanalDTO.fromJson(jsonDecode(response.body));


}
Future<UsoSemanalDTO> usoSemanalPrimerPlano() async{
  final response = await ApiConnect.instance.get('/api/usage/uso_semanal_primer_plano');
  if (response.statusCode != 200) {
    throw Exception('Error al obtener uso semanal de la nube');
  }
 Log.d(response.body);

  return UsoSemanalDTO.fromJson(jsonDecode(response.body));


}
Future<List<UsoDiarioDTO>> usoDiarioSegundoPlano() async{
  final response = await ApiConnect.instance.get('/api/usage/uso_diario_segundo_plano');
  if (response.statusCode != 200) {
    throw Exception('Error al obtener uso diario de la nube');
  }
  Log.d(response.body);
  return (jsonDecode(response.body) as List)
      .map((e) => UsoDiarioDTO.fromJson(e))
      .toList();




}
Future<ResponseBase> registrarUsoDiarioSegundoPlano(UsoDiarioDTO uso)async{
  final response= await ApiConnect.instance.postWithArgs('/api/usage/registrar_uso_diario_segundo_plano', true,{
    'usoDiario': uso.usoDiario,
    "uso": uso.fecha.toIso8601String()
  });
  return ResponseBase.fromJson(jsonDecode(response.body));

}
Future<ResponseBase> registrarUsoDiarioPrimerPlanoPlano(UsoDiarioDTO uso)async{
  final response= await ApiConnect.instance.postWithArgs('/api/usage/registrar_uso_diario_primer_plano', true,{
    'usoDiario': uso.usoDiario,
    "uso": uso.fecha.toIso8601String()
  });
  return ResponseBase.fromJson(jsonDecode(response.body));

}
Future<List<UsoDiarioDTO>> usoDiarioPrimerPlano() async {
  final response = await ApiConnect.instance.get(
      '/api/usage/uso_diario_primer_plano');
  if (response.statusCode != 200) {
    throw Exception('Error al obtener uso diario de la nube');
  }

  return (jsonDecode(response.body) as List)
      .map((e) => UsoDiarioDTO.fromJson(e))
      .toList();


}
  Future<ResponseBase> EmpezarContadorSegundoPlano()async{
    final nombre= await TokenStorage.getUsername();

  final response= await ApiConnect.instance.post('/api/usage/iniciar_segundo_plano/$nombre', true);
  return ResponseBase.fromJson(jsonDecode(response.body));

  }
  Future<ResponseBase> EmpezarContadorPrimerPlano()async{
    final nombre= await TokenStorage.getUsername();

    final response= await ApiConnect.instance.post('/api/usage/iniciar_primer_plano/$nombre',true);
    Log.d("Respuesta del servidor: ${response.body}");
    return ResponseBase.fromJson(jsonDecode(response.body));

  }
  Future<ResponseBase> TerminarContadorSegundoPlano()async{
    final nombre= await TokenStorage.getUsername();

  final response= await ApiConnect.instance.post('/api/usage/terminar_segundo_plano/$nombre', true);
  return ResponseBase.fromJson(jsonDecode(response.body));

  }
  Future<ResponseBase> TerminarContadorPrimerPlano()async{
    final nombre= await TokenStorage.getUsername();
    final response= await ApiConnect.instance.post('/api/usage/terminar_primer_plano/$nombre', true);
    final Map<String, dynamic> json = jsonDecode(response.body);
    return ResponseBase.fromJson(json);

  }

// Future<UsoSemanalDTO> usoSemanalBetween(DateTime startDate, DateTime endDate) async {

//}
// Future<UsoSemanalDTO> usoDiarioByDia(DateTime dia) async {

//}
// Future<UsoMensual> usoMensual() async {

//}
// Future<UsoMensual> usoMensualByMonth(DateTime month) async {

//}

class UsoSemanalDTO {
  final List<UsoDiarioDTO> usoSemanal;
  UsoSemanalDTO({
    required this.usoSemanal,
  });


  factory UsoSemanalDTO.fromJson(Map<String, dynamic> json) {
    return UsoSemanalDTO(
      usoSemanal : (json['usoDiario'] as List)
          .map((e) => UsoDiarioDTO.fromJson(e))
          .toList(),
    );
  }



}

class UsoDiarioDTO {
  int usoDiario;
  DateTime fecha;
  UsoDiarioDTO({
    required this.fecha,
    required this.usoDiario,
  });
  factory UsoDiarioDTO.fromJson(Map<String, dynamic> json) {
    return UsoDiarioDTO(
      usoDiario: json['usoDiario'] as int,
      fecha: parseJavaLocalDateTime(json['uso']),

    );
  }
  factory UsoDiarioDTO.fromJsonWithDateTime(Map<String, dynamic> json){
        UsoDiarioDTO uso= UsoDiarioDTO(fecha: DateTime.tryParse(json['uso']) ?? DateTime.now(),
    usoDiario: json['usoDiario'] as int? ?? 1);

    return uso;

  }



}
DateTime parseJavaLocalDateTime(List<dynamic> data) {
  return DateTime(
    data[0],
    data[1],
    data[2],
    data[3],
    data[4],
    data[5],
    data[6] ~/ 1000000,
  );
}

