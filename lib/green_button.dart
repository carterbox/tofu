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

/// Load and display electricity usage data from a greenbutton download.
///
/// Note that in accordance to the COMED API, all prices are label with period
/// ending. i.e. If you ask for the 5 minute price at 10:00 pm, then the price
/// is for the period from 9:55 pm to 10:00 pm. If you ask for the hourly price
/// at 1:00 pm, the price is the average from 12:00 pm to 1:00 pm.

import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart' as chart;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart' as logging;
import 'comed.dart';

import 'package:flutter/services.dart' show rootBundle;

final _logger = logging.Logger('electricity_clock.green_button');

Future<String> loadPlaceholderGreenbutton() async {
  return await rootBundle.loadString('assets/data/greenbutton-placeholder.csv');
}

/// A collection of hourly energy use over time.
@immutable
class HourlyEnergyUse {
  final String units = 'kWh';

  final double rateHighThreshold = 1.0;

  /// How much energy was used in [units]
  final Map<DateTime, double> usage;

  const HourlyEnergyUse({
    required this.usage,
  });

  @override
  String toString() {
    return usage.entries
        .map((e) => '${e.value.toStringAsFixed(3)}$units hour-ending ${e.key}')
        .join('\n');
  }

  /// Return the day ending before and last containing the usage
  List<DateTime> getDateRange() {
    List<DateTime> dates = usage.keys.toList(growable: false);
    DateTime lo = dates[0];
    DateTime hi = dates[0];
    for (final date in dates) {
      if (date.isBefore(lo)) {
        lo = date;
      }
      if (date.isAfter(hi)) {
        hi = date;
      }
    }
    return [
      DateTime(lo.year, lo.month, lo.day).subtract(const Duration(days: 1)),
      DateTime(hi.year, hi.month, hi.day),
    ];
  }

  factory HourlyEnergyUse.placeholder() {
    Map<DateTime, double> usage = {
      DateTime(2023, 1, 1, 01): 0.15,
      DateTime(2023, 1, 1, 02): 0.2,
      DateTime(2023, 1, 1, 03): 0.1,
      DateTime(2023, 1, 1, 04): 0.3,
      DateTime(2023, 1, 1, 05): 0.15,
      DateTime(2023, 1, 1, 06): 0.4,
      DateTime(2023, 1, 1, 07): 0.3,
      DateTime(2023, 1, 1, 08): 0.2,
      DateTime(2023, 1, 1, 09): 0.15,
      DateTime(2023, 1, 1, 10): 0.5,
      DateTime(2023, 1, 1, 11): 0.2,
      DateTime(2023, 1, 1, 12): 0.15,
    };
    return HourlyEnergyUse(usage: usage);
  }

  /// Construct a [HourlyEnergyUse] from a ComEd Green Button comma-separated
  /// file
  ///
  /// This CSV file has a header followed by column labels and then data. The
  /// headers and example first row are as follows:
  ///
  /// TYPE,DATE,START TIME,END TIME,USAGE,UNITS,COST,NOTES
  /// Electric usage,2022-12-01,00:00,00:29,0.16,kWh,$0.02,
  ///
  /// https://www.energy.gov/data/green-button
  factory HourlyEnergyUse.fromComEdCsvFile(File file) {
    Map<DateTime, double> usage = {};

    for (final line in file.readAsLinesSync()) {
      final tokens = line.split(',');

      if (tokens[0] == 'Electric usage') {
        final date = tokens[1].split('-');
        final int year = int.parse(date[0]);
        final int month = int.parse(date[1]);
        final int day = int.parse(date[2]);

        final time = tokens[3].split(':');
        final end = convertToHourEnd(
            DateTime(year, month, day, int.parse(time[0]), int.parse(time[1])));

        usage[end] = (usage[end] ?? 0) + double.parse(tokens[4]);
      }
    }

    return HourlyEnergyUse(usage: usage);
  }

