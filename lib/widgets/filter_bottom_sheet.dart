import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../theme/app_theme.dart';

class FilterBottomSheet extends StatelessWidget {
  FilterBottomSheet({super.key});

  final List<String> _categories = [
    'Restaurants',
    'Hidden Gems',
    'Experiences',
    'Cafes',
    'Nightlife',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, sp, _) {
        final userPrefs = sp.userPreferences;

        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Filters',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      sp.clearManualFilters();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.dustyPink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: Text(
                      'Clear all',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Categories ────────────────────────────────────────────
              const SizedBox(height: 6),
              Text(
                'Categories',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMid,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _categories.map((cat) {
                  final selected = sp.selectedCategories.contains(cat);
                  final preferred = userPrefs.contains(cat);

                  return GestureDetector(
                    onTap: () => sp.toggleCategory(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryLight
                            : preferred
                                ? const Color(0xFFFDF0F4)
                                : AppTheme.surfaceWarm,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : preferred
                                  ? AppTheme.dustyPink.withValues(alpha: 0.4)
                                  : AppTheme.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (preferred)
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 12,
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.dustyPink,
                              ),
                            ),
                          Text(
                            cat,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: selected || preferred
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected
                                  ? AppTheme.primary
                                  : preferred
                                      ? AppTheme.dustyPink
                                      : AppTheme.textMid,
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: AppTheme.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // ── Preference legend ─────────────────────────────────────
              if (userPrefs.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0F4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.dustyPink.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: AppTheme.dustyPink,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Matches your preferences',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.dustyPink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Apply ─────────────────────────────────────────────────
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply filters'),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}
