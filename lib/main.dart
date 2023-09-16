// electricity_clock, an app for monitoring time-of-use electricity rates
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
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:electricity_clock/comed.dart';
import 'package:electricity_clock/solar.dart';
import 'package:electricity_clock/theme.dart';
import 'package:electricity_clock/green_button.dart';
import 'package:window_size/window_size.dart';

void main() {
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    setWindowMinSize(const Size(500, 500));
    setWindowMaxSize(const Size(1000, 800));
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      return MaterialApp(
        title: 'Electricity Clock',
        home: const HourlyEnergyRatesPage(),
        theme: TofuAppTheme.lightTheme(lightDynamic),
        darkTheme: TofuAppTheme.darkTheme(darkDynamic),
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
    });
  }
}

class NavigationDrawer extends StatelessWidget {
  final int selectedDestination;
  const NavigationDrawer(this.selectedDestination, {super.key});

  @override
  build(BuildContext context) {
    return Drawer(
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
            selected: selectedDestination == 0,
            onTap: () {
              Navigator.of(context).pop();
              if (selectedDestination == 0) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const HourlyEnergyRatesPage(),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historic Energy Usage'),
            selected: selectedDestination == 1,
            onTap: () {
              Navigator.of(context).pop();
              if (selectedDestination == 1) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const HistoricEnergyUsePage(),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.copyright),
            title: const Text('Licenses'),
            selected: selectedDestination == 2,
            onTap: () {
              Navigator.of(context).pop();
              showLicensePage(context: context);
            },
          ),
        ],
      ),
    );
  }
}

class HourlyEnergyRatesPage extends StatelessWidget {
  const HourlyEnergyRatesPage({super.key});

  final String title = 'Hourly Energy Rates';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final layoutIsWide = constraints.maxWidth > 600;
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        floatingActionButton:
            layoutIsWide ? null : const PriceClockExplainerButton(),
        drawer: const NavigationDrawer(0),
        body: Row(
          children: [
            if (layoutIsWide)
              const Expanded(
                flex: 13,
                child: PriceClockExplainer(),
              ),
            const Expanded(
              flex: 21,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  StreamingSolarCircle(),
                  StreamingPriceClock(),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

final energyUseProvider = StateNotifierProvider<HistoricEnergyUseClockNotifier,
    HistoricEnergyUseClockState>((ref) {
  return HistoricEnergyUseClockNotifier();
});

class HistoricEnergyUsePage extends ConsumerWidget {
  const HistoricEnergyUsePage({super.key});

  final String title = 'Historic Energy Use';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    HistoricEnergyUseClockState state = ref.watch(energyUseProvider);

    return LayoutBuilder(builder: (context, constraints) {
      final layoutIsWide = constraints.maxWidth > 600;

      Widget body = Row(children: [
        if (layoutIsWide)
          const Expanded(
            flex: 13,
            child: HistoricEnergyUseExplainer(),
          ),
        Expanded(
            flex: 21,
            child: Column(
              children: [
                Expanded(child: HistoricEnergyUseClock(state: state)),
                HistoricEnergyUseClockController(
                    stateProvider: energyUseProvider)
              ],
            )),
      ]);

      return Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        floatingActionButton:
            layoutIsWide ? null : const HistoricEnergyUseExplainerButton(),
        drawer: const NavigationDrawer(1),
        body: body,
      );
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
      dayColor: const Color(0xFFF7CD5D)
          .harmonizeWith(Theme.of(context).colorScheme.primary),
      nightColor: const Color(0xFF041A40)
          .harmonizeWith(Theme.of(context).colorScheme.primary),
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
