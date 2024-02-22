// electricity_clock, an app for monitorign time-of-use electricity rates
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

/// Provides a widget showing the forecasted electricity rates for 24 hours

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart' as chart;
import 'dart:math' as math;

import '../data/comed.dart';

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

/// A placeholder for when the forecasted energy rates are not yet known
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
              '24 Hour Forecast of Electricity Prices',
              textAlign: TextAlign.left,
              textScaler: TextScaler.linear(2.0),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'in cents per kWh',
              textAlign: TextAlign.left,
              textScaler: TextScaler.linear(1.5),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'This chart shows the current and forecasted hourly average electricity prices for the Chicagoland ComEd electricity market. The current hour is highlighted. Noon appears at the top of the figure and midnight at the bottom. The area of each bar scales with the price.',
              textAlign: TextAlign.left,
              textScaler: TextScaler.linear(1.0),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Reduce your electricity bill by shifting electricity use to hours when electricity prices are low.',
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