  /// Construct a [HourlyEnergyUse] from a ComEd Green Button comma-separated
  /// file
  ///
  /// This CSV file has a header followed by column labels and then data. The
  /// headers and example first row are as follows:
  ///
  /// TYPE,DATE,START TIME,END TIME,USAGE,UNITS,COST,NOTES
  /// Electric usage,2022-12-01,00:00,00:29,0.16,kWh,$0.02,
  ///
  /// https://www.energy.gov/data/green-button
  factory HourlyEnergyUse.fromComEdCsvString(String file) {
    Map<DateTime, double> usage = {};
    const splitter = LineSplitter();

    for (final line in splitter.convert(file)) {
      final tokens = line.split(',');

      if (tokens[0] == 'Electric usage') {
        final date = tokens[1].split('-');
        final int year = int.parse(date[0]);
        final int month = int.parse(date[1]);
        final int day = int.parse(date[2]);

        final time = tokens[3].split(':');
        final end = convertToHourEnd(
            DateTime(year, month, day, int.parse(time[0]), int.parse(time[1])));

        usage[end] = (usage[end] ?? 0) + double.parse(tokens[4]);
      }
    }

    return HourlyEnergyUse(usage: usage);
  }

  /// Return 24 averaged hour-ending readings
  List<double> hourlyAverages() {
    if (usage.isEmpty) {
      return List<double>.filled(24, double.nan, growable: false);
    }

    var totals = List<double>.filled(24, 0.0, growable: false);
    var counts = List<double>.filled(24, 0.0, growable: false);
    for (final reading in usage.entries) {
      final hour = reading.key.hour;
      totals[hour] += reading.value;
      counts[hour] += 1;
    }

    return [for (var i = 0; i < totals.length; ++i) totals[i] / counts[i]];
  }

  HourlyEnergyUse filterByWeekday(Set<int> weekdays) {
    final filteredUsage = Map.of(usage);
    filteredUsage.removeWhere((key, value) => !weekdays.contains(key.weekday));
    return HourlyEnergyUse(
      usage: filteredUsage,
    );
  }

  HourlyEnergyUse filterByMonth(List<int> months) {
    final filteredUsage = Map.of(usage);
    filteredUsage.removeWhere((key, value) => !months.contains(key.month));
    return HourlyEnergyUse(
      usage: filteredUsage,
    );
  }

  HourlyEnergyUse filterByDate(DateTime start, DateTime end) {
    final filteredUsage = Map.of(usage);
    filteredUsage.removeWhere(
        (key, value) => key.compareTo(start) <= 0 || key.compareTo(end) > 0);
    return HourlyEnergyUse(
      usage: filteredUsage,
    );
  }
}

/// Provides min, median, and max rates in that order
List<double> getHighlights(List<double> values) {
  var ratesSorted = values.toList();
  ratesSorted.removeWhere((element) => !(element.isFinite));
  if (ratesSorted.isEmpty) {
    return [];
  }
  ratesSorted.sort();
  return [
    ratesSorted[0],
    ratesSorted[ratesSorted.length ~/ 2],
    ratesSorted[ratesSorted.length - 1],
  ];
}

double _computeAverageRate(
  Map<DateTime, double> usage,
  Map<DateTime, double> rates,
) {
  if (rates.isNotEmpty && usage.isNotEmpty) {
    double totalUsage = 0.0;
    double totalCost = 0.0;
    for (final hour in usage.entries) {
      if (rates.containsKey(hour.key)) {
        totalUsage += hour.value;
        totalCost += hour.value * rates[hour.key]!;
      } else {
        _logger.warning(
            'No matching rate found for usage during hour ending ${hour.key}');
      }
    }
    if (totalUsage != 0.0) {
      return totalCost / totalUsage;
    }
  }
  return double.nan;
}

@immutable
class HistoricEnergyUseClockState {
  final HourlyEnergyUse historicEnergyUse;
  final HourlyEnergyUse filteredHistoricEnergyUse;
  final CentPerEnergyRates historicEnergyRates;
  final CentPerEnergyRates filteredHistoricEnergyRates;
  final Set<int> weekdays;
  final double averageRate;

  const HistoricEnergyUseClockState({
    required this.historicEnergyUse,
    required this.filteredHistoricEnergyUse,
    required this.historicEnergyRates,
    required this.filteredHistoricEnergyRates,
    required this.weekdays,
    this.averageRate = double.nan,
  });

