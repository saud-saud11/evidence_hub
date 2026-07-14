import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/domain/user_profile.dart';
import '../../features/authentication/domain/user_role.dart';
import '../../features/authentication/presentation/auth_controller.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.value ?? ref.read(authRepositoryProvider).currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final location = GoRouterState.of(context).uri.path;

    // Define Navigation Items
    final List<ShellNavItem> navItems = [
      ShellNavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        labelKey: 'dashboard',
        route: '/',
      ),
      ShellNavItem(
        icon: Icons.search,
        activeIcon: Icons.search,
        labelKey: 'search',
        route: '/search',
      ),
      ShellNavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        labelKey: 'references',
        route: '/references',
      ),
      ShellNavItem(
        icon: Icons.star_border,
        activeIcon: Icons.star,
        labelKey: 'favorites',
        route: '/favorites',
      ),
    ];

    if (user.role == UserRole.admin) {
      navItems.addAll([
        ShellNavItem(
          icon: Icons.people_outline,
          activeIcon: Icons.people,
          labelKey: 'usersMgmt',
          route: '/users',
        ),
        ShellNavItem(
          icon: Icons.history,
          activeIcon: Icons.history,
          labelKey: 'activityLogs',
          route: '/activity-logs',
        ),
      ]);
    }

    return Scaffold(
      drawer: ResponsiveLayout.isDesktop(context)
          ? null
          : Drawer(
              child: _SidebarContent(
                user: user,
                navItems: navItems,
                currentLocation: location,
              ),
            ),
      appBar: ResponsiveLayout.isDesktop(context)
          ? null
          : AppBar(
              title: Text(
                context.tr('appName'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: false,
              actions: [
                _LanguageToggle(),
                _ThemeToggle(),
                const SizedBox(width: 8),
              ],
            ),
      body: ResponsiveLayout(
        mobile: child,
        tablet: child,
        desktop: Row(
          children: [
            SizedBox(
              width: 280,
              child: _SidebarContent(
                user: user,
                navItems: navItems,
                currentLocation: location,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: child,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ResponsiveLayout.isDesktop(context)
          ? null
          : BottomNavigationBar(
              currentIndex: _getBottomNavIndex(location, navItems),
              onTap: (index) => context.go(navItems[index].route),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Theme.of(context).colorScheme.secondary,
              items: navItems.take(4).map((item) {
                final isActive = location == item.route ||
                    (item.route != '/' && location.startsWith(item.route));
                return BottomNavigationBarItem(
                  icon: Icon(isActive ? item.activeIcon : item.icon),
                  label: context.tr(item.labelKey),
                );
              }).toList(),
            ),
    );
  }

  int _getBottomNavIndex(String location, List<ShellNavItem> items) {
    // Only take the first 4 for bottom nav
    final mainItems = items.take(4).toList();
    for (int i = 0; i < mainItems.length; i++) {
      if (location == mainItems[i].route ||
          (mainItems[i].route != '/' && location.startsWith(mainItems[i].route))) {
        return i;
      }
    }
    return 0;
  }
}

class ShellNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
  final String route;

  ShellNavItem({
    required this.icon,
    required this.activeIcon,
    required this.labelKey,
    required this.route,
  });
}

class _SidebarContent extends ConsumerWidget {
  final UserProfile user;
  final List<ShellNavItem> navItems;
  final String currentLocation;

  const _SidebarContent({
    Key? key,
    required this.user,
    required this.navItems,
    required this.currentLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? colorScheme.surface : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('appName'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    Text(
                      context.tr('appSubtitle'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: Theme.of(context).hintColor,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Navigation Links
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isActive = currentLocation == item.route ||
                    (item.route != '/' && currentLocation.startsWith(item.route));

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (!ResponsiveLayout.isDesktop(context)) {
                          Navigator.of(context).pop(); // Close drawer
                        }
                        context.go(item.route);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? colorScheme.primary.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isActive
                              ? Border(
                                  left: BorderSide(
                                    color: colorScheme.primary,
                                    width: context.isRTL ? 0 : 3,
                                  ),
                                  right: BorderSide(
                                    color: colorScheme.primary,
                                    width: context.isRTL ? 3 : 0,
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isActive ? item.activeIcon : item.icon,
                              color: isActive
                                  ? colorScheme.primary
                                  : colorScheme.secondary,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              context.tr(item.labelKey),
                              style: TextStyle(
                                fontWeight:
                                    isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(),

          // Toolbar (Lang & Theme toggles)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LanguageToggle(),
              _ThemeToggle(),
            ],
          ),
          const SizedBox(height: 12),

          // User Profile Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  radius: 18,
                  child: Text(
                    user.fullName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context.tr(user.role.nameStr),
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 18),
                  onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                  color: Colors.redAccent,
                  tooltip: context.tr('logout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return TextButton.icon(
      onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
      icon: const Icon(Icons.language, size: 16),
      label: Text(locale.languageCode == 'ar' ? 'English' : 'العربية'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    
    return IconButton(
      onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20),
      color: Theme.of(context).colorScheme.secondary,
      tooltip: context.tr('theme'),
    );
  }
}
