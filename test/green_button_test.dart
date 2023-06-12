import 'dart:io';
import 'package:electricity_clock/comed.dart';
import 'package:test/test.dart';
import 'package:electricity_clock/green_button.dart';

void main() {
  test('Check CSV green button loader', () {
    final greenButtonReport = File('./assets/data/greenbutton-placeholder.csv');

    final historicEnergyUse =
        HourlyEnergyUse.fromComEdCsvFile(greenButtonReport);

    print(historicEnergyUse.hourlyAverages());
  });

  test('Check CSV green button loader', () async {
    final greenButtonReport = File('./assets/data/greenbutton-placeholder.csv');

    final contents = await greenButtonReport.readAsString();

    final historicEnergyUse = HourlyEnergyUse.fromComEdCsvString(contents);

    print(historicEnergyUse.hourlyAverages());
  });

  test('Check CSV green button loader', () async {
    final greenButtonReport = File('./assets/data/greenbutton-placeholder.csv');

    final historicEnergyUse =
        HourlyEnergyUse.fromComEdCsvFile(greenButtonReport);

    final dateRange = historicEnergyUse.getDateRange();

    final historicEnergyRates = await fetchHistoricHourlyRatesDayRange(
      DateTime(2022, 11, 30),
      DateTime(2023, 02, 07),
    );

    print(dateRange);

    for (final item in historicEnergyUse.usage.entries) {
      if (historicEnergyRates.rates.containsKey(item.key)) {
        final double price = historicEnergyRates.rates[item.key]!;
        final double cost = price * item.value;
        print('Rates are ${price.toStringAsFixed(2)} for ${item.key}');
        print(
            'Spent ${cost.toStringAsFixed(2)} ${historicEnergyRates.units} for ${item.value.toStringAsFixed(2)} kWh');
      } else {
        print('Rates are missing data for ${item.key}');
      }
    }
  });
}
