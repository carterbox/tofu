// tofu, an app for visualizing time-of-use electricity rates
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
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;

final _datefmt = intl.NumberFormat('##00', 'en_US');

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
  final firstHour = now.add(const Duration(hours: 1));
  final finalHour = now.add(const Duration(hours: 24));
  var windowedRates = List<double>.filled(24, 0, growable: false);
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
  final tomorrow = today.add(const Duration(days: 1));
  final response1 = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=daynexttoday&date=${_dateWithZeros(tomorrow)}'));
  if (response0.statusCode == 200 && response1.statusCode == 200) {
    return CentPerEnergyRates.fromJavaScriptText(
        response0.body + response1.body);
  } else {
    throw Exception('Failed to load rates from last 24 hours.');
  }
}

/// A collection of energy rates over time.
abstract class EnergyRates {
  /// Times corresponding the end of period for each of the [rates].
  final List<DateTime> dates;

  /// The number of [units] per kwh
  final List<double> rates;

  const EnergyRates({
    required this.dates,
    required this.rates,
  });
}

/// A collection of US dollar cents per kWh across multiple periods.
class CentPerEnergyRates extends EnergyRates {
  /// The unit of measure for the [rates].
  static const String units = '\u00A2';

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

  /// Concatenate another [CentPerEnergyRates] to this one.
  CentPerEnergyRates operator +(CentPerEnergyRates other) {
    return CentPerEnergyRates(
      dates: dates + other.dates,
      rates: rates + other.rates,
    );
  }
}
