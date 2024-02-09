import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart' as chart;
import 'dart:math' as math;

import '../data/comed.dart';


final streamOfEnergyRates = StreamProvider<EnergyRatesUpdate>((ref) async* {
  await for (final rate in streamRatesNextDay()) {
    yield rate;
  }
});

class StreamingPriceClock extends ConsumerWidget {
  const StreamingPriceClock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(streamOfEnergyRates).when(
          error: (error, stackTrace) => const PriceClockLoading(),
          loading: () => const PriceClockLoading(),
          data: (data) => PriceClock(
            energyRates: data.forecast,
            currentHourRate: data.currentHour,
          ),
        );
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
      final double maxAllowedRadius = 0.5 *
          math.min(
            constraints.maxHeight,
            constraints.maxWidth,
          );

      final centerSpaceRadius = maxAllowedRadius * 0.25;
      final barMaxRadialSize = maxAllowedRadius - centerSpaceRadius;

      final theme = Theme.of(context);
      final double barHeightMaximum = (energyRates.rateHighThreshold * 1.1);
      var sections = List<chart.PieChartSectionData>.empty(growable: true);
      final importantRates = energyRates.getHighlights();
      DateTime currentHour = convertToHourEnd(DateTime.now());
      for (int hour = 0; hour < 24; hour++) {
        final bool isCurrentHour = (hour == 0);
        final double price = isCurrentHour
            ? currentHourRate
            : energyRates.rates[currentHour.add(Duration(hours: hour))] ??
                double.nan;
        sections.add(createSection(
          value: price,
          units: energyRates.units,
          colorText: isCurrentHour
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onPrimaryContainer,
          colorTextShadow: isCurrentHour
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.primaryContainer,
          colorBorder: isCurrentHour
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onPrimaryContainer,
          color: isCurrentHour
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.primaryContainer,
          isImportant: isCurrentHour || importantRates.contains(price),
          maxValue: barHeightMaximum,
          centerSpaceRadius: centerSpaceRadius,
          barMaxRadialSize: barMaxRadialSize,
        ));
      }
      return chart.PieChart(
        chart.PieChartData(
          sections: sections,
          centerSpaceRadius: centerSpaceRadius,
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
    return Container(
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
    final colorScheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
      tooltip: 'Explain chart',
      heroTag: 'explainer',
      child: const Icon(Icons.question_mark),
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: colorScheme.primaryContainer,
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
      final diameter = math.min(constraints.maxHeight, constraints.maxWidth);
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
