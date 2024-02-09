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

/// Provides a widget representing the sunrise and sunset schedule

library;

import 'dart:math';

import 'package:fl_chart/fl_chart.dart' as chart;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';

/// Represents the time of [sunrise] and [length] of the day in hours
class DayInfo {
  final double sunrise;
  final double length;

  const DayInfo({
    required this.sunrise,
    required this.length,
  });

  factory DayInfo.forToday() {
    return DayInfo.fromSunsetSunriseResult(getSunriseSunset(
      41.8781,
      -87.6298,
      const Duration(),
      DateTime.now(),
    ));
  }

  factory DayInfo.fromSunsetSunriseResult(SunriseSunsetResult result) {
    return DayInfo(
        sunrise: result.sunrise.toLocal().hour +
            result.sunrise.toLocal().minute / 60,
        length: result.sunset.difference(result.sunrise).inMinutes / 60);
  }
}

/// A widget representing the ratio of daytime to nighttime for [today].
///
/// The widget is a pie chart with two sections: a section containing a moon
/// section for night and a section containing a sun icon for day.
class SolarCircle extends StatelessWidget {
  final double radius;
  final DayInfo today;
  final Color dayColor;
  final Color nightColor;

  const SolarCircle({
    this.radius = 1.0,
    this.today = const DayInfo(sunrise: 6, length: 12),
    this.dayColor = Colors.amber,
    this.nightColor = Colors.indigo,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double diameter =
            2 * radius * max(constraints.maxHeight, constraints.maxWidth);
        final double iconSize =
            1 / 16 * min(constraints.maxHeight, constraints.maxWidth);
        return Stack(
          alignment: Alignment.center,
          children: [
            chart.PieChart(chart.PieChartData(
              sections: [
                chart.PieChartSectionData(
                  value: today.length,
                  color: dayColor,
                  showTitle: false,
                  radius: diameter / 2,
                ),
                chart.PieChartSectionData(
                  value: 24 - today.length,
                  color: nightColor,
                  showTitle: false,
                  radius: diameter / 2,
                ),
              ],
              centerSpaceRadius: 0,
              startDegreeOffset: 15 * (6 + today.sunrise),
            )),
            SizedBox(
                width: diameter,
                height: diameter,
                child: Align(
                    alignment: const Alignment(0.0, 0.618),
                    child: Icon(
                      Icons.dark_mode_outlined,
                      color: dayColor,
                      size: iconSize,
                    ))),
            SizedBox(
              width: diameter,
              height: diameter,
              child: Align(
                  alignment: const Alignment(0.0, -0.618),
                  child: Icon(
                    Icons.light_mode,
                    color: nightColor,
                    size: iconSize,
                  )),
            ),
          ],
        );
      },
    );
  }
}

// Yield updated DayInfo every 24 hours
Stream<DayInfo> streamSunriseSunset() async* {
  while (true) {
    yield DayInfo.forToday();
    await Future.delayed(const Duration(hours: 24));
  }
}

final streamOfDayInfo = StreamProvider<DayInfo>((ref) async* {
  await for (final day in streamSunriseSunset()) {
    yield day;
  }
});

class StreamingSolarCircle extends ConsumerWidget {
  const StreamingSolarCircle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayInfo = ref.watch(streamOfDayInfo).when(
          error: (error, stackTrace) => const DayInfo(length: 12, sunrise: 6),
          loading: () => const DayInfo(length: 12, sunrise: 6),
          data: (data) => data,
        );
    return SolarCircle(
      radius: 2.0,
      today: dayInfo,
      dayColor: Theme.of(context).colorScheme.surface,
      nightColor: Theme.of(context).colorScheme.surfaceVariant,
    );
  }
}
