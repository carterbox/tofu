import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart' as chart;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

Future<EnergyRates> fetchRatesLast24Hours() async {
  final response = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=5minutefeed&format=json'));

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return EnergyRates.fromJson(jsonDecode(response.body));
    // return const EnergyRates(
    //     period: 5, units: 'cents', rates: [1.0, 2.2, 3.3, 4.0]);
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load rates from last 24 hours.');
  }
}

class EnergyRates {
  // period in minutes
  final int period;
  // The unit of measure per kwh
  final String units;
  final List<double> rates;

  const EnergyRates({
    required this.period,
    required this.units,
    required this.rates,
  });

  factory EnergyRates.fromJson(List<dynamic> json) {
    return EnergyRates(
      period: 5,
      units: '\u{00A2}',
      rates: json.map((x) => double.parse(x['price'])).toList(),
    );
  }
}

/// Return the pie char sections for the time of use
List<chart.PieChartSectionData> timeOfUse(List<double> rates, int resample) {
  List<double> smoothedRates = List<double>.filled(288 ~/ resample, 0.0);
  for (int i = 0; i < rates.length; i++) {
    smoothedRates[i ~/ resample] += rates[i] / resample;
  }

  return smoothedRates
      .map(
        (x) => chart.PieChartSectionData(
          value: 1,
          showTitle: true,
          title: x.toStringAsFixed(1),
          radius: x * 10,
        ),
      )
      .toList();
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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: FutureBuilder<EnergyRates>(
            future: futureRates,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return chart.PieChart(
                  chart.PieChartData(
                    sections: timeOfUse(snapshot.data!.rates, 6),
                    centerSpaceRadius: double.infinity,
                    startDegreeOffset: -90,
                  ),
                );
              } else if (snapshot.hasError) {
                // TODO: Display a connection error message
              }
              return const CircularProgressIndicator();
            },
          ),
        ),
      ),
    );
  }
}
