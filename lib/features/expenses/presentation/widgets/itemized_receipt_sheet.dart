import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/models/receipt_data.dart';
import '../../../../core/models/split.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/services/gemini_vision_service.dart';
import '../../../receipts/domain/services/receipt_split_calculator.dart';

class ReceiptScanResult {
  final ParsedReceiptData parsedData;
  final List<ExpenseSplit>? splits;
  final SplitType splitType;

  const ReceiptScanResult({
    required this.parsedData,
    this.splits,
    this.splitType = SplitType.exact,
  });
}

class ItemizedReceiptSheet extends ConsumerStatefulWidget {
  final List<GroupMember> members;
  final String? currentUserId;
  final ParsedReceiptData? initialParsedData;

  const ItemizedReceiptSheet({
    super.key,
    this.members = const [],
    this.currentUserId,
    this.initialParsedData,
  });

  static Future<ReceiptScanResult?> show(
    BuildContext context, {
    List<GroupMember> members = const [],
    String? currentUserId,
    ParsedReceiptData? initialParsedData,
  }) {
    return showModalBottomSheet<ReceiptScanResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemizedReceiptSheet(
        members: members,
        currentUserId: currentUserId,
        initialParsedData: initialParsedData,
      ),
    );
  }

  @override
  ConsumerState<ItemizedReceiptSheet> createState() => _ItemizedReceiptSheetState();
}

