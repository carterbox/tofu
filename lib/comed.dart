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

/// Fetch and display electricity rate data from the ComEd REST API.
///
/// Note that in accordance to the COMED API, all prices are label with period
/// ending. i.e. If you ask for the 5 minute price at 10:00 pm, then the price
/// is for the period from 9:55 pm to 10:00 pm. If you ask for the hourly price
/// at 1:00 pm, the price is the average from 12:00 pm to 1:00 pm.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart' as chart;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:logging/logging.dart' as logging;

final _datefmt = intl.NumberFormat('##00', 'en_US');
final _logger = logging.Logger('electricity_clock.comed');

String _dateWithZeros(DateTime date) {
  final str =
      '${_datefmt.format(date.year)}${_datefmt.format(date.month)}${_datefmt.format(date.day)}';
  return str;
}

/// Rounds the given [date] to the hour's end
///
/// Year, month, and day are the same. Increase the hour if the minute is
/// greater than 0.
DateTime convertToHourEnd(DateTime date) {
  if (date.minute > 0) {
    date = date.add(const Duration(hours: 1));
  }
  return DateTime(date.year, date.month, date.day, date.hour);
}

/// Rounds the given [date] to the day's end
///
/// Year, month are the same. Increase the hour if the minute is
/// greater than 0.
DateTime convertToDayEnd(DateTime date) {
  date = convertToHourEnd(date);
  if (date.hour > 0) {
    date = date.add(const Duration(days: 1));
  }
  return DateTime(date.year, date.month, date.day);
}

/// Returns the 5-minute rates from the days in range (start, end].
///
/// Prices are period-ending, so to get prices for today the range would be from
/// (the end of) yesterday to (the end of) today.
Future<CentPerEnergyRates> fetchHistoricHourlyRatesDayRange(
  DateTime start,
  DateTime end,
) async {
  start = convertToDayEnd(start);
  end = convertToDayEnd(end);

  if (start.isBefore(end)) {
    List<DateTime> dates = [end];
    while (dates.last.isAfter(start)) {
      dates.add(dates.last.subtract(const Duration(days: 1)));
    }

    final List<http.Response> responses = await Future.wait(dates.map(
      (date) {
        return http.get(Uri.parse(
            'https://hourlypricing.comed.com/api?type=day&date=${_dateWithZeros(date)}'));
      },
    ));

    final String texts = responses.map(
      (response) {
        if (response.statusCode == 200) {
          return response.body;
        } else {
          throw Exception(
              'Failed to retrieve historic rates on a day in range $start to $end.');
        }
      },
    ).join();

    _logger.info('Fetched hourly prices from ComEd from $start to $end.');
    return CentPerEnergyRates.fromJavaScriptText(texts);
  }

  return const CentPerEnergyRates(rates: {});
}

/// Returns the hour-average rate for the current hour.
///
/// Updated every 5 minutes.
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
  return CentPerEnergyRates.fromJavaScriptText(response0.body + response1.body);
}

class EnergyRatesUpdate {
  final HourlyEnergyRates forecast;
  final double currentHour;

  const EnergyRatesUpdate({
    required this.forecast,
    required this.currentHour,
  });
}

/// Stream the hourly energy price forecast for as much of the following 24
/// hours as possible along with and the current hourly average price
///
/// The stream yields every 5 minutes +/- 15 seconds with a new current hour
/// average if the forecast is not null. Each API, the forecast and current
/// hourly average are called separately and only as needed.
Stream<EnergyRatesUpdate> streamRatesNextDay() async* {
  final randomInt = Random();
  DateTime lastUpdate = DateTime(0);
  HourlyEnergyRates? forecast;
  while (true) {
    try {
      if (DateTime.now().hour != lastUpdate.hour ||
          DateTime.now().difference(lastUpdate) >= const Duration(hours: 1)) {
        forecast = await fetchRatesNextDay();
        _logger.info('Prices forecast from ComEd updated.');
      }
      if (forecast != null) {
        yield EnergyRatesUpdate(
          forecast: forecast,
          currentHour: await fetchCurrentHourAverage(),
        );
        lastUpdate = DateTime.now();
      }
      _logger.info('Prices hourly from ComEd updated.');
    } on http.ClientException catch (error) {
      // Ignore errors and just wait another 5 minutes to try again
      _logger.warning(error);
    }
    await Future.delayed(
        Duration(minutes: 5, seconds: randomInt.nextInt(30) - 15));
  }
}

