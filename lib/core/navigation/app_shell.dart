import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/bills/presentation/bloc/bills_bloc.dart';
import '../../features/bills/presentation/bloc/bills_event.dart';
import '../../features/bills/presentation/pages/bills_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'app_routes.dart';

/// Destination after signing in: the dashboard and the bills list share one
/// tab bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const String routeName = AppRoutes.shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    context.read<BillsBloc>().add(const BillsStarted());
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          HomePage(onSeeAllBills: () => _select(1)),
          const BillsPage(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        index: _index,
        onChanged: _select,
      ),
    );
  }
}

/// Bottom tab bar: cream surface, inked hairline, accent for the active tab.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: AppLayout.navHeight + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(
          top: BorderSide(color: AppColors.ink, width: AppStroke.thin),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _NavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.receipt_long_outlined,
              label: 'Bills',
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.accent : AppColors.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppFonts.display(
                size: 11,
                weight: FontWeight.w600,
                color: color,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
