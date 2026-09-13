import 'dart:math' as math;

import 'package:flutter/material.dart';

class SmoothLinePath {
  const SmoothLinePath({required this.path, required this.coordinates});

  final Path path;
  final List<Offset> coordinates;
}

/// Builds a smooth cubic line without overshooting between adjacent samples.
///
/// The coordinates are returned with the path so markers, selection handles,
/// and area fills cannot drift away from the line they describe.
SmoothLinePath buildMonotoneSmoothLinePath({
  required List<double> values,
  required Offset Function(double value, int index) position,
}) {
  if (values.isEmpty) {
    return SmoothLinePath(path: Path(), coordinates: const []);
  }

  final coordinates = [
    for (var i = 0; i < values.length; i++) position(values[i], i),
  ];
  final path = Path()..moveTo(coordinates.first.dx, coordinates.first.dy);
  if (coordinates.length == 1) {
    return SmoothLinePath(path: path, coordinates: coordinates);
  }

  final slopes = [
    for (var i = 0; i < coordinates.length - 1; i++)
      (coordinates[i + 1].dy - coordinates[i].dy) /
          (coordinates[i + 1].dx - coordinates[i].dx),
  ];
  final tangents = List<double>.filled(coordinates.length, 0);
  tangents.first = slopes.first;
  tangents.last = slopes.last;
  for (var i = 1; i < tangents.length - 1; i++) {
    final incoming = slopes[i - 1];
    final outgoing = slopes[i];
    tangents[i] = incoming * outgoing <= 0 ? 0 : (incoming + outgoing) / 2;
  }

  // Hyman filtering keeps each cubic segment monotonic even when the data
  // changes sharply after a flat or slowly changing run.
  for (var i = 0; i < slopes.length; i++) {
    final slope = slopes[i];
    if (slope == 0) {
      tangents[i] = 0;
      tangents[i + 1] = 0;
      continue;
    }
    final a = tangents[i] / slope;
    final b = tangents[i + 1] / slope;
    final radius = math.sqrt(a * a + b * b);
    if (radius > 3) {
      final scale = 3 / radius;
      tangents[i] = scale * a * slope;
      tangents[i + 1] = scale * b * slope;
    }
  }

  for (var i = 0; i < coordinates.length - 1; i++) {
    final current = coordinates[i];
    final next = coordinates[i + 1];
    final dx = next.dx - current.dx;
    final control1 = Offset(
      current.dx + dx / 3,
      current.dy + tangents[i] * dx / 3,
    );
    final control2 = Offset(
      next.dx - dx / 3,
      next.dy - tangents[i + 1] * dx / 3,
    );
    path.cubicTo(
      control1.dx,
      control1.dy,
      control2.dx,
      control2.dy,
      next.dx,
      next.dy,
    );
  }

  return SmoothLinePath(path: path, coordinates: coordinates);
}