/// A collection of hourly energy rates over time.
@immutable
abstract class HourlyEnergyRates {
  /// Times corresponding the end of period for each of the [rates].
  final Map<DateTime, double> rates;

  /// The unit of measure for the [rates].
  String get units;

  /// Above this value is a high rate of [units] per kWh
  double get rateHighThreshold;

  /// Above this value is a middle rate of [units] per kWh
  double get rateMidThreshold;

  const HourlyEnergyRates({
    required this.rates,
  });

  /// Provides min, median, and max rates in that order
  List<double> getHighlights() {
    var finiteRates = Map<DateTime, double>.of(rates);
    finiteRates.removeWhere((key, value) => !(value.isFinite));

    var ratesSorted = finiteRates.values.toList();
    ratesSorted.sort();

    return [
      ratesSorted[0],
      ratesSorted[finiteRates.length ~/ 2],
      ratesSorted[finiteRates.length - 1],
    ];
  }
}

/// A collection of US dollar cents per kWh across multiple periods.
@immutable
class CentPerEnergyRates extends HourlyEnergyRates {
  @override
  final String units = '\u00A2/kWh';
  @override
  final double rateHighThreshold = 15;
  @override
  final double rateMidThreshold = 7.5;

  const CentPerEnergyRates({
    required super.rates,
  });

  /// Construct from json: [{"millisUTC":"1665944400000","price":"3.0"}, ...]
  ///
  /// If multiple rates share the same hour, they are averaged together using
  /// the same weight for each entry.
  factory CentPerEnergyRates.fromJson(List<dynamic> json) {
    Map<DateTime, List<double>> rates = {};

    for (final x in json) {
      final date = convertToHourEnd(DateTime.fromMillisecondsSinceEpoch(
        int.parse(x['millisUTC']),
        isUtc: true,
      ).toLocal());

      final price = double.parse(x['price']);

      var prices = rates.putIfAbsent(date, () => []);
      prices.add(price);
    }

    return CentPerEnergyRates(
      rates: rates.map<DateTime, double>((key, value) {
        return MapEntry(key, value.average);
      }),
    );
  }

  /// Construct from a string: [ [Date.UTC(2022,9,16,23,0,0), 4.3], ...]
  ///
  /// JavaScript uses 0 indexed month, but Dart uses 1 indexed month, so we have
  /// to correct for that.
  ///
  /// If multiple rates share the same hour, they are averaged together using
  /// the same weight for each entry.
  factory CentPerEnergyRates.fromJavaScriptText(String text) {
    Map<DateTime, List<double>> rates = {};

    // Replace the constructor in the string
    final regex = RegExp(r'[0-9]+\.?[0-9]*');
    final numbers =
        regex.allMatches(text).map((x) => x[0]!).toList(growable: false);

    for (var i = 0; i < numbers.length; i += 7) {
      final date = convertToHourEnd(DateTime(
        int.parse(numbers[i]), // year
        int.parse(numbers[i + 1]) + 1, // month
        int.parse(numbers[i + 2]), // day
        int.parse(numbers[i + 3]), // hour
        int.parse(numbers[i + 4]), // minute
        int.parse(numbers[i + 5]), // second
      ));
      final price = double.parse(numbers[i + 6]);

      var prices = rates.putIfAbsent(date, () => []);
      prices.add(price);
    }

    return CentPerEnergyRates(
      rates: rates.map<DateTime, double>((key, value) {
        return MapEntry(key, value.average);
      }),
    );
  }

  /// Trim energy rates to exactly 24 hours in the future
  CentPerEnergyRates toExactly24Hours() {
    Map<DateTime, double> rates = {};

    final firstHour = convertToHourEnd(DateTime.now());

    for (int i = 0; i < 24; i++) {
      final thisHour = firstHour.add(Duration(hours: i));
      if (this.rates.containsKey(thisHour)) {
        rates[thisHour] = this.rates[thisHour]!;
      }
    }

    return CentPerEnergyRates(
      rates: rates,
    );
  }

  @override
  String toString() {
    return rates.entries
        .map((e) => '${e.value.toStringAsFixed(2)}$units hour-ending ${e.key}')
        .join('\n');
  }

  CentPerEnergyRates filterByWeekday(Set<int> weekdays) {
    final filteredUsage = Map.of(rates);
    filteredUsage.removeWhere((key, value) => !weekdays.contains(key.weekday));
    return CentPerEnergyRates(
      rates: filteredUsage,
    );
  }

