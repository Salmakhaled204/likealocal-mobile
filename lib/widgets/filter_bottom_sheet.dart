import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';

class FilterBottomSheet extends StatelessWidget {
  FilterBottomSheet({super.key});

  // Full list of categories available in the app.
  final List<String> availableCategories = [
    'Restaurants',
    'Hidden Gems',
    'Experiences',
    'Cafes',
    'Nightlife',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, searchProvider, _) {
        // Fix #3 – Read the user's preferences from the provider so that
        // preference-matched chips are visually highlighted automatically.
        final userPrefs = searchProvider.userPreferences;

        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            // Keeps the sheet above the soft keyboard when open.
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      searchProvider.clearManualFilters();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear All',
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Category chips ───────────────────────────────────────────
              const SizedBox(height: 16),
              Text(
                'Categories',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableCategories.map((category) {
                  final isSelected =
                      searchProvider.selectedCategories.contains(category);

                  // Fix #3 – A category matched by the user's saved preferences
                  // is shown with a secondary tint so the user can see which
                  // categories come from their profile.
                  final isPreferred = userPrefs.contains(category);

                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPreferred)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.favorite,
                              size: 12,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.pinkAccent,
                            ),
                          ),
                        Text(category),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) => searchProvider.toggleCategory(category),
                    selectedColor:
                        Theme.of(context).primaryColor.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                    backgroundColor: isPreferred
                        ? Colors.pink.withOpacity(0.07)
                        : Colors.grey[100],
                    labelStyle: GoogleFonts.inter(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.black87,
                      fontWeight: isSelected || isPreferred
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),

              // ── Preference legend (only shown if user has preferences) ──
              if (userPrefs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.favorite, size: 12, color: Colors.pinkAccent),
                    const SizedBox(width: 6),
                    Text(
                      'Matches your preferences',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],

              // ── Apply button ─────────────────────────────────────────────
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Apply Filters',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
