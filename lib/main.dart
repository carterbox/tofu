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
import 'package:tofu/solar.dart';
import 'package:tofu/comed.dart';

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

class _MyHomePageState extends State<MyHomePage> {
  late Future<EnergyRates> futureRates;

  @override
  void initState() {
    super.initState();
    futureRates = fetchRatesNextDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: LayoutBuilder(builder: (context, constraints) {
          final radius = 0.7 *
              min(
                constraints.maxHeight,
                constraints.maxWidth,
              );
          return Stack(
            alignment: Alignment.center,
            children: [
              getSolarCircle(radius * 1 / 5),
              FutureBuilder<EnergyRates>(
                future: futureRates,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return getPriceClock(snapshot.data!, radius * 4 / 5);
                  }
                  if (snapshot.hasError) {
                    // TODO: Display a connection error message
                  }
                  return SizedBox(
                    width: radius / 10,
                    height: radius / 10,
                    child: CircularProgressIndicator(
                      strokeWidth: radius / 50,
                    ),
                  );
                },
              ),
            ],
          );
        }),
      ),
    );
  }
}