  factory HistoricEnergyUseClockState.fromUnfiltered({
    required HourlyEnergyUse historicEnergyUse,
    required CentPerEnergyRates historicEnergyRates,
  }) {
    return HistoricEnergyUseClockState(
        historicEnergyUse: historicEnergyUse,
        filteredHistoricEnergyUse: historicEnergyUse,
        historicEnergyRates: historicEnergyRates,
        filteredHistoricEnergyRates: historicEnergyRates,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        averageRate: _computeAverageRate(
          historicEnergyUse.usage,
          historicEnergyRates.rates,
        ));
  }

  HistoricEnergyUseClockState filterByWeekday(Set<int> weekdays) {
    final filteredUsage = historicEnergyUse.filterByWeekday(weekdays);
    final filteredRates = historicEnergyRates.filterByWeekday(weekdays);
    return HistoricEnergyUseClockState(
      historicEnergyUse: historicEnergyUse,
      filteredHistoricEnergyUse: filteredUsage,
      historicEnergyRates: historicEnergyRates,
      filteredHistoricEnergyRates: filteredRates,
      weekdays: weekdays,
      averageRate: _computeAverageRate(
        filteredUsage.usage,
        filteredRates.rates,
      ),
    );
  }
}

chart.PieChartSectionData createSection(
    {required double value,
    required String units,
    required Color color,
    required List<double> isImportant,
    required double outerRadius,
    required double barHeightMaximum}) {
  double barHeight = value;
  if (value < 0.0) {
    // Large negative bars look really bad.
    barHeight = -1.0;
  }
  if (value == 0.0 || !value.isFinite) {
    barHeight = 0.0;
  }
  return chart.PieChartSectionData(
    value: 1,
    showTitle: value.isFinite && isImportant.contains(value),
    title: '${value.toStringAsFixed(1)} $units',
    radius: outerRadius * barHeight / barHeightMaximum,
    titlePositionPercentageOffset: 1 + 0.1 * barHeightMaximum / barHeight,
    color: color,
  );
}

class Legend extends StatelessWidget {
  final List<String> labels;
  final List<Color> colors;

  const Legend({
    super.key,
    required this.labels,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    var chips = <Chip>[];
    for (var i = 0; i < labels.length; ++i) {
      chips.add(Chip(
        avatar: CircleAvatar(
          backgroundColor: colors[i],
        ),
        label: Text(labels[i]),
        backgroundColor: Colors.transparent,
      ));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: chips,
    );
  }
}

class HistoricEnergyUseClock extends StatelessWidget {
  final double radius;
  final HistoricEnergyUseClockState state;

  const HistoricEnergyUseClock({
    super.key,
    required this.state,
    this.radius = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Legend(
          labels: const [
            'Energy Use',
            'Energy Rates',
          ],
          colors: [
            theme.colorScheme.secondary,
            theme.colorScheme.primary,
          ],
        ),
        LayoutBuilder(builder: (context, constraints) {
          final double diameter =
              0.5 * min(constraints.maxHeight, constraints.maxWidth);

          final innerRadius = diameter * radius * 0.25;
          final outerRadius = diameter * radius * 0.75;

          final theme = Theme.of(context);
          final double barHeightMaximumUsage =
              (state.filteredHistoricEnergyUse.rateHighThreshold * 1.1);
          final double barHeightMaximumRates =
              (state.filteredHistoricEnergyRates.rateHighThreshold * 1.1);
          var sections = List<chart.PieChartSectionData>.empty(growable: true);
          final usage = state.filteredHistoricEnergyUse.hourlyAverages();
          final rates = state.filteredHistoricEnergyRates.hourlyAverages();
          final isImportantUsage = getHighlights(usage);
          final isImportantRates = getHighlights(rates);
          for (int hour = 0; hour < 24; hour++) {
            sections.add(createSection(
              value: usage[hour],
              units: state.historicEnergyUse.units,
              color: theme.colorScheme.secondary,
              isImportant: isImportantUsage,
              outerRadius: outerRadius,
              barHeightMaximum: barHeightMaximumUsage,
            ));
            sections.add(createSection(
              value: rates[hour],
              units: state.historicEnergyRates.units,
              color: theme.colorScheme.primary,
              isImportant: isImportantRates,
              outerRadius: outerRadius,
              barHeightMaximum: barHeightMaximumRates,
            ));
          }
          return chart.PieChart(
            chart.PieChartData(
              sections: sections,
              centerSpaceRadius: innerRadius,
              startDegreeOffset: (360 / 24) * 5,
            ),
          );
        }),
      ],
    );
  }
}

