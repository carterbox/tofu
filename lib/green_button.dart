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

import 'package:fl_chart/fl_chart.dart' as chart;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'comed.dart';

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

class HistoricEnergyUseClock extends StatelessWidget {
  final HourlyEnergyUse historicEnergyUse;
  final double radius;

  const HistoricEnergyUseClock({
    super.key,
    required this.historicEnergyUse,
    this.radius = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double diameter =
          0.5 * min(constraints.maxHeight, constraints.maxWidth);

      final innerRadius = diameter * radius * 0.25;
      final outerRadius = diameter * radius * 0.75;

      final theme = Theme.of(context);
      final double barHeightMaximum =
          (historicEnergyUse.rateHighThreshold * 1.1);
      var sections = List<chart.PieChartSectionData>.empty(growable: true);
      // final isImportant = historicEnergyUse.getHighlights();
      final usage = historicEnergyUse.hourlyAverages();
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
          showTitle: price.isFinite, // && isImportant.contains(price),
          title: '${price.toStringAsFixed(1)}${historicEnergyUse.units}',
          radius: outerRadius * barHeight / barHeightMaximum,
          titlePositionPercentageOffset: 1 + 0.1 * barHeightMaximum / barHeight,
          color: theme.colorScheme.primary,
        ));
      }
      return chart.PieChart(
        chart.PieChartData(
          sections: sections,
          centerSpaceRadius: innerRadius,
          startDegreeOffset: (360 / 24) * 4,
        ),
      );
    });
  }
}

class HistoricEnergyUseExplainer extends StatelessWidget {
  const HistoricEnergyUseExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).dialogBackgroundColor,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'What is your historic energy use?',
              textAlign: TextAlign.left,
              textScaleFactor: 2,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Run your appliances when electricity rates are low.',
              textAlign: TextAlign.left,
              textScaleFactor: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: MaterialButton(
              child: const Text('Load data from file'),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                    type: FileType.custom, allowedExtensions: ['csv']);

                // The result will be null, if the user aborted the dialog
                if (result != null) {
                  File file = File(result.files.first.path!);
                  final history = HourlyEnergyUse.fromComEdCsvFile(file);
                  print(history.usage[0]);
                }
              },
            ),
          ),
          const Padding(
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
