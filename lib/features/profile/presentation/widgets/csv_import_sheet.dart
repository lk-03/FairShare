import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/splitwise_csv_parser.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';

/// Production-ready CSV Import sheet for migrating Splitwise and group ledger history.
/// Supports:
/// 1. Direct Share (from OS share sheet via Splitwise "Export as CSV")
/// 2. Device File Browser (`FilePicker.pickFiles`)
/// 3. Ingestion into a New Group OR an Existing Group
class CsvImportSheet extends ConsumerStatefulWidget {
  final Group? targetGroup;
  final String? initialCsvText;

  const CsvImportSheet({
    super.key,
    this.targetGroup,
    this.initialCsvText,
  });

  static Future<void> show(
    BuildContext context, {
    Group? targetGroup,
    String? initialCsvText,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CsvImportSheet(
        targetGroup: targetGroup,
        initialCsvText: initialCsvText,
      ),
    );
  }

  @override
  ConsumerState<CsvImportSheet> createState() => _CsvImportSheetState();
}

class _CsvImportSheetState extends ConsumerState<CsvImportSheet> {
  int _currentStep = 0; // 0: Input, 1: Preview & Map, 2: Importing
  bool _showTutorial = false;
  bool _showPasteBox = false;

  late bool _isExistingGroupMode;
  Group? _selectedExistingGroup;

  final TextEditingController _pasteController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController(text: 'Splitwise Group');

  SplitwiseParseResult? _parseResult;
  String? _selectedMemberAsUser; // For New Group mode
  final Map<String, String> _csvMemberToUserId = {}; // For Existing Group mode: CSV raw name -> userId or '__SHADOW__'

  bool _isImporting = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _isExistingGroupMode = widget.targetGroup != null;
    _selectedExistingGroup = widget.targetGroup;

