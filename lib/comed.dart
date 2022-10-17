/// Fetch electricity rate data from ComEd REST API.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;

final _datefmt = intl.NumberFormat('##00', 'en_US');

String _dateWithZeros(DateTime date) {
  return '${_datefmt.format(date.year)}${_datefmt.format(date.month)}${_datefmt.format(date.day)}';
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

  // FIXME: PieChartSectionData cannot render zero rate, so add a tiny offset
  List<double> averageRates = List<double>.filled(numBins, 0.001);
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

/// Returns the 5-minute rates from the past 24 Hours.
Future<EnergyRates> fetchRatesLast24Hours() async {
  final response = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=5minutefeed&format=json'));
  if (response.statusCode == 200) {
    return EnergyRates.fromJson(jsonDecode(response.body), '\u00A2');
  } else {
    throw Exception('Failed to load rates from last 24 hours.');
  }
}

/// Returns the real hourly rates from the past 24 Hours.
Future<EnergyRates> fetchRatesLastDay() async {
  final now = DateTime.now();
  final response = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=day&date=${_dateWithZeros(now)}'));
  if (response.statusCode == 200) {
    return EnergyRates.fromText(response.body, '\u00A2');
  } else {
    throw Exception('Failed to load rates from last 24 hours.');
  }
}

/// Returns the predicted hourly rates for the next day.
Future<EnergyRates> fetchRatesNextDay() async {
  final now = DateTime.now();
  final response = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=daynexttoday&date=${_dateWithZeros(now)}'));
  if (response.statusCode == 200) {
    return EnergyRates.fromText(response.body, '\u00A2');
  } else {
    throw Exception('Failed to load rates from last 24 hours.');
  }
}

/// A collection of energy rates over time.
class EnergyRates {
  /// Times corresponding the end of period for each of the [rates].
  final List<DateTime> dates;

  /// The unit of measure for the [rates].
  final String units;

  /// The number of [units] per kwh
  final List<double> rates;

  const EnergyRates({
    required this.dates,
    required this.units,
    required this.rates,
  });

  /// Construct from json like this: [{"millisUTC":"1665944400000","price":"3.0"}, ...]
  factory EnergyRates.fromJson(List<dynamic> json, String units) {
    return EnergyRates(
      dates: json
          .map((x) => DateTime.fromMillisecondsSinceEpoch(
                int.parse(x['millisUTC']),
                isUtc: true,
              ).toLocal())
          .toList(),
      units: units,
      rates: json.map((x) => double.parse(x['price'])).toList(),
    );
  }

  /// Construct from a string like this: [ [Date.UTC(2022,9,16,23,0,0), 4.3], ...]
  factory EnergyRates.fromText(String text, String units) {
    // Replace the constructor in the string
    final regex = RegExp(r'[0-9]+\.?[0-9]*');
    final numbers =
        regex.allMatches(text).map((x) => x[0]!).toList(growable: false);
    var dates = List<DateTime>.empty(growable: true);
    var rates = List<double>.empty(growable: true);
    for (var i = 0; i < numbers.length; i += 7) {
      dates.add(DateTime(
        int.parse(numbers[i]),
        int.parse(numbers[i + 1]),
        int.parse(numbers[i + 2]),
        int.parse(numbers[i + 3]),
        int.parse(numbers[i + 4]),
        int.parse(numbers[i + 5]),
      ));
      rates.add(double.parse(numbers[i + 6]));
    }
    return EnergyRates(
      dates: dates,
      units: units,
      rates: rates,
    );
  }
}
