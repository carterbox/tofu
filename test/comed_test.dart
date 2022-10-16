import 'package:tofu/comed.dart';

void main() {
  const String text =
      '[[Date.UTC(2022,9,16,0,0,0), 5.0], [Date.UTC(2022,9,16,1,0,0), 4.6], [Date.UTC(2022,9,16,2,0,0), 4.2], [Date.UTC(2022,9,16,3,0,0), 4.1], [Date.UTC(2022,9,16,4,0,0), 4.3], [Date.UTC(2022,9,16,5,0,0), 4.5], [Date.UTC(2022,9,16,6,0,0), 5.0], [Date.UTC(2022,9,16,7,0,0), 5.1], [Date.UTC(2022,9,16,8,0,0), 5.2], [Date.UTC(2022,9,16,9,0,0), 5.1], [Date.UTC(2022,9,16,10,0,0), 5.3], [Date.UTC(2022,9,16,11,0,0), 5.2], [Date.UTC(2022,9,16,12,0,0), 5.0], [Date.UTC(2022,9,16,13,0,0), 4.4], [Date.UTC(2022,9,16,14,0,0), 4.1], [Date.UTC(2022,9,16,15,0,0), 4.0], [Date.UTC(2022,9,16,16,0,0), 4.0], [Date.UTC(2022,9,16,17,0,0), 4.6], [Date.UTC(2022,9,16,18,0,0), 5.9], [Date.UTC(2022,9,16,19,0,0), 8.1], [Date.UTC(2022,9,16,20,0,0), 6.1], [Date.UTC(2022,9,16,21,0,0), 5.5], [Date.UTC(2022,9,16,22,0,0), 4.8], [Date.UTC(2022,9,16,23,0,0), 4.3]]';

  const String text0 = '[]';

  final EnergyRates example = EnergyRates.fromText(text, 'cents');
  print(example.dates);
  print(example.rates);
}
