import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';

/// OnboardingCarousel presents a 5-slide interactive walkthrough of FairShare's
/// signature features: debt simplification, direct UPI payments, split engines,
/// shared house cart, and Splitwise CSV migration.
class OnboardingCarousel extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const OnboardingCarousel({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<OnboardingCarousel> {
  final PageController _pageController = PageController();
  int _currentSlide = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToSlide(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  void _handleNext() {
    if (_currentSlide < 4) {
      _goToSlide(_currentSlide + 1);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        children: [
          // Top bar with branding & skip button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 28, withGlow: true, withShadow: true),
                    const SizedBox(width: 8),
                    Text(
                      'FairShare',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: colors.textMain,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Paging slide content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentSlide = index);
              },
              children: [
                _buildSlide(
                  badge: 'ALGORITHM POWERED',
                  badgeColor: colors.cyan,
                  title: 'Split Smarter,\nSettle Faster',
                  description:
                      'Stop dealing with tangled group IOUs. FairShare calculates the minimum cash transfers so everyone settles with the fewest possible payments.',
                  graphic: _buildDebtSimplificationGraphic(colors, isDark),
                ),
                _buildSlide(
                  badge: 'INSTANT & ZERO FEES',
                  badgeColor: colors.emerald,
                  title: 'Pay Directly.\nNo Middleman Fees.',
                  description:
                      'Settle debts directly into any UPI app. 1-tap opens Google Pay, PhonePe, or Paytm with the payee and amount pre-filled.',
                  graphic: _buildDirectUpiGraphic(colors, isDark),
                ),
                _buildSlide(
                  badge: 'FLEXIBLE MATH',
                  badgeColor: colors.cyan,
                  title: '5 Granular\nSplit Modes',
                  description:
                      'Split by Equal shares, Exact rupees, Percentages (%), Custom Ratios (2:1:1), or Adjustments with auto-calculated remainder.',
                  graphic: _buildSplitModesGraphic(colors, isDark),
                ),
                _buildSlide(
                  badge: 'HOUSEHOLD & TRIPS',
                  badgeColor: colors.amber,
                  title: 'Shared House Cart\n& Needs List',
                  description:
                      'Keep a shared household supply checklist. When someone buys an item, check it off to auto-convert it into a shared group expense!',
                  graphic: _buildHouseCartGraphic(colors, isDark),
                ),
                _buildSlide(
                  badge: 'EASY MIGRATION',
                  badgeColor: colors.cyan,
                  title: 'Splitwise CSV Import\n& 1-Tap Shortcuts',
                  description:
                      'Migrate years of Splitwise history with 1-tap CSV import, preserve shadow member history, and bookmark frequent expenses as 1-tap shortcuts.',
                  graphic: _buildSplitwiseMigrationGraphic(colors, isDark),
                ),
              ],
            ),
          ),

          // Bottom Controls: Pagination Dots & Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              children: [
                // Animated pagination indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (idx) {
                    final isActive = idx == _currentSlide;
                    return GestureDetector(
                      onTap: () => _goToSlide(idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: isActive ? 24 : 8,
                        decoration: BoxDecoration(
                          color: isActive ? colors.cyan : colors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Primary CTA button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.cyan,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _currentSlide == 4 ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide({
    required String badge,
    required Color badgeColor,
    required String title,
    required String description,
    required Widget graphic,
  }) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Graphic container
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: graphic,
                  ),
                  const SizedBox(height: 24),

                  // Badge pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Slide Title
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.15,
                      color: colors.textMain,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Slide Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE GRAPHIC 1: DEBT SIMPLIFICATION
  // ---------------------------------------------------------------------------
  Widget _buildDebtSimplificationGraphic(AppThemeColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'DEBT SIMPLIFICATION',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colors.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '2 Fewer Payments',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Before card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Before: 3 Tangled Debts',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Alex owes Sam ₹300',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sam owes Pri ₹750',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Down arrow
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Icon(
              Icons.arrow_circle_down_rounded,
              size: 22,
              color: colors.cyan,
            ),
          ),

          // After simplified card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.emerald.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.emerald,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alex pays Pri ₹450',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      Text(
                        'Fully Settled in 1 Payment',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹450',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: colors.emerald,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE GRAPHIC 2: DIRECT UPI INTENT
  // ---------------------------------------------------------------------------
  Widget _buildDirectUpiGraphic(AppThemeColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'DIRECT UPI INTENT',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colors.emerald,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 11,
                      color: colors.cyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified VPA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: colors.cyan,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settle up with Rahul',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'rahul@okhdfcbank',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹620.00',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: colors.cyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Quick UPI badges
          Row(
            children: [
              _buildUpiBadge('GPay', colors.cyan, colors),
              const SizedBox(width: 8),
              _buildUpiBadge('PhonePe', const Color(0xFF818CF8), colors),
              const SizedBox(width: 8),
              _buildUpiBadge('Paytm', const Color(0xFF38BDF8), colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpiBadge(String name, Color badgeColor, AppThemeColors colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: badgeColor,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE GRAPHIC 3: 5 GRANULAR SPLIT MODES
  // ---------------------------------------------------------------------------
  Widget _buildSplitModesGraphic(AppThemeColors colors, bool isDark) {
    final modes = ['Equal', 'Unequal', 'Percent (%)', 'Shares (2:1)', 'Adjust'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'SPLIT ENGINES',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colors.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Custom Ratios & %',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Mode tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: modes.map((m) {
              final isHighlighted = m == 'Shares (2:1)';
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? colors.cyan.withValues(alpha: 0.2)
                      : colors.accentPill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isHighlighted ? colors.cyan : colors.border,
                    width: 1,
                  ),
                ),
                child: Text(
                  m,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isHighlighted ? colors.cyan : colors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Split visual bar card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Dinner at Biggies (₹900)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '3 Members',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Multi-segment progress bar (2 : 1 : 1)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 8,
                          color: colors.cyan,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 8,
                          color: colors.emerald,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 8,
                          color: colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Alex: ₹450 (2x)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'Sam: ₹225 (1x)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'Pri: ₹225 (1x)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE GRAPHIC 4: SHARED HOUSE CART & NEEDS LIST
  // ---------------------------------------------------------------------------
  Widget _buildHouseCartGraphic(AppThemeColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'SHARED HOUSE CART',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colors.amber,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Auto-Log Expense',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Checked item
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: colors.emerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Water Can (20L)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.lineThrough,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '₹90 (Auto-logged)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colors.emerald,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Pending item
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: colors.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cooking Oil & Masalas',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textMain,
                    ),
                  ),
                ),
                Text(
                  'Urgent Need',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE GRAPHIC 5: SPLITWISE MIGRATION & PRESETS
  // ---------------------------------------------------------------------------
  Widget _buildSplitwiseMigrationGraphic(AppThemeColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'IMPORT & PRESETS',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colors.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '100% Free',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // CSV Demo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.cyan.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_download_outlined,
                    size: 18,
                    color: colors.cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flatmates_export.csv',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      Text(
                        '270+ Transactions Imported',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.done_all_rounded,
                  size: 18,
                  color: colors.emerald,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Preset Bookmark Demo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.bookmark_rounded,
                        size: 18,
                        color: colors.cyan,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Hostel Tea & Snacks',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: colors.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '1-TAP PRESET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.cyan,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
