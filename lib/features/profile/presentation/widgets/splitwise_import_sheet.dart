import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/splitwise_csv_parser.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';

class SplitwiseImportSheet extends ConsumerStatefulWidget {
  const SplitwiseImportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SplitwiseImportSheet(),
    );
  }

  @override
  ConsumerState<SplitwiseImportSheet> createState() => _SplitwiseImportSheetState();
}

class _SplitwiseImportSheetState extends ConsumerState<SplitwiseImportSheet> {
  int _currentStep = 0; // 0: Input/Paste, 1: Preview & Map, 2: Importing
  bool _showTutorial = true;
  final TextEditingController _pasteController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController(text: 'Splitwise Group');

  SplitwiseParseResult? _parseResult;
  String? _selectedMemberAsUser;
  bool _isImporting = false;
  String _statusMessage = '';

  @override
  void dispose() {
    _pasteController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  void _loadSampleCsv() {
    const sample = '''Date,Description,Category,Cost,Currency,LK,Njj,KATTU PUCHI,keith james (removed)
2026-03-09,Fans,General,2800.00,INR,-700.00,2100.00,-700.00,-700.00
2026-03-10,Dmart,Household supplies,3800.00,INR,2850.00,-950.00,-950.00,-950.00
2026-03-11,keith j. paid Njj,Payment,110.00,INR,0.00,-110.00,0.00,110.00
2026-03-15,"Instamart(maggi,syrup,curd,banana)",Groceries,390.00,INR,-167.50,-167.50,335.00,0.00
2026-03-18,poori,Dining out,92.00,INR,46.00,-46.00,0.00,0.00
''';
    setState(() {
      _pasteController.text = sample;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sample Splitwise CSV loaded')),
    );
  }

  void _loadLocalExportCsv() {
    try {
      final file = File('.misc/export.csv');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        setState(() {
          _pasteController.text = content;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loaded export.csv (315 lines)')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('.misc/export.csv not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read export.csv: $e')),
      );
    }
  }

  void _handlePreview() {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste Splitwise CSV text first')),
      );
      return;
    }

    try {
      final result = SplitwiseCsvParser.parseSplitwiseCsv(text);
      if (result.rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions found in this CSV.')),
        );
        return;
      }

      final currentUser = ref.read(currentUserProvider);
      final currentUserName = currentUser?.displayName.toLowerCase() ?? '';

      // Auto-match current user if possible
      String defaultSelected = result.memberNames.first;
      for (final m in result.memberNames) {
        final clean = SplitwiseCsvParser.cleanMemberName(m).toLowerCase();
        if (clean == currentUserName || (currentUserName.isNotEmpty && clean.contains(currentUserName))) {
          defaultSelected = m;
          break;
        }
      }

      setState(() {
        _parseResult = result;
        _selectedMemberAsUser = defaultSelected;
        _currentStep = 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV Parsing Error: $e')),
      );
    }
  }

  Future<void> _executeImport() async {
    final result = _parseResult;
    if (result == null || _selectedMemberAsUser == null) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to import a group.')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _statusMessage = 'Creating group...';
    });

