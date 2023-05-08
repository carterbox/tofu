import 'package:electricity_clock/comed.dart';
import 'package:test/test.dart';

void main() {
  test('Check EnergyRates from Text constructor', () {
    const String text =
        '[[Date.UTC(2022,9,16,0,0,0), 5.0], [Date.UTC(2022,9,16,23,0,0), 4.3], [Date.UTC(2022,9,16,1,0,0), 4.6], ]';
    final HourlyEnergyRates nonempty =
        CentPerEnergyRates.fromJavaScriptText(text);
    print(nonempty.rates);
    expect(nonempty.rates, {DateTime(2022, 10, 16): 5.0, DateTime(2022, 10, 16, 23): 4.3, DateTime(2022, 10, 16, 1): 4.6});

    const String text0 = '[]';
    final HourlyEnergyRates empty =
        CentPerEnergyRates.fromJavaScriptText(text0);
    print(empty.rates);
    expect(empty.rates, {});
  });

  test('Check fetchRatesNextDay', () async {
    print((await fetchRatesNextDay()).rates);
  });

  test('Check fetchCurrentHourAverage', () async {
    final rate = (await fetchCurrentHourAverage());
    expect(rate >= 0, true);
    print(rate);
  });

  test('Check getHourlyAverages', () async {
    final empty = await fetchHistoricHourlyRatesDayRange(
      DateTime(2022, 10, 1),
      DateTime(2022, 10, 1),
    );
    expect(empty.rates, {});

    final singleDay = await fetchHistoricHourlyRatesDayRange(
      DateTime(2022, 10, 1),
      DateTime(2022, 10, 2),
    );
    expect(singleDay.rates.length, 24);
  });
}
