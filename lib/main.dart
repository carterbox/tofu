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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:window_size/window_size.dart';

import 'theme.dart';
import 'widgets/forecast.dart';
import 'widgets/historic.dart';
import 'widgets/solar.dart';

void main() {
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    setWindowMinSize(const Size(500, 500));
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
            title: const Text('Forecasted Rates'),
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
            title: const Text('Historic Usage'),
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

  final String title = 'Forecasted Rates';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final colorScheme = Theme.of(context).colorScheme;
      final layoutIsWide = constraints.maxWidth > 600;
      Widget body = Stack(
        children: [
          Row(
            children: [
              if (layoutIsWide)
                Expanded(
                  flex: 13,
                  child: Container(),
                ),
              const Expanded(
                flex: 21,
                child: StreamingSolarCircle(),
              ),
            ],
          ),
          Row(
            children: [
              if (layoutIsWide)
                Expanded(
                  flex: 13,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 600,
                      child: Card(
                        color: colorScheme.primaryContainer,
                        child: const PriceClockExplainer(),
                      ),
                    ),
                  ),
                ),
              const Expanded(
                flex: 21,
                child: Stack(
                  children: [StreamingPriceClock()],
                ),
              ),
            ],
          )
        ],
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        floatingActionButton:
            layoutIsWide ? null : const PriceClockExplainerButton(),
        drawer: const NavigationDrawer(0),
        body: body,
      );
    });
  }
}

class HistoricEnergyUsePage extends StatelessWidget {
  const HistoricEnergyUsePage({super.key});

  final String title = 'Historic Use';

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(builder: (context, constraints) {
      final layoutIsWide = constraints.maxWidth > 600;
      final colorScheme = Theme.of(context).colorScheme;
      Widget body = Stack(
        children: [
          Row(
            children: [
              if (layoutIsWide)
                Expanded(
                  flex: 13,
                  child: Container(),
                ),
              Expanded(
                flex: 21,
                child: SolarCircle(
                  radius: 2.0,
                  dayColor: colorScheme.surface,
                  nightColor: colorScheme.surfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (layoutIsWide)
                Expanded(
                  flex: 13,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 600,
                      child: Card(
                        color: colorScheme.primaryContainer,
                        child: const HistoricEnergyUseExplainer(),
                      ),
                    ),
                  ),
                ),
              const Expanded(
                flex: 21,
                child: Stack(
                  children: [HistoricEnergyUseClock()],
                ),
              ),
            ],
          ),
        ],
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        floatingActionButton: layoutIsWide
            ? const HistoricEnergyUseClockControllerButton()
            : const Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  HistoricEnergyUseExplainerButton(),
                  SizedBox(
                    height: 8,
                  ),
                  HistoricEnergyUseClockControllerButton(),
                ],
              ),
        drawer: const NavigationDrawer(1),
        body: body,
      );
    });
  }
}
