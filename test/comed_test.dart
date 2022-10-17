import 'package:tofu/comed.dart';
import 'package:test/test.dart';

void main() {
  test('Check EnergyRates from Text constructor', () {
    const String text =
        '[[Date.UTC(2022,9,16,0,0,0), 5.0], [Date.UTC(2022,9,16,23,0,0), 4.3], [Date.UTC(2022,9,16,1,0,0), 4.6], ]';
    final EnergyRates nonempty = EnergyRates.fromText(text, 'cents');
    expect(nonempty.rates, [5.0, 4.3, 4.6]);
    expect(nonempty.dates, [
      DateTime(2022, 9, 16),
      DateTime(2022, 9, 16, 23),
      DateTime(2022, 9, 16, 1)
    ]);

    const String text0 = '[]';
    final EnergyRates empty = EnergyRates.fromText(text0, 'cents');
    expect(empty.rates, List<double>.empty());
    expect(empty.dates, List<DateTime>.empty());
  });
  test('Check fetchRatesNextDay', () async {
    print((await fetchRatesNextDay()).rates);
  });
  test('Check fetchRatesLastDay', () async {
    print((await fetchRatesLastDay()).rates);
  });
}
