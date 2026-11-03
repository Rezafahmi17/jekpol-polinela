import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool showBadge;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.showBadge = false,
  });
}

class CustomFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;

  const CustomFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = items.length >= 5;
    return Container(
      margin: EdgeInsets.fromLTRB(isCompact ? 10 : 18, 0, isCompact ? 10 : 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.04), width: 1.2),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8, vertical: isCompact ? 5 : 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isSelected = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!isSelected) {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(vertical: isCompact ? 5 : 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: item.showBadge,
                          smallSize: 9,
                          backgroundColor: AppColors.danger,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 200),
                            scale: isSelected ? 1.15 : 1.0,
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected ? AppColors.primary : AppColors.grey,
                              size: isCompact ? 21 : 24,
                            ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 3 : 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: isCompact ? 10.5 : 11.5,
                            letterSpacing: isCompact ? -0.2 : 0,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppColors.primaryDark : AppColors.grey,
                            fontFamily: 'Roboto',
                          ),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

