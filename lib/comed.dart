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

/// Fetch electricity rate data from ComEd REST API.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart' as chart;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:logging/logging.dart' as logging;

final _datefmt = intl.NumberFormat('##00', 'en_US');
final _logger = logging.Logger('tofu.comed');

String _dateWithZeros(DateTime date) {
  final str =
      '${_datefmt.format(date.year)}${_datefmt.format(date.month)}${_datefmt.format(date.day)}';
  return str;
}

/// Reduce and EnergyRate into bins of the requested size
List<double> getAverageRates(EnergyRates energyRates, int minutesPerBin) {
  const int minutesPerHour = 60;
  const int minutesPerDay = minutesPerHour * 24;
  assert(minutesPerBin >= 5);
  assert(minutesPerBin <= minutesPerHour);
  while (minutesPerHour ~/ minutesPerBin != minutesPerHour / minutesPerBin) {
    minutesPerBin -= 1;
  }
  final int numBins = minutesPerDay ~/ minutesPerBin;

  List<double> averageRates = List<double>.filled(numBins, 0);
  List<int> counts = List<int>.filled(numBins, 0);

  for (int i = 0; i < energyRates.rates.length; i++) {
    int index =
        (energyRates.dates[i].minute + energyRates.dates[i].hour * 60) ~/
            minutesPerBin;
    counts[index] += 1;
    averageRates[index] += energyRates.rates[i];
  }
  for (int i = 0; i < numBins; i++) {
    if (counts[i] > 0) {
      averageRates[i] /= counts[i];
    }
  }
  return averageRates;
}

/// Trim energy rates to exactly 24 hours in the future future
List<double> getStrictHourRates(EnergyRates x) {
  // Rates are provided as hour ending, so we convert now into the end of hour
  final now = DateTime.now();
  final firstHour = now.add(const Duration(hours: 0));
  final finalHour = now.add(const Duration(hours: 24));
  var windowedRates = List<double>.filled(24, double.nan, growable: false);
  for (int i = 0; i < x.rates.length; i++) {
    final date = x.dates[i];
    final rate = x.rates[i];
    if (date.isAfter(firstHour) && date.isBefore(finalHour)) {
      windowedRates[date.hour] = rate;
    }
  }
  return windowedRates;
}

Future<double> fetchCurrentHourAverage() async {
  final response = await http.get(
      Uri.parse('https://hourlypricing.comed.com/api?type=currenthouraverage'));
  if (response.statusCode == 200) {
    final x = jsonDecode(response.body);
    return double.parse(x[0]['price']);
  } else {
    throw Exception('Failed to get current hour average.');
  }
}

/// Returns the 5-minute rates from the past 24 Hours.
Future<CentPerEnergyRates> fetchRatesLast24Hours() async {
  final response = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=5minutefeed&format=json'));
  if (response.statusCode == 200) {
    return CentPerEnergyRates.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load rates from last 24 hours.');
  }
}

/// Returns the real hourly rates from the past 24 Hours.
Future<CentPerEnergyRates> fetchRatesLastDay() async {
  final today = DateTime.now();
  final response1 = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=day&date=${_dateWithZeros(today)}'));
  final yesterday = today.subtract(const Duration(days: 1));
  final response0 = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=day&date=${_dateWithZeros(yesterday)}'));
  if (response0.statusCode == 200 && response1.statusCode == 200) {
    return CentPerEnergyRates.fromJavaScriptText(
        response0.body + response1.body);
  } else {
    throw Exception('Failed to load rates from last 24 hours.');
  }
}

/// Returns the predicted hourly rates for the next day.
Future<CentPerEnergyRates> fetchRatesNextDay() async {
  final today = DateTime.now();
  final response0 = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=daynexttoday&date=${_dateWithZeros(today)}'));
  if (response0.statusCode != 200) {
    throw http.ClientException(
        'Server responded with status: ${response0.statusCode}');
  }
  final tomorrow = today.add(const Duration(days: 1));
  final response1 = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=daynexttoday&date=${_dateWithZeros(tomorrow)}'));
  if (response1.statusCode != 200) {
    throw http.ClientException(
        'Server responded with status: ${response1.statusCode}');
  }
  return CentPerEnergyRates.fromJavaScriptText(response0.body + response1.body)
      .toExactly24Hours();
}

Stream<CentPerEnergyRates> streamRatesNextDay() async* {
  final randomInt = Random();
  while (true) {
    try {
      yield await fetchRatesNextDay();
      _logger.info('Prices from ComEd updated.');
    } on http.ClientException catch (error) {
      // Ignore errors and just wait another 5 minutes to try again
      _logger.warning(error);
    }
    await Future.delayed(
        Duration(minutes: 5, seconds: randomInt.nextInt(30) - 15));
  }
}

/// A collection of energy rates over time.
abstract class EnergyRates {
  /// Times corresponding the end of period for each of the [rates].
  final List<DateTime> dates;

  /// The number of [units] per kwh
  final List<double> rates;

  /// The unit of measure for the [rates].
  String get units;

  /// Above this value is a high rate of [units] per kWh
  double get rateHighThreshold;

  /// Above this value is a middle rate of [units] per kWh
  double get rateMidThreshold;

  const EnergyRates({
    required this.dates,
    required this.rates,
  });
}

/// A collection of US dollar cents per kWh across multiple periods.
class CentPerEnergyRates extends EnergyRates {
  @override
  final String units = '\u00A2';
  @override
  final double rateHighThreshold = 15;
  @override
  final double rateMidThreshold = 7.5;

