import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/splitwise_csv_parser.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';

/// Production-ready CSV Import sheet for migrating Splitwise ledger history into existing cloud groups.
/// Rules:
/// 1. Only import into existing cloud groups (local groups not supported).
/// 2. Target group must have at least as many members as active CSV members (pending balances != 0).
/// 3. Active members must be mapped to distinct group members.
/// 4. Settled members (0 pending balance) can be mapped or kept as shadow members.
/// 5. Batch-inserts directly into Supabase database tables (public.expenses & public.expense_splits).
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

  Group? _selectedExistingGroup;

  final TextEditingController _pasteController = TextEditingController();

  SplitwiseParseResult? _parseResult;
  final Map<String, String> _csvMemberToUserId = {}; // CSV raw name -> userId or '__SHADOW__'

  bool _isImporting = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
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

    final target = _selectedExistingGroup;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target cloud group first.')),
      );
      return;
    }

    if (target.isLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV Import is only available for cloud groups.')),
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

      // Check group member capacity against active CSV members
      var targetMembers = ref.read(groupMembersProvider(target.id));
      if (targetMembers.isEmpty && target.members.isNotEmpty) {
        targetMembers = target.members;
      }

      final activeMemberNames = result.activeMemberNames;
      if (targetMembers.length < activeMemberNames.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot Import: CSV has ${activeMemberNames.length} active members with pending balances (${activeMemberNames.join(", ")}), but "${target.name}" only has ${targetMembers.length} member(s). Please add at least ${activeMemberNames.length - targetMembers.length} more member(s) to this group before importing.',
            ),
            backgroundColor: AppColors.rose,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      final currentUser = ref.read(currentUserProvider);
      final currentUserName = currentUser?.displayName.toLowerCase() ?? '';

      // Initialize mapping for existing group
      _csvMemberToUserId.clear();
      final Set<String> assignedUserIds = {};

      // 1. Pass: map active members with smart auto-match to distinct group members
      for (final rawName in result.activeMemberNames) {
        final clean = SplitwiseCsvParser.cleanMemberName(rawName).toLowerCase();
        String matchedUserId = '';

        for (final em in targetMembers) {
          if (assignedUserIds.contains(em.userId)) continue;
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

        // If no match yet, pick first unassigned member
        if (matchedUserId.isEmpty) {
          for (final em in targetMembers) {
            if (!assignedUserIds.contains(em.userId)) {
              matchedUserId = em.userId;
              break;
            }
          }
        }

        if (matchedUserId.isNotEmpty) {
          assignedUserIds.add(matchedUserId);
          _csvMemberToUserId[rawName] = matchedUserId;
        }
      }

      // 2. Pass: map settled members (0 pending split) - can map to remaining or stay shadow
      for (final rawName in result.settledMemberNames) {
        final clean = SplitwiseCsvParser.cleanMemberName(rawName).toLowerCase();
        String matchedUserId = '__SHADOW__';

        for (final em in targetMembers) {
          if (assignedUserIds.contains(em.userId)) continue;
          final emName = em.displayName.toLowerCase();
          if (emName.isNotEmpty && (emName == clean || emName.contains(clean) || clean.contains(emName))) {
            matchedUserId = em.userId;
            assignedUserIds.add(matchedUserId);
            break;
          }
        }
        _csvMemberToUserId[rawName] = matchedUserId;
      }

      setState(() {
        _parseResult = result;
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
    final targetGroup = _selectedExistingGroup;
    if (result == null || targetGroup == null) return;

    if (targetGroup.isLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV Import is only available for cloud groups.')),
      );
      return;
    }

    // Validate that all active members are mapped to real members
    for (final activeName in result.activeMemberNames) {
      final mapped = _csvMemberToUserId[activeName];
      if (mapped == null || mapped == '__SHADOW__') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please map active member "$activeName" to a group member.'),
            backgroundColor: AppColors.rose,
          ),
        );
        return;
      }
    }

    // Validate that all mapped active members are mapped to distinct user IDs
    final mappedActiveUserIds = result.activeMemberNames.map((n) => _csvMemberToUserId[n]!).toSet();
    if (mappedActiveUserIds.length < result.activeMemberNames.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Each active member must be mapped to a distinct group member.'),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _statusMessage = 'Reconciling group members...';
    });

    try {
      final Map<String, String> memberToUserId = {};
      final List<GroupMember> newShadowMembers = [];

      for (int i = 0; i < result.memberNames.length; i++) {
        final rawName = result.memberNames[i];
        final cleanName = SplitwiseCsvParser.cleanMemberName(rawName);
        final mappedUserId = _csvMemberToUserId[rawName] ?? '__SHADOW__';

        if (mappedUserId != '__SHADOW__') {
          memberToUserId[rawName] = mappedUserId;
        } else {
          final shadowUserId = const Uuid().v4();
          final shadowMemberId = const Uuid().v4();
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
              profile: UserProfile(
                id: shadowUserId,
                fullName: cleanName,
                createdAt: DateTime.now(),
              ),
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
        _statusMessage = 'Importing ${result.rows.length} transactions into database...';
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

      // Batch insert directly into Supabase database (public.expenses and public.expense_splits)
      final expenseRepo = ref.read(expenseRepositoryProvider);
      await expenseRepo.batchCreateExpenses(targetGroup.id, importedExpenses);

      // Invalidate and refresh group state
      ref.invalidate(groupExpensesProvider(targetGroup.id));
      ref.invalidate(groupMembersProvider(targetGroup.id));
      ref.invalidate(groupMemberBalancesProvider(targetGroup.id));
      await ref.read(groupExpensesProvider(targetGroup.id).notifier).loadExpenses();
      await ref.read(groupsProvider.notifier).loadUserGroups();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${importedExpenses.length} transactions into ${targetGroup.name}!',
            ),
            backgroundColor: AppColors.emerald,
          ),
        );
        context.push('/groups/${targetGroup.id}');
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.cloud_upload_rounded, color: colors.cyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Splitwise CSV',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: colors.textMain,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Migrate full expense history into an existing cloud group',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
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
    final cloudGroups = userGroups.where((g) => !g.isLocal).toList();

    // If targetGroup was pre-passed and is local, warn immediately
    if (widget.targetGroup != null && widget.targetGroup!.isLocal) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.rose, size: 36),
            const SizedBox(height: 12),
            Text(
              'Cloud Groups Only',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.textMain),
            ),
            const SizedBox(height: 6),
            Text(
              'Splitwise CSV history can only be imported into cloud-synchronized groups. "${widget.targetGroup!.name}" is a local Quick Group.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Auto-select first cloud group if none selected
    if (_selectedExistingGroup == null && cloudGroups.isNotEmpty) {
      _selectedExistingGroup = cloudGroups.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Target Cloud Group Selector / Indicator
        Text(
          'TARGET CLOUD GROUP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        if (widget.targetGroup != null) ...[
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
                  avatarUrl: widget.targetGroup?.avatarUrl,
                  name: widget.targetGroup?.name ?? 'Group',
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
                        widget.targetGroup?.name ?? 'Group',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.textMain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.lock_outline_rounded, size: 16, color: colors.textSecondary),
              ],
            ),
          ),
        ] else if (cloudGroups.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.screen,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'No cloud groups found. Please create or join a cloud group before importing Splitwise CSV history.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: colors.screen,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Group>(
                value: _selectedExistingGroup ?? cloudGroups.first,
                isExpanded: true,
                dropdownColor: colors.surface,
                items: cloudGroups.map((g) {
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
                onChanged: (newGroup) {
                  if (newGroup != null) {
                    setState(() {
                      _selectedExistingGroup = newGroup;
                    });
                  }
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),

        // File Browser Card
        Material(
          color: colors.screen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.cyan.withValues(alpha: 0.4), width: 1.5),
          ),
          child: InkWell(
            onTap: _pickCsvFile,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.cyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.file_upload_outlined, color: colors.cyan, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Browse & Import CSV File',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a Splitwise CSV export from device storage',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Direct Share / Tutorial Card
        Container(
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
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: AppColors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'How to export from Splitwise',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colors.textMain,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showTutorial = !_showTutorial),
                    child: Text(
                      _showTutorial ? 'Hide' : 'Show Guide',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.cyan,
                      ),
                    ),
                  ),
                ],
              ),
              if (_showTutorial) ...[
                const SizedBox(height: 10),
                Text(
                  '1. Open Splitwise and go to your group.\n'
                  '2. Tap the settings gear icon in top-right.\n'
                  '3. Scroll down and tap "Export as CSV".\n'
                  '4. Save the file or share it with FairShare.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: colors.textSecondary),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _launchSplitwiseApp,
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Open Splitwise App', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.cyan,
                    side: BorderSide(color: colors.cyan.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Paste CSV Text Accordion
        Container(
          decoration: BoxDecoration(
            color: colors.screen,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _showPasteBox = !_showPasteBox),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.content_paste_rounded, size: 16, color: colors.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        'Or paste CSV text directly',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textMain,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _showPasteBox ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showPasteBox) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _pasteController,
                        maxLines: 6,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: colors.textMain,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Date,Description,Category,Cost,Currency,User1,User2...',
                          hintStyle: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: colors.textSecondary.withValues(alpha: 0.6),
                          ),
                          filled: true,
                          fillColor: colors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _handlePreview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.cyan,
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Preview Pasted CSV', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
                    Row(
                      children: [
                        Icon(Icons.cloud_done_rounded, size: 12, color: colors.cyan),
                        const SizedBox(width: 4),
                        Text(
                          'Importing into Cloud Group',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors.cyan),
                        ),
                      ],
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
                    '${result.activeMemberNames.length}',
                    'Active Members',
                    Icons.people_alt_rounded,
                    AppColors.amber,
                  ),
                  _buildStatBadge(
                    '${result.settledMemberNames.length}',
                    'Settled',
                    Icons.done_all_rounded,
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
          'Active members must be mapped to distinct group members. Settled members (₹0 balance) can be mapped or kept as shadows:',
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
        const SizedBox(height: 10),

        Builder(builder: (context) {
          var existingMembers = targetGroup != null ? ref.watch(groupMembersProvider(targetGroup.id)) : <GroupMember>[];
          if (existingMembers.isEmpty && targetGroup != null && targetGroup.members.isNotEmpty) {
            existingMembers = targetGroup.members;
          }
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
                final isActive = result.activeMemberNames.contains(rawName);
                final net = result.cumulativeNetBalances[rawName] ?? 0.0;
                final currentMappedUserId = _csvMemberToUserId[rawName] ?? (isActive ? (existingMembers.isNotEmpty ? existingMembers.first.userId : '') : '__SHADOW__');

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
                            Row(
                              children: [
                                Text(
                                  isActive ? 'Active • ' : 'Settled • ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? AppColors.amber : colors.emerald,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatINR(net),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isActive ? (net > 0 ? colors.emerald : AppColors.rose) : colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'From CSV',
                              style: TextStyle(fontSize: 9, color: colors.textSecondary),
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
                              value: existingMembers.any((em) => em.userId == currentMappedUserId) || (!isActive && currentMappedUserId == '__SHADOW__')
                                  ? currentMappedUserId
                                  : (isActive && existingMembers.isNotEmpty ? existingMembers.first.userId : '__SHADOW__'),
                              isExpanded: true,
                              dropdownColor: colors.surface,
                              style: TextStyle(fontSize: 12, color: colors.textMain),
                              items: [
                                if (!isActive)
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
            'Import History into ${targetGroup?.name ?? 'Group'} (${result.rows.length} Expenses)',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildImportingState(AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colors.cyan),
          ),
          const SizedBox(height: 20),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please keep FairShare open while your transactions are synced to the cloud.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
