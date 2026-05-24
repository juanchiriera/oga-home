import 'package:flutter/material.dart';

class ExpenseCategory {
  const ExpenseCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.colorIndex,
  });

  final String key;
  final String label;
  final IconData icon;

  /// Index into [expenseCategoryAccent] for on-palette tints.
  final int colorIndex;
}

const kExpenseCategories = <ExpenseCategory>[
  ExpenseCategory(
    key: 'housing',
    label: 'Vivienda',
    icon: Icons.home_work_outlined,
    colorIndex: 0,
  ),
  ExpenseCategory(
    key: 'food',
    label: 'Comida',
    icon: Icons.restaurant_outlined,
    colorIndex: 1,
  ),
  ExpenseCategory(
    key: 'transport',
    label: 'Transporte',
    icon: Icons.directions_car_outlined,
    colorIndex: 2,
  ),
  ExpenseCategory(
    key: 'shopping',
    label: 'Compras',
    icon: Icons.shopping_bag_outlined,
    colorIndex: 3,
  ),
  ExpenseCategory(
    key: 'utilities',
    label: 'Servicios',
    icon: Icons.lightbulb_outline,
    colorIndex: 4,
  ),
  ExpenseCategory(
    key: 'health',
    label: 'Salud',
    icon: Icons.local_hospital_outlined,
    colorIndex: 5,
  ),
  ExpenseCategory(
    key: 'education',
    label: 'Educación',
    icon: Icons.school_outlined,
    colorIndex: 6,
  ),
  ExpenseCategory(
    key: 'leisure',
    label: 'Ocio',
    icon: Icons.sports_esports_outlined,
    colorIndex: 7,
  ),
  ExpenseCategory(
    key: 'other',
    label: 'Otros',
    icon: Icons.category_outlined,
    colorIndex: 8,
  ),
];

Color expenseCategoryAccent(ColorScheme scheme, int index) {
  final tones = <Color>[
    scheme.primary,
    scheme.secondary,
    scheme.tertiary,
    scheme.primaryContainer,
    scheme.secondaryContainer,
    scheme.tertiaryContainer,
    scheme.error,
    scheme.onSurfaceVariant,
    scheme.outline,
  ];
  return tones[index % tones.length];
}