  const CentPerEnergyRates({
    required super.dates,
    required super.rates,
  });

  /// Construct from json like this: [{"millisUTC":"1665944400000","price":"3.0"}, ...]
  factory CentPerEnergyRates.fromJson(List<dynamic> json) {
    return CentPerEnergyRates(
      dates: json
          .map((x) => DateTime.fromMillisecondsSinceEpoch(
                int.parse(x['millisUTC']),
                isUtc: true,
              ).toLocal())
          .toList(),
      rates: json.map((x) => double.parse(x['price'])).toList(),
    );
  }

  /// Construct from a string like this: [ [Date.UTC(2022,9,16,23,0,0), 4.3], ...]
  ///
  /// JavaScript uses 0 indexed month, but Dart uses 1 indexed month, so we have
  /// to correct for that.
  factory CentPerEnergyRates.fromJavaScriptText(String text) {
    // Replace the constructor in the string
    final regex = RegExp(r'[0-9]+\.?[0-9]*');
    final numbers =
        regex.allMatches(text).map((x) => x[0]!).toList(growable: false);
    var dates = List<DateTime>.empty(growable: true);
    var rates = List<double>.empty(growable: true);
    for (var i = 0; i < numbers.length; i += 7) {
      dates.add(DateTime(
        int.parse(numbers[i]), // year
        int.parse(numbers[i + 1]) + 1, // month
        int.parse(numbers[i + 2]), // day
        int.parse(numbers[i + 3]), // hour
        int.parse(numbers[i + 4]),
        int.parse(numbers[i + 5]),
      ));
      rates.add(double.parse(numbers[i + 6]));
    }
    return CentPerEnergyRates(
      dates: dates,
      rates: rates,
    );
  }

  /// Trim energy rates to exactly 24 hours in the future
  CentPerEnergyRates toExactly24Hours() {
    // Rates are provided as hour ending, so we convert now into the end of hour
    final now = DateTime.now();
    final firstHour = now.add(const Duration(hours: 0));
    final finalHour = now.add(const Duration(hours: 24));
    var windowedRates = List<double>.filled(24, double.nan, growable: false);
    var windowedDates = List<DateTime>.filled(24, DateTime(0), growable: false);
    for (int i = 0; i < rates.length; i++) {
      final date = dates[i];
      final rate = rates[i];
      if (date.isAfter(firstHour) && date.isBefore(finalHour)) {
        windowedRates[date.hour] = rate;
        windowedDates[date.hour] = date;
      }
    }
    return CentPerEnergyRates(
      rates: windowedRates,
      dates: windowedDates,
    );
  }

  /// Concatenate another [CentPerEnergyRates] to this one.
  CentPerEnergyRates operator +(CentPerEnergyRates other) {
    return CentPerEnergyRates(
      dates: dates + other.dates,
      rates: rates + other.rates,
    );
  }
}

/// A circular bar chart showing the current and forecasted energy rates for a
/// 24 hour period
class PriceClock extends StatelessWidget {
  final EnergyRates energyRates;
  late final double innerRadius;
  late final double outerRadius;

  PriceClock({
    super.key,
    required this.energyRates,
    required radius,
  }) {
    innerRadius = radius * 0.25;
    outerRadius = radius * 0.75;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double barHeightMaximum = (energyRates.rateHighThreshold * 1.1);
    var sections = List<chart.PieChartSectionData>.empty(growable: true);
    for (int hour = 0; hour < energyRates.rates.length; hour++) {
      final double price = energyRates.rates[hour];
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
        showTitle: price.isFinite,
        title: '${price.toStringAsFixed(1)}${energyRates.units}',
        radius: outerRadius * barHeight / barHeightMaximum,
        titlePositionPercentageOffset: 0.66 * barHeightMaximum / barHeight,
        color: hour == (DateTime.now().hour + 1) % 24
            ? theme.colorScheme.inversePrimary
            : theme.colorScheme.primary,
      ));
    }
    return chart.PieChart(
      chart.PieChartData(
        sections: sections,
        centerSpaceRadius: innerRadius,
        startDegreeOffset: (360 / 24) * 5,
      ),
    );
  }
}

/// A button which toggles a bottom drawer with text explaining the Price Clock
class PriceClockExplainerButton extends StatefulWidget {
  const PriceClockExplainerButton({super.key});

  @override
  State<PriceClockExplainerButton> createState() =>
      _PriceClockExplainerButtonState();
}

class _PriceClockExplainerButtonState extends State<PriceClockExplainerButton> {
  bool _showingBottomSheet = false;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
        child: const Icon(Icons.question_mark),
        onPressed: () {
          if (_showingBottomSheet) {
            _showingBottomSheet = false;
            Navigator.pop(context);
            return;
          }
          _showingBottomSheet = true;
          Scaffold.of(context).showBottomSheet<void>(
            (BuildContext context) {
              return Container(
                color: Colors.amber,
                height: 166,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(left: 20, right: 20, top: 50),
                        child: Text(
                          'When should you run your appliances?',
                          textAlign: TextAlign.left,
                          textScaleFactor: 1.5,
                        ),
                      ),
                      Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'This chart shows the current and forecasted hourly average rates for as much of the next 24 hours as possible. Run your appliances when electricity rates are low.',
                            textAlign: TextAlign.left,
                            textScaleFactor: 1.0,
                          ))
                    ],
                  ),
                ),
              );
            },
          );
        });
  }
}