class HistoricEnergyUseClockNotifier
    extends StateNotifier<HistoricEnergyUseClockState> {
  HistoricEnergyUseClockNotifier()
      : super(const HistoricEnergyUseClockState(
          historicEnergyUse: HourlyEnergyUse(usage: {}),
          filteredHistoricEnergyUse: HourlyEnergyUse(usage: {}),
          historicEnergyRates: CentPerEnergyRates(rates: {}),
          filteredHistoricEnergyRates: CentPerEnergyRates(rates: {}),
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ));

  void changeEnergyUse(HourlyEnergyUse newUse, CentPerEnergyRates newRates) {
    state = HistoricEnergyUseClockState.fromUnfiltered(
      historicEnergyUse: newUse,
      historicEnergyRates: newRates,
    ).filterByWeekday(state.weekdays);
  }

  void changeFilter(Set<int> newWeekdays) {
    state = state.filterByWeekday(
      newWeekdays,
    );
  }
}

class HistoricEnergyUseClockController extends ConsumerWidget {
  final StateNotifierProvider<HistoricEnergyUseClockNotifier,
      HistoricEnergyUseClockState> stateProvider;

  static const Map<String, int> dayNames = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  const HistoricEnergyUseClockController({
    super.key,
    required this.stateProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    HistoricEnergyUseClockState state = ref.watch(stateProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;

    String averagePriceMessage = '';
    if (state.averageRate.isFinite) {
      averagePriceMessage =
          'The average price for electricity only is ${state.averageRate.toStringAsFixed(3)} ${state.filteredHistoricEnergyRates.units}. Other fees and charges may apply.';
    } else {
      averagePriceMessage = 'The average electricity price is unknown.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 5.0),
          ElevatedButton(
            child: const Text('Load your usage data'),
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform
                  .pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
              // The result will be null, if the user aborted the dialog
              if (result != null) {
                File file = File(result.files.first.path!);
                final newUsage = HourlyEnergyUse.fromComEdCsvFile(file);
                final dateRange = newUsage.getDateRange();
                final newRates = await fetchHistoricHourlyRatesDayRange(
                  dateRange[0],
                  dateRange[1],
                );
                // TODO: Add a loading state here while awaiting results?
                ref.read(stateProvider.notifier).changeEnergyUse(
                      newUsage,
                      newRates,
                    );
              }
            },
          ),
          const SizedBox(height: 30.0),
          Text('Filter by weekday', style: textTheme.titleLarge),
          const SizedBox(height: 10.0),
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 5.0,
            runSpacing: 5.0,
            children: dayNames.entries.map((entry) {
              return FilterChip(
                label: Text(entry.key),
                selected: state.weekdays.contains(entry.value),
                onSelected: (bool selected) {
                  Set<int> newWeekdays = Set.from(state.weekdays);
                  if (selected) {
                    newWeekdays.add(entry.value);
                  } else {
                    newWeekdays.remove(entry.value);
                  }
                  ref.read(stateProvider.notifier).changeFilter(newWeekdays);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10.0),
          Text(
            averagePriceMessage,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 10.0),
        ],
      ),
    );
  }
}

class HistoricEnergyUseExplainer extends StatelessWidget {
  const HistoricEnergyUseExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).dialogBackgroundColor,
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'What is your historic energy use?',
              textAlign: TextAlign.left,
              textScaleFactor: 2,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'This chart shows the average hourly energy use from your Green Button Download.',
              textAlign: TextAlign.left,
              textScaleFactor: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A button which toggles a model bottom sheet containing HistoricEnergyUseExplainer
class HistoricEnergyUseExplainerButton extends StatelessWidget {
  const HistoricEnergyUseExplainerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      child: const Icon(Icons.question_mark),
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (BuildContext context) {
            return const HistoricEnergyUseExplainer();
          },
        );
      },
    );
  }
}
