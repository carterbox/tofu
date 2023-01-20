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

import 'dart:io';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:tofu/comed.dart';
import 'package:tofu/solar.dart';
import 'package:tofu/theme.dart';
import 'package:window_size/window_size.dart';

void main() {
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowMinSize(const Size(500, 500));
    setWindowMaxSize(Size.infinite);
  }
  runApp(const ProviderScope(child: MyApp()));
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
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
  int _selectedDestination = 0;

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
          return Row(
            children: [
              if (constraints.maxWidth > 600)
                const Expanded(
                  flex: 13,
                  child: Placeholder(),
                ),
              Expanded(
                flex: 21,
                child: Stack(
                  alignment: Alignment.center,
                  children: const [
                    StreamingSolarCircle(),
                    StreamingPriceClock(),
                  ],
                ),
              ),
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

final streamOfDayInfo = StreamProvider<DayInfo>((ref) async* {
  await for (final day in streamSunriseSunset()) {
    yield day;
  }
});

class StreamingSolarCircle extends ConsumerWidget {
  const StreamingSolarCircle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayInfo = ref.watch(streamOfDayInfo).when(
          error: (error, stackTrace) => const DayInfo(length: 12, sunrise: 6),
          loading: () => const DayInfo(length: 12, sunrise: 6),
          data: (data) => data,
        );
    return SolarCircle(
      radius: 0.255,
      today: dayInfo,
      dayColor:
          Colors.amber.harmonizeWith(Theme.of(context).colorScheme.primary),
      nightColor:
          Colors.indigo.harmonizeWith(Theme.of(context).colorScheme.primary),
    );
  }
}

final streamOfEnergyRates = StreamProvider<EnergyRatesUpdate>((ref) async* {
  await for (final rate in streamRatesNextDay()) {
    yield rate;
  }
});

class StreamingPriceClock extends ConsumerWidget {
  const StreamingPriceClock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(streamOfEnergyRates).when(
          error: (error, stackTrace) => const PriceClockLoading(),
          loading: () => const PriceClockLoading(),
          data: (data) => PriceClock(
            energyRates: data.forecast,
            currentHourRate: data.currentHour,
          ),
        );
  }
}
