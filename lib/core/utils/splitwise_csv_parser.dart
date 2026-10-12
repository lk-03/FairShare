import '../models/expense.dart';
import '../models/expense_payer.dart';
import '../models/split.dart';

/// Represents a single parsed row from a Splitwise group CSV export.
class SplitwiseParsedRow {
  final DateTime date;
  final String description;
  final String rawCategory;
  final String category;
  final double cost;
  final String currency;
  final bool isPayment;
  final Map<String, double> rawNetBalances; // member name -> net impact
  final Map<String, double> shares; // member name -> share amount
  final Map<String, double> payments; // member name -> paid amount
  final String primaryPayerName;

  const SplitwiseParsedRow({
    required this.date,
    required this.description,
    required this.rawCategory,
    required this.category,
    required this.cost,
    required this.currency,
    required this.isPayment,
    required this.rawNetBalances,
    required this.shares,
    required this.payments,
    required this.primaryPayerName,
  });
}

/// Represents the overall parsed result from a Splitwise CSV export.
class SplitwiseParseResult {
  final List<String> memberNames;
  final String currency;
  final List<SplitwiseParsedRow> rows;
  final int totalExpensesCount;
  final int totalPaymentsCount;
  final double totalCost;

  const SplitwiseParseResult({
    required this.memberNames,
    required this.currency,
    required this.rows,
    required this.totalExpensesCount,
    required this.totalPaymentsCount,
    required this.totalCost,
  });
}

/// RFC 4180-compliant CSV parser and Splitwise ledger reconstructor.
class SplitwiseCsvParser {
  /// Tokenizes CSV text into rows of string columns, respecting quotes and line breaks.
  static List<List<String>> parseCsv(String csvText) {
    final List<List<String>> result = [];
    final StringBuffer currentCell = StringBuffer();
    final List<String> currentRow = [];
    bool inQuotes = false;

    final runes = csvText.runes.toList();
    for (int i = 0; i < runes.length; i++) {
      final char = String.fromCharCode(runes[i]);

      if (inQuotes) {
        if (char == '"') {
          // Check for escaped quote ("")
          if (i + 1 < runes.length && String.fromCharCode(runes[i + 1]) == '"') {
            currentCell.write('"');
            i++; // skip next quote
          } else {
            inQuotes = false;
          }
        } else {
          currentCell.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
        } else if (char == '\n' || char == '\r') {
          // Handle CRLF or standalone LF/CR
          if (char == '\r' && i + 1 < runes.length && String.fromCharCode(runes[i + 1]) == '\n') {
            i++;
          }
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            result.add(List<String>.from(currentRow));
          }
          currentRow.clear();
        } else {
          currentCell.write(char);
        }
      }
    }

