// tofu, an app for visualizing time-of-use electricity rates
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

/// A widget representing the ratio of daytime to nighttime for [today].
class SolarCircle extends StatelessWidget {
  final double radius;
  late final double dayLength;
  late final double startDegreeOffset;

  SolarCircle({
    required this.radius,
    required DateTime today,
    super.key,
  }) {
    final chicago = getSunriseSunset(
      41.8781,
      -87.6298,
      const Duration(),
      today,
    );
    startDegreeOffset = 15 *
        (6 + // offset to midnight
            chicago.sunrise.toLocal().hour +
            chicago.sunrise.toLocal().minute / 60 // offset to sunrise
        );
    dayLength = chicago.sunset.difference(chicago.sunrise).inMinutes / 60;
  }

  @override
  Widget build(BuildContext context) {
    return chart.PieChart(chart.PieChartData(
      sections: [
        chart.PieChartSectionData(
          value: dayLength,
          color: Colors.amber,
          showTitle: false,
          radius: radius,
        ),
        chart.PieChartSectionData(
          value: 24 - dayLength,
          color: Colors.indigo,
          showTitle: false,
          radius: radius,
        ),
      ],
      centerSpaceRadius: 0,
      startDegreeOffset: startDegreeOffset,
    ));
  }
}
