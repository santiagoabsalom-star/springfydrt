import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:springfydrt/features/yourdata/api/usageApi.dart';

import '../../core/log.dart';

enum TipoVisualizacion { semanalPrimer, semanalSegundo, diarioPrimer, diarioSegundo }

class YourDataPage extends StatefulWidget {
  const YourDataPage({super.key});

  @override
  State<YourDataPage> createState() => _YourDataPageState();
}

class _YourDataPageState extends State<YourDataPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<UsoDiarioDTO> usoDiarioDTOPrimerPlano = [];
  List<UsoDiarioDTO> usoDiarioDTOSegundoPlano = [];
  UsoSemanalDTO usoSemanalDTOPrimerPlano = UsoSemanalDTO(usoSemanal: []);
   UsoSemanalDTO usoSemanalDTOSegundoPlano = UsoSemanalDTO(usoSemanal: []);
  TipoVisualizacion vistaSeleccionada = TipoVisualizacion.semanalPrimer;
  final StreamController<TipoVisualizacion> _vistaController = StreamController<TipoVisualizacion>.broadcast();

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }
  @override
  void dispose(){
    super.dispose();
    _vistaController.close();
  }
  void cargarDatos() async {
    final diarioPrimer = await usoDiarioPrimerPlano();
    final diarioSegundo = await usoDiarioSegundoPlano();
    final semanalPrimer = await usoSemanalPrimerPlano();
    final semanalSegundo = await usoSemanalSegundoPlano();

    setState(() {
      usoDiarioDTOPrimerPlano = diarioPrimer;
      usoDiarioDTOSegundoPlano = diarioSegundo;
      usoSemanalDTOPrimerPlano = semanalPrimer;
      usoSemanalDTOSegundoPlano = semanalSegundo;
    });
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiempo de uso'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<TipoVisualizacion>(
        stream: _vistaController.stream,
        initialData: vistaSeleccionada,
        builder: (context, snapshot) {
          final vista = snapshot.data!;

          Map<int, double> datosProcesados = {};
          bool esVistaSemanal = vista == TipoVisualizacion.semanalPrimer || vista == TipoVisualizacion.semanalSegundo;

          if (esVistaSemanal) {
            datosProcesados = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
            var lista = (vista == TipoVisualizacion.semanalPrimer) ? usoSemanalDTOPrimerPlano.usoSemanal : usoSemanalDTOSegundoPlano.usoSemanal;
            for (var item in lista) {
              int wd = item.fecha.weekday;
              datosProcesados[wd] = (datosProcesados[wd] ?? 0) + item.usoDiario.toDouble();
            }
          } else {
            datosProcesados = { for (var k in List.generate(24, (i) => i)) k : 0.0 };
            var lista = (vista == TipoVisualizacion.diarioPrimer) ? usoDiarioDTOPrimerPlano : usoDiarioDTOSegundoPlano;
            for (var item in lista) {
              int hora = item.fecha.hour;
              datosProcesados[hora] = (datosProcesados[hora] ?? 0) + item.usoDiario.toDouble();
            }
          }

          double maxSegundos = datosProcesados.values.isEmpty ? 0 : datosProcesados.values.reduce((a, b) => a > b ? a : b);

          bool usarMinutosEnEje = maxSegundos < 3600 && maxSegundos > 0;

          datosProcesados.updateAll((key, value) => usarMinutosEnEje ? value / 60 : value / 3600);

          double maxValorConvertido = usarMinutosEnEje ? maxSegundos / 60 : maxSegundos / 3600;
          double escalaY = esVistaSemanal && !usarMinutosEnEje ? 24 : (maxValorConvertido > 0 ? maxValorConvertido * 1.2 : 10);

          return SingleChildScrollView(child:Column(
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: SegmentedButton<TipoVisualizacion>(
                  segments: const [
                    ButtonSegment(value: TipoVisualizacion.semanalPrimer, label: Text('Sem. 1P'), icon: Icon(Icons.view_week)),
                    ButtonSegment(value: TipoVisualizacion.semanalSegundo, label: Text('Sem. 2P'), icon: Icon(Icons.history)),
                    ButtonSegment(value: TipoVisualizacion.diarioPrimer, label: Text('Día 1P'), icon: Icon(Icons.today)),
                    ButtonSegment(value: TipoVisualizacion.diarioSegundo, label: Text('Día 2P'), icon: Icon(Icons.timer)),
                  ],
                  selected: {vista},
                  onSelectionChanged: (newSelection) {
                    vistaSeleccionada = newSelection.first;
                    _vistaController.add(newSelection.first);
                  },
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: Colors.blueAccent,
                    selectedForegroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(height: 100),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: esVistaSemanal 
                  ? BarChart(
                    BarChartData(
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.blueGrey,
                          tooltipBorderRadius: BorderRadius.circular(4),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final double val = rod.toY;
                            String texto = val < 1 ? "${(val * 60).toStringAsFixed(1)} min" : "${val.toStringAsFixed(1)} h";
                            return BarTooltipItem(texto, const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                          },
                        ),
                      ),
                      maxY: escalaY,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              String unit = usarMinutosEnEje ? 'm' : 'h';
                              return Text('${value.toInt()}$unit',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey));
                            }),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                                const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                                int index = value.toInt();
                                if (index >= 0 && index < 7) {
                                  return Text(dias[index], style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10));
                                }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(7, (index) {

                        final double valorY = datosProcesados[index + 1] ?? 0;

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: valorY,
                              color: Colors.blueAccent,
                              width: 22,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: escalaY,
                                color:  Color.fromRGBO(255, 255, 255, 0.2),
                              ),
                            )
                          ],
                        );
                      }),
                    ),
                  )
                  : LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) => Colors.blueGrey,
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((spot) {
                              final double val = spot.y;
                              String texto = usarMinutosEnEje
                                  ? "${val.toStringAsFixed(1)} min"
                                  : (val < 1 ? "${(val * 60).toStringAsFixed(1)} min" : "${val.toStringAsFixed(1)} h");
                              return LineTooltipItem(texto, const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                            }).toList();
                          },
                        ),
                      ),
                      maxY: escalaY,
                      gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              String unit = usarMinutosEnEje ? 'm' : 'h';
                              return Text('${value.toInt()}$unit',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey));
                            }),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value % 4 == 0) {
                                return Text('${value.toInt()}h', style: const TextStyle(color: Colors.grey, fontSize: 10));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(24, (index) {
                            return FlSpot(index.toDouble(), datosProcesados[index] ?? 0);
                          }),
                          isCurved: true,
                          color: Colors.blueAccent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blueAccent.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0,vertical: 10.0),
                child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
          ),
          child: Row(
          children: [
          const Icon(Icons.access_time_filled, color: Colors.blueAccent, size: 30),
          const SizedBox(width: 15),
          Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
          esVistaSemanal ? "Uso Total de la Semana" : "Uso Total del Día",
          style: const TextStyle(
          fontSize: 14,
          color: Colors.black54,
          fontWeight: FontWeight.w500,
          ),
          ),
          Text(usarMinutosEnEje ?_formatearTiempoTotal(datosProcesados.values.reduce((a, b) => a + b) / 60) :
          _formatearTiempoTotal(datosProcesados.values.reduce((a, b) => a + b)),
          style: const TextStyle(
          fontSize: 22,
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
          ),
          ),
          ],
          ),
          ],
              )))
            ],
          ));
        },
      ),
    );
  }}
String _formatearTiempoTotal(double horasTotales) {
  Log.d("$horasTotales");
  if (horasTotales <= 0) return "Sin actividad :(";

  int horas = horasTotales.toInt();
  int minutos = ((horasTotales - horas) * 60).round();

  if (horas > 0) {
    return "$horas h $minutos min";
  } else {
    return "$minutos min";
  }
}
