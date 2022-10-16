import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

Future<EnergyRates> fetchRatesLast24Hours() async {
  final response = await http.get(Uri.parse(
      'https://hourlypricing.comed.com/api?type=5minutefeed&format=json'));
  if (response.statusCode == 200) {
    return EnergyRates.fromJson(jsonDecode(response.body), '\u00A2');
  } else {
    throw Exception('Failed to load rates from last 24 hours.');
  }
}

class EnergyRates {
  // The time corresponding to each rate
  final List<DateTime> dates;
  // The unit of measure
  final String units;
  // The number of units per kwh
  final List<double> rates;

  const EnergyRates({
    required this.dates,
    required this.units,
    required this.rates,
  });

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
}
