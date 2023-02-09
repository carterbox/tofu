import 'dart:io';
import 'package:test/test.dart';
import 'package:electricity_clock/green_button.dart';

void main() {
  test('Check CSV green button loader', () {
    final greenButtonReport = File(
        './test/cec_electric_interval_data_Service 1_2022-12-01_to_2023-02-07.csv');

    final historicEnergyUse = HistoricEnergyUse.fromComEdCsvFile(greenButtonReport);

    print(historicEnergyUse.hourlyAverages());
  });
}
