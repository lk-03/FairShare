import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';

/// 10 Curated copyright-free (CC0/MIT) diverse cartoon illustrated avatars via DiceBear.
const List<String> diverseCartoonAvatars = [
  'https://api.dicebear.com/7.x/bottts-neutral/png?seed=Felix&backgroundColor=b6e3f4',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Aria&backgroundColor=ffd5dc',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Zane&backgroundColor=d1d4f9',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Nala&backgroundColor=c0aede',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Kiran&backgroundColor=ffdfbf',
  'https://api.dicebear.com/7.x/bottts-neutral/png?seed=Milo&backgroundColor=ffd5dc',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Tara&backgroundColor=b6e3f4',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Leo&backgroundColor=ffdfbf',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Sam&backgroundColor=d1d4f9',
  'https://api.dicebear.com/7.x/bottts-neutral/png?seed=Cleo&backgroundColor=c0aede',
];

/// Bottom sheet modal allowing users to select an illustrated avatar.
class AvatarPickerModal extends StatelessWidget {
  final String? currentAvatarUrl;
  final ValueChanged<String> onSelectAvatar;

  const AvatarPickerModal({
    super.key,
    this.currentAvatarUrl,
    required this.onSelectAvatar,
  });

  static Future<void> show(
    BuildContext context, {
    String? currentAvatarUrl,
    required ValueChanged<String> onSelectAvatar,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AvatarPickerModal(
        currentAvatarUrl: currentAvatarUrl,
        onSelectAvatar: onSelectAvatar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top;

    return Container(
      constraints: BoxConstraints(
        maxHeight: availableHeight * 0.88,
      ),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Avatar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select a cartoon character for your profile',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Avatar Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: diverseCartoonAvatars.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                final url = diverseCartoonAvatars[index];
                final isSelected = currentAvatarUrl == url;

                return GestureDetector(
                  onTap: () {
                    onSelectAvatar(url);
                    Navigator.of(context).pop();
                  },
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? colors.cyan : colors.border,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colors.cyan.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: colors.accentPill,
                            child: Icon(
                              Icons.person_rounded,
                              color: colors.cyan,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: colors.cyan,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