class _ItemizedReceiptSheetState extends ConsumerState<ItemizedReceiptSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _errorMessage;
  ParsedReceiptData? _parsedData;
  Uint8List? _selectedImageBytes;

  // Itemized split state
  final Map<int, Set<String>> _itemAssignments = {};
  TaxDistributionMode _taxMode = TaxDistributionMode.proportional;

  @override
  void initState() {
    super.initState();
    if (widget.initialParsedData != null) {
      _parsedData = widget.initialParsedData;
      _initializeAssignments(widget.initialParsedData!);
    }
  }

  @override
  void dispose() {
    // Zero-storage guarantee: immediately dispose image bytes from memory
    _selectedImageBytes = null;
    super.dispose();
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final apiKey = AppConfig.geminiApiKey;
    if (apiKey == null || apiKey.isEmpty || apiKey.contains('placeholder')) {
      setState(() {
        _errorMessage =
            'Gemini API key is not configured in .env. Please configure GEMINI_API_KEY to enable receipt OCR.';
      });
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 85,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      // Zero-storage guarantee: remove picker temp file from device storage immediately (mobile only)
      if (!kIsWeb) {
        try {
          final f = File(file.path);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {
          // Best-effort local cleanup
        }
      }

      setState(() {
        _selectedImageBytes = bytes;
        _isLoading = true;
        _errorMessage = null;
      });

      final service = ref.read(geminiVisionServiceProvider);
      final result = await service.parseReceiptBytes(bytes);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result != null) {
            _parsedData = result;
            _initializeAssignments(result);
          } else {
            _errorMessage =
                'Could not extract receipt details. Please check the image or enter details manually.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to process receipt image: $e';
        });
      }
    }
  }

  void _initializeAssignments(ParsedReceiptData data) {
    _itemAssignments.clear();
    final allIds = widget.members.map((m) => m.userId).toSet();
    for (var i = 0; i < data.items.length; i++) {
      // Default each item to shared by all members
      _itemAssignments[i] = Set<String>.from(allIds);
    }
  }

  void _toggleMemberAssignment(int itemIndex, String userId) {
    setState(() {
      final set = _itemAssignments.putIfAbsent(
        itemIndex,
        () => widget.members.map((m) => m.userId).toSet(),
      );

      if (set.contains(userId)) {
        set.remove(userId);
      } else {
        set.add(userId);
      }
    });
  }

  void _toggleAllAssignment(int itemIndex) {
    setState(() {
      final set = _itemAssignments.putIfAbsent(
        itemIndex,
        () => widget.members.map((m) => m.userId).toSet(),
      );

      final allIds = widget.members.map((m) => m.userId).toSet();
      if (set.length == allIds.length) {
        // If all are selected, toggle to just current user (or first member)
        final fallback = widget.currentUserId ?? (widget.members.isNotEmpty ? widget.members.first.userId : '');
        set.clear();
        if (fallback.isNotEmpty) set.add(fallback);
      } else {
        // Select all
        set.clear();
        set.addAll(allIds);
      }
    });
  }

  void _applyResult() {
    if (_parsedData == null) return;

    List<ExpenseSplit>? calculatedSplits;
    if (widget.members.isNotEmpty) {
      calculatedSplits = ReceiptSplitCalculator.calculateSplits(
        parsedData: _parsedData!,
        members: widget.members,
        itemAssignments: _itemAssignments,
        taxMode: _taxMode,
      );
    }

    // Zero-storage: dispose image bytes from memory
    _selectedImageBytes = null;

    Navigator.of(context).pop(ReceiptScanResult(
      parsedData: _parsedData!,
      splits: calculatedSplits,
      splitType: widget.members.isNotEmpty ? SplitType.exact : SplitType.equal,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top;

    return Container(
      constraints: BoxConstraints(
        maxHeight: availableHeight * 0.92,
      ),
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
          left: BorderSide(color: AppColors.borderSubtle, width: 1),
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderFocus,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () {
                          _selectedImageBytes = null;
                          Navigator.of(context).pop();
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Scan Receipt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (_parsedData != null)
                    TextButton.icon(
                      onPressed: _applyResult,
                      icon: const Icon(Icons.check_rounded, color: AppColors.emerald, size: 20),
                      label: const Text(
                        'Apply',
                        style: TextStyle(
                          color: AppColors.emerald,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Initial Source Selector (when nothing has been parsed yet)
            if (_parsedData == null && !_isLoading)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.document_scanner_rounded,
                      size: 64,
                      color: AppColors.primaryTeal,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'AI Receipt Scanner',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Take a photo or upload a receipt to auto-extract items, taxes, and amounts with Gemini Vision. Zero cloud persistence.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickAndAnalyze(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_rounded, size: 20),
                            label: const Text('Take Photo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryTeal,
                              foregroundColor: AppColors.surfaceDim,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickAndAnalyze(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 20),
                            label: const Text('From Gallery'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.borderSubtle),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.rose, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Loading state
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryTeal),
                    SizedBox(height: 20),
                    Text(
                      'Analyzing receipt with Gemini Vision...',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Extracting vendor, line items, taxes, and totals in memory',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

            // Parsed Result Display & Itemized Assignment
            if (_parsedData != null)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  children: [
                    // Vendor & Total Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_selectedImageBytes != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _selectedImageBytes!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _parsedData!.merchantName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_parsedData!.date} · ${_parsedData!.category.toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(_parsedData!.totalAmount),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tax & Fee Distribution Toggle (if members are present and there are extra charges)
                    if (widget.members.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tax & Surcharges',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _taxMode == TaxDistributionMode.proportional
                                        ? 'Split by item share'
                                        : 'Split equally',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SegmentedButton<TaxDistributionMode>(
                              segments: const [
                                ButtonSegment(
                                  value: TaxDistributionMode.proportional,
                                  label: Text('Proportional', style: TextStyle(fontSize: 11)),
                                ),
                                ButtonSegment(
                                  value: TaxDistributionMode.equal,
                                  label: Text('Equal', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                              selected: {_taxMode},
                              onSelectionChanged: (val) {
                                if (val.isNotEmpty) {
                                  setState(() => _taxMode = val.first);
                                }
                              },
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Line Items Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LINE ITEMS (${_parsedData!.items.length})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (_parsedData!.tax > 0)
                          Text(
                            'Tax: ${CurrencyFormatter.format(_parsedData!.tax)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Line Items List with interactive member assignment chips
                    ..._parsedData!.items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final assigned = _itemAssignments[idx] ?? widget.members.map((m) => m.userId).toSet();
                      final isAllSelected = widget.members.isNotEmpty && assigned.length == widget.members.length;
                      final shareCount = assigned.isNotEmpty ? assigned.length : widget.members.length;
                      final perPersonShare = shareCount > 0 ? item.price / shareCount : item.price;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item name & price row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity > 1 ? "${item.quantity}x " : ""}${item.name}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(item.price),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),

                            // If members are available, render assignment chips and share calculation
                            if (widget.members.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                isAllSelected
                                    ? '${CurrencyFormatter.format(perPersonShare)} each · Shared by all (${widget.members.length})'
                                    : '${CurrencyFormatter.format(perPersonShare)} each · $shareCount member${shareCount == 1 ? "" : "s"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primaryTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  // Quick "All" chip
                                  FilterChip(
                                    label: const Text('All', style: TextStyle(fontSize: 11)),
                                    selected: isAllSelected,
                                    onSelected: (_) => _toggleAllAssignment(idx),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AppColors.surfaceCard,
                                    selectedColor: AppColors.primaryTeal.withValues(alpha: 0.2),
                                    checkmarkColor: AppColors.primaryTeal,
                                    labelStyle: TextStyle(
                                      color: isAllSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                                      fontWeight: isAllSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                  // Individual Member Chips
                                  ...widget.members.map((m) {
                                    final isSelected = assigned.contains(m.userId);
                                    final firstName = m.displayName.split(' ').first;

                                    return FilterChip(
                                      avatar: UserAvatar(
                                        radius: 10,
                                        name: m.displayName,
                                        avatarUrl: m.avatarUrl,
                                        userId: m.userId,
                                      ),
                                      label: Text(firstName, style: const TextStyle(fontSize: 11)),
                                      selected: isSelected,
                                      onSelected: (_) => _toggleMemberAssignment(idx, m.userId),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: AppColors.surfaceCard,
                                      selectedColor: AppColors.primaryTeal.withValues(alpha: 0.2),
                                      checkmarkColor: AppColors.primaryTeal,
                                      labelStyle: TextStyle(
                                        color: isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 14),

                    // Live Member Split Summary
                    if (widget.members.isNotEmpty) ...[
                      Builder(builder: (context) {
                        final liveSplits = ReceiptSplitCalculator.calculateSplits(
                          parsedData: _parsedData!,
                          members: widget.members,
                          itemAssignments: _itemAssignments,
                          taxMode: _taxMode,
                        );

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'CALCULATED ITEM SPLITS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    'Exact total: ${CurrencyFormatter.format(_parsedData!.totalAmount)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.emerald,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...liveSplits.map((s) {
                                final member = widget.members.firstWhere(
                                  (m) => m.userId == s.userId,
                                  orElse: () => widget.members.first,
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            UserAvatar(
                                              radius: 12,
                                              name: member.displayName,
                                              avatarUrl: member.avatarUrl,
                                              userId: member.userId,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                member.displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        CurrencyFormatter.format(s.amount),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Apply Button
                    ElevatedButton.icon(
                      onPressed: _applyResult,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        widget.members.isNotEmpty
                            ? 'Apply Itemized Split (${CurrencyFormatter.format(_parsedData!.totalAmount)})'
                            : 'Use These Receipt Details',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: AppColors.surfaceDim,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _parsedData = null;
                          _selectedImageBytes = null;
                          _itemAssignments.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderSubtle),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Scan Another Receipt'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
