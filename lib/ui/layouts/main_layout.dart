import 'package:flutter/material.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/notification_badge.dart';
import '../theme/app_colors.dart';

/// Main layout with sidebar
class MainLayout extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const MainLayout({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: floatingActionButton,
      drawer: !isDesktop ? const Drawer(child: AppSidebar()) : null,
      body: Row(
        children: [
          // Sidebar (desktop only)
          if (isDesktop) const AppSidebar(),
          
          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Menu button (mobile/tablet)
                      if (!isDesktop)
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),
                      
                      // Title
                      if (title != null)
                        Text(
                          title!,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      
                      const Spacer(),

                      // Notification badge
                      const NotificationBadge(),

                      // Actions
                      if (actions != null) ...actions!,
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