    if (widget.initialCsvText != null && widget.initialCsvText!.trim().isNotEmpty) {
      _pasteController.text = widget.initialCsvText!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePreview();
      });
    }
  }

  @override
  void dispose() {
    _pasteController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _pickCsvFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes);

      if (content.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected CSV file is empty')),
          );
        }
        return;
      }

      _pasteController.text = content;
      final fileName = file.name.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
      if (fileName.isNotEmpty && fileName.toLowerCase() != 'export') {
        _groupNameController.text = fileName;
      }

      _handlePreview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  Future<void> _launchSplitwiseApp() async {
    final uri = Uri.parse('splitwise://');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    final webUri = Uri.parse('https://secure.splitwise.com');
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  void _handlePreview() {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or paste CSV text first')),
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

      // Auto-match current user
      String defaultSelected = result.memberNames.first;
      for (final m in result.memberNames) {
        final clean = SplitwiseCsvParser.cleanMemberName(m).toLowerCase();
        if (clean == currentUserName || (currentUserName.isNotEmpty && clean.contains(currentUserName))) {
          defaultSelected = m;
          break;
        }
      }

      // Initialize mapping for existing group if mode is active
      _csvMemberToUserId.clear();
      final target = _selectedExistingGroup;
      if (target != null) {
        final existingMembers = ref.read(groupMembersProvider(target.id));
        for (final rawName in result.memberNames) {
          final clean = SplitwiseCsvParser.cleanMemberName(rawName).toLowerCase();
          String matchedUserId = '__SHADOW__';

          for (final em in existingMembers) {
            final emName = em.displayName.toLowerCase();
            if (emName.isNotEmpty && (emName == clean || emName.contains(clean) || clean.contains(emName))) {
              matchedUserId = em.userId;
              break;
            }
            if (em.userId == currentUser?.id && clean == currentUserName) {
              matchedUserId = em.userId;
              break;
            }
          }
          _csvMemberToUserId[rawName] = matchedUserId;
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
    if (result == null) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to import transactions.')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _statusMessage = _isExistingGroupMode ? 'Configuring existing group...' : 'Creating new group...';
    });

    try {
      if (!_isExistingGroupMode) {
        // --- MODE A: CREATE NEW GROUP ---
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
          _statusMessage = 'Setting up group members...';
        });

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

        if (shadowMembers.isNotEmpty) {
          await ref.read(groupRepositoryProvider).addMembersToCohort(
                createdCohort.id,
                shadowMembers,
              );
        }

        setState(() {
          _statusMessage = 'Importing ${result.rows.length} transactions...';
        });

        final List<Expense> allExpenses = [];
        for (final row in result.rows) {
          final expense = SplitwiseCsvParser.toExpense(
            row: row,
            cohortId: createdCohort.id,
            memberNameToUserId: memberToUserId,
          );
          allExpenses.add(expense);
        }

        final cacheService = ref.read(localCacheServiceProvider);
        await cacheService.saveExpenses(createdCohort.id, allExpenses);

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
      } else {
        // --- MODE B: IMPORT INTO EXISTING GROUP ---
        final targetGroup = _selectedExistingGroup;
        if (targetGroup == null) {
          throw Exception('Please select an existing group destination');
        }

        setState(() {
          _statusMessage = 'Reconciling group members...';
        });

        final Map<String, String> memberToUserId = {};
        final List<GroupMember> newShadowMembers = [];

        for (int i = 0; i < result.memberNames.length; i++) {
          final rawName = result.memberNames[i];
          final cleanName = SplitwiseCsvParser.cleanMemberName(rawName);
          final mappedUserId = _csvMemberToUserId[rawName] ?? '__SHADOW__';

          if (mappedUserId != '__SHADOW__') {
            memberToUserId[rawName] = mappedUserId;
          } else {
            final shadowUserId = 'user_shadow_${DateTime.now().microsecondsSinceEpoch}_$i';
            final shadowMemberId = 'gm_shadow_${DateTime.now().microsecondsSinceEpoch}_$i';
            memberToUserId[rawName] = shadowUserId;

            newShadowMembers.add(
              GroupMember(
                id: shadowMemberId,
                cohortId: targetGroup.id,
                userId: shadowUserId,
                role: 'member',
                joinedAt: DateTime.now(),
                isPlaceholder: true,
                originalCsvName: cleanName,
              ),
            );
          }
        }

        if (newShadowMembers.isNotEmpty) {
          await ref.read(groupRepositoryProvider).addMembersToCohort(
                targetGroup.id,
                newShadowMembers,
              );
        }

        setState(() {
          _statusMessage = 'Importing ${result.rows.length} transactions into ${targetGroup.name}...';
        });

        final List<Expense> importedExpenses = [];
        for (final row in result.rows) {
          final expense = SplitwiseCsvParser.toExpense(
            row: row,
            cohortId: targetGroup.id,
            memberNameToUserId: memberToUserId,
          );
          importedExpenses.add(expense);
        }

        // Merge with existing cached expenses
        final cacheService = ref.read(localCacheServiceProvider);
        final existingExpenses = cacheService.getCachedExpenses(targetGroup.id);
        final combinedExpenses = [...existingExpenses, ...importedExpenses];
        await cacheService.saveExpenses(targetGroup.id, combinedExpenses);

        ref.invalidate(groupExpensesProvider(targetGroup.id));
        ref.invalidate(groupMembersProvider(targetGroup.id));
        await ref.read(groupsProvider.notifier).loadUserGroups();

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully added ${importedExpenses.length} transactions to ${targetGroup.name}!',
              ),
              backgroundColor: AppColors.emerald,
            ),
          );
          context.push('/groups/${targetGroup.id}');
        }
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
        maxHeight: availableHeight * 0.92,
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
                                _currentStep == 0 ? 'Import CSV' : 'Preview & Map Members',
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
                                    ? (_isExistingGroupMode
                                        ? 'Import into ${_selectedExistingGroup?.name ?? 'group'}'
                                        : 'Migrate group history & expenses')
                                    : 'Assign identities & review details',
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
    final groupsAsync = ref.watch(groupsProvider);
    final userGroups = groupsAsync.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode Selector: New Group vs Existing Group (if not pre-locked)
        if (widget.targetGroup == null) ...[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.screen,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isExistingGroupMode = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_isExistingGroupMode ? colors.cyan.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'New Group',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: !_isExistingGroupMode ? colors.cyan : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isExistingGroupMode = true;
                        if (_selectedExistingGroup == null && userGroups.isNotEmpty) {
                          _selectedExistingGroup = userGroups.first;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isExistingGroupMode ? colors.cyan.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Existing Group',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _isExistingGroupMode ? colors.cyan : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // If Existing Group Mode: Group Dropdown Selector
          if (_isExistingGroupMode) ...[
            Text(
              'SELECT TARGET GROUP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            if (userGroups.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.screen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'No groups found. Please switch to "New Group".',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colors.screen,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Group>(
                    value: _selectedExistingGroup ?? userGroups.first,
                    isExpanded: true,
                    dropdownColor: colors.surface,
                    items: userGroups.map((g) {
                      return DropdownMenuItem<Group>(
                        value: g,
                        child: Row(
                          children: [
                            UserAvatar(
                              avatarUrl: g.avatarUrl,
                              name: g.name,
                              radius: 12,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                g.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (newG) {
                      setState(() => _selectedExistingGroup = newG);
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ] else ...[
          // Pre-locked target group banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.screen,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                UserAvatar(
                  avatarUrl: widget.targetGroup!.avatarUrl,
                  name: widget.targetGroup!.name,
                  radius: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Group',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors.cyan),
                      ),
                      Text(
                        widget.targetGroup!.name,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.textMain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Hero Card: Direct File Browser (Production Primary)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.screen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.cyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.folder_open_rounded, size: 28, color: colors.cyan),
              ),
              const SizedBox(height: 14),
              Text(
                'Browse & Import CSV File',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select any .csv file exported from Splitwise, Drive, or downloads',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickCsvFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.cyan,
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text(
                    'Browse CSV File',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Splitwise Quick Launcher Shortcut
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.screen,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.share_rounded, size: 18, color: colors.emerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zero-Download Tip',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colors.textMain),
                    ),
                    Text(
                      'Export CSV in Splitwise → tap "FairShare" in share menu!',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _launchSplitwiseApp,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: colors.emerald,
                ),
                child: const Text('Open App', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tutorial Accordion
        InkWell(
          onTap: () => setState(() => _showTutorial = !_showTutorial),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.screen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
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
                  _buildStep('1', 'Open Splitwise → Tap into your group', colors),
                  const SizedBox(height: 6),
                  _buildStep('2', 'Tap Group Settings (Gear icon) → Advanced settings', colors),
                  const SizedBox(height: 6),
                  _buildStep('3', 'Tap "Export as CSV"', colors),
                  const SizedBox(height: 6),
                  _buildStep('4', 'Share directly to FairShare or save file and browse above', colors),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Paste CSV text fallback accordion
        InkWell(
          onTap: () => setState(() => _showPasteBox = !_showPasteBox),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.screen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.content_paste_rounded, size: 16, color: colors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Or paste CSV text directly',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textMain,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _showPasteBox ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                if (_showPasteBox) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pasteController,
                    maxLines: 5,
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
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.cyan, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _handlePreview,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.cyan),
                        foregroundColor: colors.cyan,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Preview Pasted CSV', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Preview(AppThemeColors colors) {
    final result = _parseResult!;
    final targetGroup = _selectedExistingGroup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode & Destination Indicator Card
        if (!_isExistingGroupMode) ...[
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
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.screen,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                UserAvatar(
                  avatarUrl: targetGroup?.avatarUrl,
                  name: targetGroup?.name ?? 'Group',
                  radius: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Importing into Existing Group',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors.cyan),
                      ),
                      Text(
                        targetGroup?.name ?? 'Group',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.textMain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

        // Member Identity Mapping Section
        if (!_isExistingGroupMode) ...[
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
        ] else ...[
          // Mapping for Existing Group Mode
          Text(
            'MAP CSV MEMBERS TO GROUP ROSTER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Match each person from Splitwise to an existing member or create a new shadow member:',
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          const SizedBox(height: 10),

          Builder(builder: (context) {
            final existingMembers = targetGroup != null ? ref.watch(groupMembersProvider(targetGroup.id)) : <GroupMember>[];
            final currentUser = ref.read(currentUserProvider);

            return Material(
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
                  final currentMappedUserId = _csvMemberToUserId[rawName] ?? '__SHADOW__';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cleanName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'From CSV',
                                style: TextStyle(fontSize: 10, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: colors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: currentMappedUserId,
                                isExpanded: true,
                                dropdownColor: colors.surface,
                                style: TextStyle(fontSize: 12, color: colors.textMain),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: '__SHADOW__',
                                    child: Text(
                                      '+ New Shadow Member',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: colors.cyan,
                                      ),
                                    ),
                                  ),
                                  ...existingMembers.map((em) {
                                    final displayName = em.userId == currentUser?.id
                                        ? '${currentUser?.displayName ?? 'You'} (You)'
                                        : em.displayName;
                                    return DropdownMenuItem<String>(
                                      value: em.userId,
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textMain,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (newVal) {
                                  if (newVal != null) {
                                    setState(() {
                                      _csvMemberToUserId[rawName] = newVal;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
        ],
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
            !_isExistingGroupMode
                ? 'Create Group & Import (${result.rows.length} Expenses)'
                : 'Import History into ${targetGroup?.name ?? 'Group'} (${result.rows.length} Expenses)',
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
            'Reconstructing penny-exact ledger and member allocations...',
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

/// Backwards-compatible alias for existing imports.
typedef SplitwiseImportSheet = CsvImportSheet;