    // Flush any remaining cell/row
    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString().trim());
      if (currentRow.any((c) => c.isNotEmpty)) {
        result.add(List<String>.from(currentRow));
      }
    }

    return result;
  }

  /// Cleans member name by stripping suffixes like "(removed)" and extra spaces.
  static String cleanMemberName(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'\(removed\)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : raw.trim();
  }

  /// Maps Splitwise category strings into FairShare's built-in categories.
  static String mapCategory(String rawCategory, String description) {
    final c = rawCategory.toLowerCase();
    final d = description.toLowerCase();

    if (c == 'payment' || d.contains('paid') || d.contains('settled up')) {
      return 'custom';
    }
    if (c.contains('dining') ||
        c.contains('food') ||
        c.contains('restaurant') ||
        d.contains('lunch') ||
        d.contains('dinner') ||
        d.contains('biriyani') ||
        d.contains('burger') ||
        d.contains('shawarma')) {
      return 'dining';
    }
    if (c.contains('grocer') ||
        c.contains('household') ||
        c.contains('home') ||
        c.contains('furniture') ||
        d.contains('blinkit') ||
        d.contains('instamart') ||
        d.contains('dmart') ||
        d.contains('egg') ||
        d.contains('milk') ||
        d.contains('chicken') ||
        d.contains('bread')) {
      return 'house';
    }
    if (c.contains('water') || c.contains('utilit') || c.contains('electricity') || c.contains('eb')) {
      return 'utilities';
    }
    if (c.contains('gas') || c.contains('fuel') || c.contains('car') || c.contains('transport') || c.contains('taxi') || c.contains('auto') || c.contains('uber') || d.contains('petrol')) {
      return 'transport';
    }
    if (c.contains('trip') || c.contains('hotel') || c.contains('travel') || c.contains('flight')) {
      return 'trip';
    }
    if (c.contains('gift') || c.contains('entertainment') || c.contains('movie') || c.contains('party') || c.contains('event')) {
      return 'event';
    }

    return 'custom';
  }

  /// Parses and reconstructs Splitwise group transactions from CSV text.
  static SplitwiseParseResult parseSplitwiseCsv(String csvText) {
    final rawRows = parseCsv(csvText);
    if (rawRows.isEmpty) {
      throw const FormatException('CSV file is empty.');
    }

    // 1. Identify Header Row: must contain Date, Description, Cost, Currency
    int headerIndex = -1;
    for (int i = 0; i < rawRows.length; i++) {
      final row = rawRows[i].map((c) => c.toLowerCase()).toList();
      if (row.contains('date') && row.contains('description') && row.contains('cost') && row.contains('currency')) {
        headerIndex = i;
        break;
      }
    }

    if (headerIndex == -1) {
      throw const FormatException(
        'Invalid Splitwise CSV header: Missing required columns (Date, Description, Cost, Currency).',
      );
    }

    final header = rawRows[headerIndex];
    final dateCol = header.indexWhere((c) => c.toLowerCase() == 'date');
    final descCol = header.indexWhere((c) => c.toLowerCase() == 'description');
    final catCol = header.indexWhere((c) => c.toLowerCase() == 'category');
    final costCol = header.indexWhere((c) => c.toLowerCase() == 'cost');
    final currCol = header.indexWhere((c) => c.toLowerCase() == 'currency');

    // Member columns are all columns after the first 5 standard columns (or any column after currency)
    final int firstMemberCol = [dateCol, descCol, catCol, costCol, currCol]
            .reduce((max, e) => e > max ? e : max) +
        1;

    if (firstMemberCol >= header.length) {
      throw const FormatException('No group members found in CSV header columns.');
    }

    final List<String> rawMemberNames = [];
    for (int i = firstMemberCol; i < header.length; i++) {
      final colName = header[i].trim();
      if (colName.isNotEmpty) {
        rawMemberNames.add(colName);
      }
    }

    if (rawMemberNames.isEmpty) {
      throw const FormatException('Could not identify any member columns in CSV header.');
    }

    final List<SplitwiseParsedRow> parsedRows = [];
    String detectedCurrency = 'INR';
    int expensesCount = 0;
    int paymentsCount = 0;
    double totalCostSum = 0.0;

    // 2. Parse data rows
    for (int r = headerIndex + 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      if (row.isEmpty || row.every((c) => c.isEmpty)) continue;

      final dateStr = dateCol < row.length ? row[dateCol].trim() : '';
      final desc = descCol < row.length ? row[descCol].trim() : '';
      final rawCat = (catCol != -1 && catCol < row.length) ? row[catCol].trim() : 'General';
      final costStr = costCol < row.length ? row[costCol].replaceAll(',', '').trim() : '0';
      final curr = currCol < row.length ? row[currCol].trim() : 'INR';

      if (dateStr.isEmpty || desc.isEmpty) continue;

      final date = DateTime.tryParse(dateStr) ?? DateTime.now();
      final cost = double.tryParse(costStr) ?? 0.0;
      if (curr.isNotEmpty) detectedCurrency = curr;

      // Read member net balance impacts
      final Map<String, double> netBalances = {};
      for (int m = 0; m < rawMemberNames.length; m++) {
        final colIdx = firstMemberCol + m;
        final valStr = colIdx < row.length ? row[colIdx].replaceAll(',', '').trim() : '0';
        final val = double.tryParse(valStr) ?? 0.0;
        netBalances[rawMemberNames[m]] = val;
      }

      final isPayment = rawCat.toLowerCase() == 'payment' ||
          desc.toLowerCase().contains('settled up') ||
          desc.toLowerCase().contains(' paid ');

      if (isPayment) {
        paymentsCount++;
      } else {
        expensesCount++;
      }
      totalCostSum += cost;

      // 3. Reconstruct shares and payments from net balance impacts
      // N_i = paid_i - share_i
      final Map<String, double> shares = {};
      final Map<String, double> payments = {};

      final positives = netBalances.entries.where((e) => e.value > 0.001).toList();
      final negatives = netBalances.entries.where((e) => e.value < -0.001).toList();

      if (positives.length == 1) {
        // Standard single payer
        final payerName = positives.first.key;

        // Payer paid full cost
        payments[payerName] = cost;

        // Everyone with negative balance owes their negative amount
        double assignedSharesSum = 0.0;
        for (final neg in negatives) {
          final share = -neg.value;
          shares[neg.key] = share;
          assignedSharesSum += share;
        }

        // Payer's own share is remaining cost
        final payerShare = (cost - assignedSharesSum).clamp(0.0, cost);
        if (payerShare > 0.001) {
          shares[payerName] = payerShare;
        }
      } else if (positives.isNotEmpty) {
        // Multi-payer scenario
        // Members with negative balance paid 0 and owe their negative amount
        double borrowerTotal = 0.0;
        for (final neg in negatives) {
          final share = -neg.value;
          shares[neg.key] = share;
          borrowerTotal += share;
        }

        final remainderToShare = (cost - borrowerTotal).clamp(0.0, cost);

        for (final pos in positives) {
          // If positive lenders also consumed a share
          final lenderShare = positives.isNotEmpty ? remainderToShare / positives.length : 0.0;
          if (lenderShare > 0.001) {
            shares[pos.key] = lenderShare;
          }
          payments[pos.key] = pos.value + lenderShare;
        }
      } else {
        // Fallback: equal split among members if net impacts are zeroed
        final perPerson = rawMemberNames.isNotEmpty ? cost / rawMemberNames.length : 0.0;
        for (final m in rawMemberNames) {
          shares[m] = perPerson;
        }
        if (rawMemberNames.isNotEmpty) {
          payments[rawMemberNames.first] = cost;
        }
      }

      // Determine primary payer
      String primaryPayer = rawMemberNames.first;
      if (payments.isNotEmpty) {
        primaryPayer = payments.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      }

      final mappedCategory = mapCategory(rawCat, desc);

      parsedRows.add(
        SplitwiseParsedRow(
          date: date,
          description: desc,
          rawCategory: rawCat,
          category: mappedCategory,
          cost: cost,
          currency: detectedCurrency,
          isPayment: isPayment,
          rawNetBalances: netBalances,
          shares: shares,
          payments: payments,
          primaryPayerName: primaryPayer,
        ),
      );
    }

    return SplitwiseParseResult(
      memberNames: rawMemberNames,
      currency: detectedCurrency,
      rows: parsedRows,
      totalExpensesCount: expensesCount,
      totalPaymentsCount: paymentsCount,
      totalCost: totalCostSum,
    );
  }

  /// Converts a [SplitwiseParsedRow] into a canonical FairShare [Expense].
  static Expense toExpense({
    required SplitwiseParsedRow row,
    required String cohortId,
    required Map<String, String> memberNameToUserId,
  }) {
    final primaryPayerId = memberNameToUserId[row.primaryPayerName] ?? '';

    // Reconstruct ExpensePayers
    final List<ExpensePayer> payers = [];
    for (final entry in row.payments.entries) {
      final uid = memberNameToUserId[entry.key];
      if (uid != null && entry.value > 0.001) {
        payers.add(ExpensePayer(userId: uid, amount: entry.value));
      }
    }

    // Reconstruct ExpenseSplits
    final List<ExpenseSplit> splits = [];
    for (final entry in row.shares.entries) {
      final uid = memberNameToUserId[entry.key];
      if (uid != null && entry.value > 0.001) {
        splits.add(ExpenseSplit(userId: uid, amount: entry.value));
      }
    }

    return Expense(
      id: 'exp_sw_${DateTime.now().microsecondsSinceEpoch}_${row.date.millisecondsSinceEpoch}',
      cohortId: cohortId,
      title: row.description,
      category: row.category,
      totalAmount: row.cost,
      currency: row.currency,
      paidByUserId: primaryPayerId,
      payers: payers.isNotEmpty ? payers : [ExpensePayer(userId: primaryPayerId, amount: row.cost)],
      splitType: SplitType.exact,
      splits: splits,
      createdAt: row.date,
      updatedAt: row.date,
      paidByName: cleanMemberName(row.primaryPayerName),
      notes: 'Imported from Splitwise (${row.rawCategory})',
    );
  }
}
