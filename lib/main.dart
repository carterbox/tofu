import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart' as chart;
import 'package:flutter/material.dart';
import 'comed.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tofu',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Time OF Use'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

/// Return the pie char sections for the time of use
List<chart.PieChartSectionData> timeOfUse(
  EnergyRates rates,
  int resample,
  double width,
) {
  List<double> smoothedRates = getAverageRates(rates, resample);
  return smoothedRates.map(
    (x) {
      final r = x * width / 14.0;
      return chart.PieChartSectionData(
        value: 1,
        showTitle: true,
        title: x.toStringAsFixed(1),
        radius: r,
        titlePositionPercentageOffset: 0.5 / r * width,
      );
    },
  ).toList();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<EnergyRates> futureRates;

  @override
  void initState() {
    super.initState();
    futureRates = fetchRatesLast24Hours();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: FutureBuilder<EnergyRates>(
          future: futureRates,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return LayoutBuilder(builder: (context, constraints) {
                final radius = 0.5 *
                    min(
                      constraints.maxHeight,
                      constraints.maxWidth,
                    );
                return chart.PieChart(
                  chart.PieChartData(
                    sections: timeOfUse(
                      snapshot.data!,
                      60,
                      radius * 4 / 5,
                    ),
                    centerSpaceRadius: radius / 5,
                    startDegreeOffset: -90,
                  ),
                );
              });
            } else if (snapshot.hasError) {
              // TODO: Display a connection error message
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}
