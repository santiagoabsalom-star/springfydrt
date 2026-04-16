
import 'dart:convert';


import 'package:springfydrt/features/login/api/dto.dart';

import '../../../core/log.dart';
import '../../../core/network/api_connect.dart';
import '../../login/api/token.dart';

Future<UsoSemanalDTO> usoSemanalSegundoPlano() async{
  final response = await ApiConnect.instance.get('/api/usage/uso_semanal_segundo_plano');
  if (response.statusCode != 200) {
    throw Exception('Error al obtener uso semanal de la nube');
  }

  return UsoSemanalDTO.fromJson(jsonDecode(response.body));


}
Future<UsoSemanalDTO> usoSemanalPrimerPlano() async{
  final response = await ApiConnect.instance.get('/api/usage/uso_semanal_primer_plano');
  if (response.statusCode != 200) {
    throw Exception('Error al obtener uso semanal de la nube');
  }

  return UsoSemanalDTO.fromJson(jsonDecode(response.body));


}
Future<UsoDiarioDTO> usoDiarioSegundoPlano() async{
  final response = await ApiConnect.instance.get('/api/usage/uso_diario_segundo_plano');
  if (response.statusCode != 200) {
    throw Exception('Error al obtener uso diario de la nube');
  }
  return UsoDiarioDTO.fromJson(jsonDecode(response.body));




}
Future<UsoDiarioDTO> usoDiarioPrimerPlano() async {
  final response = await ApiConnect.instance.get(
      '/api/usage/uso_diario_primer_plano');
  if (response.statusCode != 200) {
    throw Exception('Error al obtener uso diario de la nube');
  }
  return UsoDiarioDTO.fromJson(jsonDecode(response.body));
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
  int? usoSemanal;
  UsoSemanalDTO({
    this.usoSemanal,
  });
  factory UsoSemanalDTO.fromJson(Map<String, dynamic> json) {
    return UsoSemanalDTO(

      usoSemanal: json['usoSemanal'],
    );
  }



}
class UsoDiarioDTO {
  int? usoDiario;
  UsoDiarioDTO({
    this.usoDiario,
  });
  factory UsoDiarioDTO.fromJson(Map<String, dynamic> json) {
    return UsoDiarioDTO(

      usoDiario: json['usoSemanal'],
    );
  }



}

