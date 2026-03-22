import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final String activeSection;
  final Function(String) onNavigate;

  const BottomNavBar({
    super.key,
    required this.activeSection,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final List<NavItem> navItems = [
      NavItem(
        icon: Icons.analytics_outlined,
        label: 'Daily Research',
        section: 'daily_research',
      ),
      NavItem(
        icon: Icons.streetview_outlined,
        label: 'Street View',
        section: 'street_view',
      ),
    ];

    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D1515).withOpacity(0.95),
            const Color(0xFF0D1515),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navItems.map((item) {
          final isActive = activeSection == item.section;
          return _buildNavItem(item, isActive);
        }).toList(),
      ),
    );
  }

  Widget _buildNavItem(NavItem item, bool isActive) {
    return Expanded(
      child: InkWell(
        onTap: () => onNavigate(item.section),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: isActive
                    ? const Color(0xFF5FAD56)
                    : Colors.white.withOpacity(0.5),
                size: isActive ? 28 : 24,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive
                      ? const Color(0xFF5FAD56)
                      : Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
                ),
              ),
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 30,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5FAD56),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5FAD56).withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  final String section;

  NavItem({
    required this.icon,
    required this.label,
    required this.section,
  });
}