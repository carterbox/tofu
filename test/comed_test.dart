import 'package:electricity_clock/comed.dart';
import 'package:test/test.dart';

void main() {
  test('Check EnergyRates from Text constructor', () {
    const String text =
        '[[Date.UTC(2022,9,16,0,0,0), 5.0], [Date.UTC(2022,9,16,23,0,0), 4.3], [Date.UTC(2022,9,16,1,0,0), 4.6], ]';
    final EnergyRates nonempty = CentPerEnergyRates.fromJavaScriptText(text);
    expect(nonempty.rates, [5.0, 4.3, 4.6]);
    expect(nonempty.dates, [
      DateTime(2022, 10, 16),
      DateTime(2022, 10, 16, 23),
      DateTime(2022, 10, 16, 1)
    ]);

    const String text0 = '[]';
    final EnergyRates empty = CentPerEnergyRates.fromJavaScriptText(text0);
    expect(empty.rates, List<double>.empty());
    expect(empty.dates, List<DateTime>.empty());
  });
  test('Check fetchRatesNextDay', () async {
    print((await fetchRatesNextDay()).rates);
  });
  test('Check fetchRatesLastDay', () async {
    print((await fetchRatesLastDay()).rates);
  });
  test('Check getStrictHourRates', () async {
    final unstrictRates = (await fetchRatesNextDay());
    final rates = getStrictHourRates(unstrictRates);
    expect(rates.length, 24);
    print(rates);
    print(unstrictRates.rates);
  });
  test('Check fetchCurrentHourAverage', () async {
    final rate = (await fetchCurrentHourAverage());
    expect(rate >= 0, true);
    print(rate);
  });
}
