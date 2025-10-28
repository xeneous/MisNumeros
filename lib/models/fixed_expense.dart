import 'package:flutter/material.dart';

enum ExpenseFrequency {
  weekly('Semanal'),
  monthly('Mensual');

  const ExpenseFrequency(this.displayName);
  final String displayName;
}

enum PaymentType { inAdvance, onDay }

class FixedExpense {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final double amount;
  final ExpenseFrequency frequency;
  final PaymentType paymentType;
  final int dayOfMonth; // Para gastos mensuales (1-31)
  final int dayOfWeek; // Para gastos semanales (1=lunes, 7=domingo)
  final String category;
  final String? accountId; // Cuenta asociada para el pago
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastPaymentDate;

  FixedExpense({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.amount,
    required this.frequency,
    required this.paymentType,
    required this.dayOfMonth,
    required this.dayOfWeek,
    required this.category,
    this.accountId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.lastPaymentDate,
  });

  FixedExpense copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    double? amount,
    ExpenseFrequency? frequency,
    PaymentType? paymentType,
    int? dayOfMonth,
    int? dayOfWeek,
    String? category,
    String? accountId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastPaymentDate,
  }) {
    return FixedExpense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      paymentType: paymentType ?? this.paymentType,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'amount': amount,
      'frequency': frequency.name,
      'paymentType': paymentType.name,
      'dayOfMonth': dayOfMonth,
      'dayOfWeek': dayOfWeek,
      'category': category,
      'accountId': accountId,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
    };
  }

  factory FixedExpense.fromMap(Map<String, dynamic> map) {
    return FixedExpense(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      description: map['description'],
      amount: map['amount']?.toDouble() ?? 0.0,
      frequency: ExpenseFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => ExpenseFrequency.monthly,
      ),
      paymentType: PaymentType.values.firstWhere(
        (e) => e.name == map['paymentType'],
        orElse: () => PaymentType.onDay,
      ),
      dayOfMonth: map['dayOfMonth']?.toInt() ?? 1,
      dayOfWeek: map['dayOfWeek']?.toInt() ?? 1,
      category: map['category'] ?? 'Otros',
      accountId: map['accountId'],
      isActive: map['isActive'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      lastPaymentDate: map['lastPaymentDate'] != null
          ? DateTime.parse(map['lastPaymentDate'])
          : null,
    );
  }

  // Método para obtener el ícono según la categoría
  IconData getCategoryIcon() {
    switch (category.toLowerCase()) {
      case 'deporte':
      case 'deportes':
        return Icons.sports_soccer;
      case 'transporte':
        return Icons.directions_car;
      case 'comida':
      case 'alimentación':
        return Icons.restaurant;
      case 'servicios':
        return Icons.home;
      case 'entretenimiento':
        return Icons.movie;
      case 'salud':
        return Icons.local_hospital;
      case 'educación':
        return Icons.school;
      default:
        return Icons.category;
    }
  }

  // Método para obtener el color según la categoría
  Color getCategoryColor() {
    switch (category.toLowerCase()) {
      case 'deporte':
      case 'deportes':
        return Colors.green;
      case 'transporte':
        return Colors.blue;
      case 'comida':
      case 'alimentación':
        return Colors.orange;
      case 'servicios':
        return Colors.brown;
      case 'entretenimiento':
        return Colors.purple;
      case 'salud':
        return Colors.red;
      case 'educación':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  // Método para obtener el nombre del día de la semana
  String getDayOfWeekName() {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return days[dayOfWeek - 1];
  }

  // Método para verificar si este gasto aplica para una fecha específica
  bool appliesToDate(DateTime date) {
    if (!isActive) return false;

    if (frequency == ExpenseFrequency.monthly) {
      return date.day == dayOfMonth;
    } else {
      return date.weekday == dayOfWeek;
    }
  }

  // Método para obtener la próxima fecha de aplicación
  DateTime getNextApplicationDate() {
    final now = DateTime.now();

    if (frequency == ExpenseFrequency.monthly) {
      final thisMonth = DateTime(now.year, now.month, dayOfMonth);
      if (thisMonth.isAfter(now) || thisMonth.isAtSameMomentAs(now)) {
        return thisMonth;
      } else {
        final nextMonth = DateTime(now.year, now.month + 1, dayOfMonth);
        return nextMonth;
      }
    } else {
      // Para gastos semanales, encontrar el próximo día de la semana
      int daysUntilNext = (dayOfWeek - now.weekday + 7) % 7;
      if (daysUntilNext == 0) {
        daysUntilNext = 7; // Si es el mismo día, siguiente semana
      }
      return now.add(Duration(days: daysUntilNext));
    }
  }
}
