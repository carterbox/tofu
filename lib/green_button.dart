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

import 'package:fl_chart/fl_chart.dart' as chart;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'comed.dart';

import 'package:flutter/services.dart' show rootBundle;

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
    var totals = List<double>.filled(24, 0.0, growable: false);
    var counts = List<double>.filled(24, 0.0, growable: false);

    for (final reading in usage.entries) {
      final hour = reading.key.hour;
      totals[hour] += reading.value;
      counts[hour] += 1;
    }

    return [for (var i = 0; i < totals.length; ++i) totals[i] / counts[i]];
  }

  HourlyEnergyUse filterByWeekday(List<int> weekdays) {
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
  ratesSorted.sort();
  return [
    ratesSorted[0],
    ratesSorted[ratesSorted.length ~/ 2],
    ratesSorted[ratesSorted.length - 1],
  ];
}

enum Weekdays{Noneday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday}

class HistoricEnergyUseClock extends StatefulWidget {
  final double radius;

  const HistoricEnergyUseClock({
    super.key,
    this.radius = 1.0,
  });

  @override
  HistoricEnergyUseClockState createState() => HistoricEnergyUseClockState();
}

class HistoricEnergyUseClockState extends State<HistoricEnergyUseClock> {
  HourlyEnergyUse? historicEnergyUse;

  @override
  Widget build(BuildContext context) {
    if (historicEnergyUse != null) {
      return LayoutBuilder(builder: (context, constraints) {
        final double diameter =
            0.5 * min(constraints.maxHeight, constraints.maxWidth);

        final innerRadius = diameter * widget.radius * 0.25;
        final outerRadius = diameter * widget.radius * 0.75;

        final theme = Theme.of(context);
        final double barHeightMaximum =
            (historicEnergyUse!.rateHighThreshold * 1.1);
        var sections = List<chart.PieChartSectionData>.empty(growable: true);
        final usage = historicEnergyUse!.hourlyAverages();
        final isImportant = getHighlights(usage);
        for (int hour = 0; hour < 24; hour++) {
          final double price = usage[hour];

          double barHeight = price;
          if (price < 0.0) {
            // Large negative bars look really bad.
            barHeight = -1.0;
          }
          if (price == 0.0 || !price.isFinite) {
            // Chart cannot render a zero height bar.
            barHeight = 0.001;
          }
          sections.add(chart.PieChartSectionData(
            value: 1,
            showTitle: price.isFinite && isImportant.contains(price),
            title: '${price.toStringAsFixed(1)}${historicEnergyUse!.units}',
            radius: outerRadius * barHeight / barHeightMaximum,
            titlePositionPercentageOffset:
                1 + 0.1 * barHeightMaximum / barHeight,
            color: theme.colorScheme.primary,
          ));
        }
         return  chart.PieChart(
              chart.PieChartData(
                sections: sections,
                centerSpaceRadius: innerRadius,
                startDegreeOffset: (360 / 24) * 5,
              ),
            );
      });
    }
    return Center(
      child: ElevatedButton(
        child: const Text('Load your usage data'),
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform
              .pickFiles(type: FileType.custom, allowedExtensions: ['csv']);

          // The result will be null, if the user aborted the dialog
          if (result != null) {
            setState(() {
              File file = File(result.files.first.path!);
              historicEnergyUse = HourlyEnergyUse.fromComEdCsvFile(file);
            });
          }
        },
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
              'Run your appliances when electricity rates are low.',
              textAlign: TextAlign.left,
              textScaleFactor: 1,
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