  factory CentPerEnergyRates.placeholder() {
    Map<DateTime, double> rates = {
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
      DateTime(2023, 1, 3, 01): 0.3,
    };
    return CentPerEnergyRates(rates: rates);
  }

  /// Return 24 averaged hour-ending readings
  List<double> hourlyAverages() {
    if (rates.isEmpty) {
      return List<double>.filled(24, double.nan, growable: false);
    }

    var totals = List<double>.filled(24, 0.0, growable: false);
    var counts = List<double>.filled(24, 0.0, growable: false);
    for (final reading in rates.entries) {
      final hour = reading.key.hour;
      totals[hour] += reading.value;
      counts[hour] += 1;
    }

    return [for (var i = 0; i < totals.length; ++i) totals[i] / counts[i]];
  }
}

/// A circular bar chart showing the current and forecasted energy rates for a
/// 24 hour period
class PriceClock extends StatelessWidget {
  final HourlyEnergyRates energyRates;
  final double radius;
  final double currentHourRate;

  const PriceClock({
    super.key,
    required this.energyRates,
    this.radius = 1.0,
    this.currentHourRate = double.nan,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double diameter =
          0.5 * min(constraints.maxHeight, constraints.maxWidth);

      final innerRadius = diameter * radius * 0.25;
      final outerRadius = diameter * radius * 0.75;

      final theme = Theme.of(context);
      final double barHeightMaximum = (energyRates.rateHighThreshold * 1.1);
      var sections = List<chart.PieChartSectionData>.empty(growable: true);
      final isImportant = energyRates.getHighlights();
      DateTime currentHour = convertToHourEnd(DateTime.now());
      for (int hour = 0; hour < 24; hour++) {
        final bool isCurrentHour = (hour == 0);
        final double price = isCurrentHour
            ? currentHourRate
            : energyRates.rates[currentHour.add(Duration(hours: hour))] ??
                double.nan;

        double barHeight = price;
        if (price < 0.0) {
          // Large negative bars look really bad.
          barHeight = -1.0;
        }
        if (price == 0.0 || !price.isFinite) {
          barHeight = 0.0;
        }
        sections.add(chart.PieChartSectionData(
          value: 1,
          showTitle:
              price.isFinite && (isCurrentHour || isImportant.contains(price)),
          title: '${price.toStringAsFixed(1)}${energyRates.units}',
          titleStyle: TextStyle(
            color: isCurrentHour
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            shadows: <Shadow>[
              Shadow(
                blurRadius: 2.0,
                color: isCurrentHour
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.primaryContainer,
              ),
            ],
          ),
          radius: outerRadius * barHeight / barHeightMaximum,
          titlePositionPercentageOffset: 1 + 0.1 * barHeightMaximum / barHeight,
          borderSide: BorderSide(
            color: isCurrentHour
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onPrimaryContainer,
          ),
          color: isCurrentHour
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.primaryContainer,
        ));
      }
      return chart.PieChart(
        chart.PieChartData(
          sections: sections,
          centerSpaceRadius: innerRadius,
          startDegreeOffset: (360 / 24) * (currentHour.hour + 5),
        ),
      );
    });
  }
}

class PriceClockExplainer extends StatelessWidget {
  const PriceClockExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.primaryContainer,
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'When should you run your appliances?',
              textAlign: TextAlign.left,
              textScaler: TextScaler.linear(2.0),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Run your appliances when electricity rates are low.',
              textAlign: TextAlign.left,
              textScaler: TextScaler.linear(1.0),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'This chart shows the current and forecasted hourly average electricity prices for as much of the next 24 hours as possible in the Chicagoland ComEd energy market.',
              textAlign: TextAlign.left,
              textScaler: TextScaler.linear(1.0),
            ),
          ),
        ],
      ),
    );
  }
}

/// A button which toggles a model bottom sheet containing PriceClockExplainer
class PriceClockExplainerButton extends StatelessWidget {
  const PriceClockExplainerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      child: const Icon(Icons.question_mark),
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (BuildContext context) {
            return const PriceClockExplainer();
          },
        );
      },
    );
  }
}

class PriceClockLoading extends StatelessWidget {
  const PriceClockLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final diameter = min(constraints.maxHeight, constraints.maxWidth);
      return Align(
        child: SizedBox(
          width: 0.25 * diameter,
          height: 0.25 * diameter,
          child: CircularProgressIndicator(
            strokeWidth: 0.01 * diameter,
          ),
        ),
      );
    });
  }
}
