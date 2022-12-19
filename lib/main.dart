// tofu, an app for monitoring time-of-use electricity rates
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
import 'package:flutter/material.dart';
import 'package:tofu/theme.dart';
import 'package:tofu/solar.dart';
import 'package:tofu/comed.dart';
import 'package:logging/logging.dart';
import 'package:dynamic_color/dynamic_color.dart';

final _logger = Logger('tofu.main');
void main() {
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOfU',
      home: const MyHomePage(title: 'Time OF Use'),
      theme: ThemeData.from(
        colorScheme: lightColorScheme,
      ),
      darkTheme: ThemeData.from(
        colorScheme: darkColorScheme,
      ),
      themeMode: ThemeMode.system,
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
  late Stream<EnergyRates> streamOfEnergyRates;
  late Stream<DayInfo> streamOfDayInfo;
  int _selectedDestination = 0;

  @override
  void initState() {
    super.initState();
    streamOfEnergyRates = streamRatesNextDay();
    streamOfDayInfo = streamSunriseSunset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Navigation Menu',
              ),
            ),
            const Divider(
              height: 1,
              thickness: 1,
            ),
            ListTile(
              leading: const Icon(Icons.price_change),
              title: const Text('Hourly Energy Rates'),
              selected: _selectedDestination == 0,
              onTap: () {
                selectDestination(0);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copyright),
              title: const Text('Open Source Licenses'),
              selected: _selectedDestination == 1,
              onTap: () {
                Navigator.of(context).pop();
                showLicensePage(context: context);
              },
            ),
          ],
        ),
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
              StreamBuilder(
                  stream: streamOfDayInfo,
                  builder: (context, snapshot) {
                    late final DayInfo today;
                    if (snapshot.hasData) {
                      today = snapshot.data!;
                    } else {
                      today = const DayInfo(length: 12, sunrise: 6);
                    }
                    return SolarCircle(
                      radius: radius * 1 / 5,
                      today: today,
                      dayColor: Colors.amber
                          .harmonizeWith(Theme.of(context).colorScheme.primary),
                      nightColor: Colors.indigo
                          .harmonizeWith(Theme.of(context).colorScheme.primary),
                    );
                  }),
              StreamBuilder<EnergyRates>(
                  stream: streamOfEnergyRates,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return PriceClock(
                        rates: snapshot.data!,
                        radius: radius * 4 / 5,
                      );
                    }
                    return SizedBox(
                      width: radius / 2,
                      height: radius / 2,
                      child: CircularProgressIndicator(
                        strokeWidth: radius / 50,
                      ),
                    );
                  }),
            ],
          );
        }),
      ),
    );
  }

  void selectDestination(int index) {
    setState(() {
      _selectedDestination = index;
    });
  }
}