    try {
      // 1. Create the Group in FairShare
      final groupName = _groupNameController.text.trim().isNotEmpty
          ? _groupNameController.text.trim()
          : 'Splitwise Group';

      final newGroup = Group(
        id: 'cohort_${DateTime.now().millisecondsSinceEpoch}',
        name: groupName,
        description: 'Imported from Splitwise (${DateFormat('dd MMM yyyy').format(DateTime.now())})',
        category: 'house',
        currency: result.currency,
        createdBy: currentUser.id,
        inviteCode: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createdCohort = await ref.read(groupsProvider.notifier).createGroup(newGroup);

      setState(() {
        _statusMessage = 'Setting up shadow members...';
      });

      // 2. Map CSV Member Names to User IDs and generate shadow members
      final Map<String, String> memberToUserId = {};
      final List<GroupMember> shadowMembers = [];

      for (int i = 0; i < result.memberNames.length; i++) {
        final rawName = result.memberNames[i];
        final cleanName = SplitwiseCsvParser.cleanMemberName(rawName);

        if (rawName == _selectedMemberAsUser) {
          memberToUserId[rawName] = currentUser.id;
        } else {
          final shadowUserId = 'user_shadow_${DateTime.now().microsecondsSinceEpoch}_$i';
          final shadowMemberId = 'gm_shadow_${DateTime.now().microsecondsSinceEpoch}_$i';
          memberToUserId[rawName] = shadowUserId;

          shadowMembers.add(
            GroupMember(
              id: shadowMemberId,
              cohortId: createdCohort.id,
              userId: shadowUserId,
              role: 'member',
              joinedAt: DateTime.now(),
              isPlaceholder: true,
              originalCsvName: cleanName,
            ),
          );
        }
      }

      // Add shadow members to cohort roster in repository and cache
      if (shadowMembers.isNotEmpty) {
        await ref.read(groupRepositoryProvider).addMembersToCohort(
              createdCohort.id,
              shadowMembers,
            );
      }

      setState(() {
        _statusMessage = 'Importing ${result.rows.length} transactions...';
      });

      // 3. Reconstruct all transactions as FairShare Expenses
      final List<Expense> allExpenses = [];
      for (final row in result.rows) {
        final expense = SplitwiseCsvParser.toExpense(
          row: row,
          cohortId: createdCohort.id,
          memberNameToUserId: memberToUserId,
        );
        allExpenses.add(expense);
      }

      // Save expenses to local cache and repository
      final cacheService = ref.read(localCacheServiceProvider);
      await cacheService.saveExpenses(createdCohort.id, allExpenses);

      // Invalidate and reload group expenses provider
      ref.invalidate(groupExpensesProvider(createdCohort.id));
      await ref.read(groupsProvider.notifier).loadUserGroups();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${allExpenses.length} expenses into ${createdCohort.name}!',
            ),
            backgroundColor: AppColors.emerald,
          ),
        );
        context.push('/groups/${createdCohort.id}');
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top;

    return Container(
      constraints: BoxConstraints(
        maxHeight: availableHeight * 0.90,
      ),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (_currentStep == 1 && !_isImporting)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.arrow_back_rounded, color: colors.textSecondary),
                            onPressed: () => setState(() => _currentStep = 0),
                          ),
                        if (_currentStep == 1 && !_isImporting) const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            color: colors.emerald,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentStep == 0 ? 'Import Splitwise CSV' : 'Preview & Map Members',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textMain,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _currentStep == 0
                                    ? 'Migrate group history & expenses'
                                    : 'Assign your identity and review group details',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isImporting) ...[
                _buildImportingState(colors),
              ] else if (_currentStep == 0) ...[
                _buildStep0Input(colors),
              ] else ...[
                _buildStep1Preview(colors),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0Input(AppThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tutorial Accordion
        InkWell(
          onTap: () => setState(() => _showTutorial = !_showTutorial),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.screen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline_rounded, size: 16, color: colors.cyan),
                        const SizedBox(width: 8),
                        Text(
                          'How to export CSV from Splitwise',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textMain,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _showTutorial ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                if (_showTutorial) ...[
                  const SizedBox(height: 10),
                  Divider(color: colors.border, height: 1),
                  const SizedBox(height: 10),
                  _buildStep('1', 'Open Splitwise app or web → Go into your group', colors),
                  const SizedBox(height: 6),
                  _buildStep('2', 'Tap Group Settings (Gear icon) → Advanced settings', colors),
                  const SizedBox(height: 6),
                  _buildStep('3', 'Tap "Export as CSV" → Save export.csv', colors),
                  const SizedBox(height: 6),
                  _buildStep('4', 'Paste the CSV content below to import', colors),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Paste header & shortcut actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PASTE CSV CONTENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.textSecondary,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: _loadLocalExportCsv,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text('Load export.csv', style: TextStyle(fontSize: 11, color: colors.cyan)),
                ),
                TextButton(
                  onPressed: _loadSampleCsv,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text('Try Sample', style: TextStyle(fontSize: 11, color: colors.emerald)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pasteController,
          maxLines: 6,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: colors.textMain,
          ),
          decoration: InputDecoration(
            hintText: 'Paste export.csv text here...',
            hintStyle: TextStyle(
              fontSize: 12,
              color: colors.textSecondary.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: colors.screen,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.cyan, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 18),

        // Preview Button
        ElevatedButton(
          onPressed: _handlePreview,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.cyan,
            foregroundColor: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Preview Import',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Preview(AppThemeColors colors) {
    final result = _parseResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Group Name Input
        Text(
          'NEW GROUP NAME',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _groupNameController,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textMain,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.screen,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.cyan, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Stats Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.screen,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBadge(
                    '${result.rows.length}',
                    'Expenses',
                    Icons.receipt_long_rounded,
                    colors.cyan,
                  ),
                  _buildStatBadge(
                    '${result.memberNames.length}',
                    'Members',
                    Icons.people_alt_rounded,
                    colors.emerald,
                  ),
                  _buildStatBadge(
                    result.currency,
                    'Currency',
                    Icons.payments_rounded,
                    colors.textMain,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Ledger Volume',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  Text(
                    CurrencyFormatter.format(result.totalCost),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colors.emerald,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Member Identity Mapping
        Text(
          'WHICH MEMBER IN THIS CSV ARE YOU?',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select your name so FairShare attributes your payments and splits to your account:',
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
        const SizedBox(height: 10),

        Material(
          color: colors.screen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: result.memberNames.length,
            separatorBuilder: (_, _) => Divider(color: colors.border, height: 1),
            itemBuilder: (context, index) {
              final rawName = result.memberNames[index];
              final cleanName = SplitwiseCsvParser.cleanMemberName(rawName);
              final isSelected = _selectedMemberAsUser == rawName;

              return InkWell(
                onTap: () => setState(() => _selectedMemberAsUser = rawName),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? colors.cyan : colors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cleanName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? colors.textMain : colors.textSecondary,
                              ),
                            ),
                            if (rawName != cleanName)
                              Text(
                                rawName,
                                style: TextStyle(fontSize: 11, color: colors.textSecondary.withValues(alpha: 0.6)),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.cyan.withValues(alpha: 0.15)
                              : colors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isSelected ? 'You (Admin)' : 'Shadow Member',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? colors.cyan : colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Confirm CTA
        ElevatedButton(
          onPressed: _executeImport,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.emerald,
            foregroundColor: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            'Create Group & Import (${result.rows.length} Expenses)',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportingState(AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colors.emerald),
          ),
          const SizedBox(height: 20),
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Building group ledger and calculating penny-exact balances...',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String title, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text, AppThemeColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.cyan.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: colors.cyan,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
