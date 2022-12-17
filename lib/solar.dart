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

/// Return a Widget representing the ratio of daytime to night time
chart.PieChart getSolarCircle(double radius, DateTime today) {
  final chicago = getSunriseSunset(
    41.8781,
    -87.6298,
    const Duration(),
    today,
  );
  final clockOffset =
      chicago.sunrise.toLocal().hour + chicago.sunrise.toLocal().minute / 60;
  final dayLength = chicago.sunset.difference(chicago.sunrise).inMinutes / 60;
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
    startDegreeOffset: 360.0 / 24.0 * (6 + clockOffset),
  ));
}
