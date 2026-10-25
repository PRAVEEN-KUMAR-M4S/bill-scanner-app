import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_category.dart';

/// One bill as it appears in "Recent bills" and the bills list.
class BillTile extends StatelessWidget {
  const BillTile({super.key, required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg - 2),
        border: Border.all(color: AppColors.ink, width: AppStroke.base),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              _iconFor(bill.category),
              size: 21,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  bill.merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.display(
                    size: 15,
                    weight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${bill.category.label} · ${DateFormats.shortDay(bill.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.display(
                    size: 11.5,
                    color: AppColors.inkMuted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            Currency.inr(bill.total),
            style: AppFonts.display(
              size: 14.5,
              weight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(BillCategory category) {
    return switch (category) {
      BillCategory.foodAndDrink => Icons.local_cafe_outlined,
      BillCategory.groceries => Icons.shopping_basket_outlined,
      BillCategory.travel => Icons.luggage_outlined,
      BillCategory.health => Icons.medication_outlined,
      BillCategory.utilities => Icons.bolt_outlined,
      BillCategory.shopping => Icons.shopping_bag_outlined,
      BillCategory.home => Icons.home_outlined,
      BillCategory.entertainment => Icons.movie_outlined,
      BillCategory.education => Icons.menu_book_outlined,
      BillCategory.other => Icons.receipt_long_outlined,
    };
  }
}
