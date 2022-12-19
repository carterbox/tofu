// tofu, an app for monitoring time-of-use electricity rates
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

/// Draw a small circle indicating sun schedule.

import 'package:fl_chart/fl_chart.dart' as chart;
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

// Yield updated DayInfo every 24 hours
Stream<DayInfo> streamSunriseSunset() async* {
  while (true) {
    yield DayInfo.forToday();
    await Future.delayed(const Duration(hours: 24));
  }
}

/// A widget representing the ratio of daytime to nighttime for [today].
class SolarCircle extends StatelessWidget {
  final double radius;
  final DayInfo today;
  final Color dayColor;
  final Color nightColor;

  const SolarCircle({
    required this.radius,
    required this.today,
    this.dayColor = Colors.amber,
    this.nightColor = Colors.indigo,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return chart.PieChart(chart.PieChartData(
      sections: [
        chart.PieChartSectionData(
          value: today.length,
          color: dayColor,
          showTitle: false,
          radius: radius,
        ),
        chart.PieChartSectionData(
          value: 24 - today.length,
          color: nightColor,
          showTitle: false,
          radius: radius,
        ),
      ],
      centerSpaceRadius: 0,
      startDegreeOffset: 15 * (6 + today.sunrise),
    ));
  }
}
