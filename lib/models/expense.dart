enum TransactionType { expense, income, repeated }

enum RecurrenceFrequency { daily, weekly, monthly, yearly }

class Expense {
  final String id;
  final double amount;
  final String category;
  final DateTime date;
  final String? note;
  final TransactionType type;

  // Recurrence specific fields
  final RecurrenceFrequency? frequency;
  final DateTime? recurrenceStartDate;
  final DateTime? recurrenceEndDate;
  final int? recurrenceOccurrences; // Total number of times to repeat
  final TransactionType? recurrenceTargetType; // expense or income
  final DateTime? lastGeneratedDate;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    this.type = TransactionType.expense,
    this.frequency,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
    this.recurrenceOccurrences,
    this.recurrenceTargetType,
    this.lastGeneratedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'type': type.name,
      'frequency': frequency?.name,
      'recurrenceStartDate': recurrenceStartDate?.toIso8601String(),
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'recurrenceOccurrences': recurrenceOccurrences,
      'recurrenceTargetType': recurrenceTargetType?.name,
      'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      type: map['type'] != null
          ? TransactionType.values.firstWhere(
              (e) => e.name == map['type'],
              orElse: () => TransactionType.expense,
            )
          : TransactionType.expense,
      frequency: map['frequency'] != null
          ? RecurrenceFrequency.values.firstWhere(
              (e) => e.name == map['frequency'],
            )
          : null,
      recurrenceStartDate: map['recurrenceStartDate'] != null
          ? DateTime.parse(map['recurrenceStartDate'] as String)
          : null,
      recurrenceEndDate: map['recurrenceEndDate'] != null
          ? DateTime.parse(map['recurrenceEndDate'] as String)
          : null,
      recurrenceOccurrences: map['recurrenceOccurrences'] as int?,
      recurrenceTargetType: map['recurrenceTargetType'] != null
          ? TransactionType.values.firstWhere(
              (e) => e.name == map['recurrenceTargetType'],
            )
          : null,
      lastGeneratedDate: map['lastGeneratedDate'] != null
          ? DateTime.parse(map['lastGeneratedDate'] as String)
          : null,
    );
  }
}
