// tofu, an app for visualizing time-of-use electricity rates
// Copyright (C) 2022 Daniel Jackson Ching
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
      double r = x * width / 14.0;
      if (x == 0.0) {
        // Chart cannot render a zero height bar.
        r = 0.001;
      } else if (x < 0.0) {
        // Large negative bars look really bad.
        r = -1.0;
      }
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
  late Future<EnergyRates> pastRates;

  @override
  void initState() {
    super.initState();
    futureRates = fetchRatesNextDay();
    pastRates = fetchRatesLastDay();
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
                const bin_width = 60;
                return chart.PieChart(
                  chart.PieChartData(
                    sections: timeOfUse(
                      snapshot.data!,
                      bin_width,
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
