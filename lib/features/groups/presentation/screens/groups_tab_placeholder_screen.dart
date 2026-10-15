import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/widgets/theme_gradient_header.dart';

class GroupsTabPlaceholderScreen extends StatelessWidget {
  const GroupsTabPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.screen,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThemeGradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Groups',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: colors.textMain,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All Shared Cohorts & Roommate Ledgers',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.accentPill,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colors.border, width: 1),
                      ),
                      child: Icon(
                        Icons.people_alt_outlined,
                        size: 30,
                        color: colors.cyan,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Groups Directory',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Comprehensive cohort management, archives, and member rosters migrating in Phase 5.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
