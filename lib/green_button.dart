import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:graphic/graphic.dart';

/// Represents measured energy use between [start] and [end] times
@immutable
class EnergyUse {
  static const String units = 'kWh';

  /// How much energy was used in kWh
  final double usage;

  /// When the energy use period started
  final DateTime start;

  /// When the energy use period ended
  final DateTime end;

  EnergyUse({
    required this.usage,
    required this.start,
    required this.end,
  }) {
    if (start.isAfter(end)) {
      throw ArgumentError('The start of an EnergyUse cannot be after its end');
    }
  }

  @override
  String toString() {
    return '$usage$units from $start until $end.';
  }
}

/// A collection of [EnergyUse] across multiple time periods
@immutable
class HistoricEnergyUse {
  /// A list of [EnergyUse]
  final List<EnergyUse> readings;

  const HistoricEnergyUse({required this.readings});

  /// Construct a [HistoricEnergyUse] from a ComEd Green Button comma-separated
  /// file
  ///
  /// This CSV file has a header followed by column labels and then data. The
  /// headers and example first row are as follows:
  ///
  /// TYPE,DATE,START TIME,END TIME,USAGE,UNITS,COST,NOTES
  /// Electric usage,2022-12-01,00:00,00:29,0.16,kWh,$0.02,
  ///
  /// https://www.energy.gov/data/green-button
  factory HistoricEnergyUse.fromComEdCsvFile(File file) {
    List<EnergyUse> readings = [];

    for (final line in file.readAsLinesSync()) {
      final tokens = line.split(',');

      if (tokens[0] == 'Electric usage') {
        final date = tokens[1].split('-');
        final int year = int.parse(date[0]);
        final int month = int.parse(date[1]);
        final int day = int.parse(date[2]);

        var time = tokens[2].split(':');
        final start =
            DateTime(year, month, day, int.parse(time[0]), int.parse(time[1]));

        time = tokens[3].split(':');
        final end =
            DateTime(year, month, day, int.parse(time[0]), int.parse(time[1]));

        final usage = double.parse(tokens[4]);

        readings.add(EnergyUse(usage: usage, start: start, end: end));
      }
    }

    readings.sort((a, b) {
      return a.start.compareTo(b.start);
    });

    return HistoricEnergyUse(readings: readings);
  }

  /// Return 24 averaged hour-ending readings
  List<double> hourlyAverages() {
    var totals = List<double>.filled(24, 0.0, growable: false);
    var counts = List<double>.filled(24, 0.0, growable: false);

    for (final reading in readings) {
      int hour = (reading.start.hour + 1) % 24;
      totals[hour] += reading.usage;
      counts[hour] += 0.5;
    }

    return [for (var i = 0; i < totals.length; ++i) totals[i] / counts[i]];
  }

  HistoricEnergyUse filterByWeekday(List<int> weekdays) {
    return HistoricEnergyUse(
      readings: readings
          .where((element) => weekdays.contains(element.end.weekday))
          .toList(growable: false),
    );
  }

  HistoricEnergyUse filterByMonth(List<int> months) {
    return HistoricEnergyUse(
      readings: readings
          .where((element) => months.contains(element.end.month))
          .toList(growable: false),
    );
  }

  HistoricEnergyUse filterByDate(DateTime start, DateTime end) {
    return HistoricEnergyUse(
      readings: readings
          .where((element) =>
              element.start.compareTo(start) >= 0 &&
              element.end.compareTo(end) < 0)
          .toList(growable: false),
    );
  }
}

class HistoricEnergyUseClock extends StatelessWidget {
  const HistoricEnergyUseClock(this.historicEnergyUse, {super.key});

  final HistoricEnergyUse historicEnergyUse;

  @override
  Widget build(BuildContext context) {
    List<Map> dataSets = [];
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.indigo,
      Colors.purple
    ];
    const labels = [
      'Weekdays',
      'Weekends',
    ];
    const groups = [
      [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ],
      [
        DateTime.saturday,
        DateTime.sunday,
      ],
    ];
    for (int i = 0; i < groups.length; i++) {
      final groupHistoricUse =
          historicEnergyUse.filterByWeekday(groups[i]).hourlyAverages();
      for (int hour = 0; hour < 24; hour++) {
        dataSets.add(
            {'day': i, 'usage': groupHistoricUse[hour], 'hour': hour});
      }
    }
    return Chart(
      data: dataSets,
      variables: {
        'hour': Variable(
          accessor: (Map map) => map['hour'] as num,
        ),
        'usage': Variable(
          accessor: (Map map) => map['usage'] as num,
        ),
        'day': Variable(
          accessor: (Map map) => map['day'] as num,
        ),
      },
      elements: [
        IntervalElement(
          position:
              Varset('hour') * Varset('usage') / Varset('day'),
          color: ColorAttr(
              variable: 'day', values: Defaults.colors10),
          size: SizeAttr(value: 2),
          modifiers: [DodgeModifier(ratio: 0.1)],
        )
      ],
      axes: [
        Defaults.horizontalAxis,
        Defaults.verticalAxis,
      ],
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
                  final history = HistoricEnergyUse.fromComEdCsvFile(file);
                  print(history.readings[0]);
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
