import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../widgets/responsive_wrapper.dart'; // ✅ Added

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to view notifications")),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.blue),
            onPressed: () => NotificationService().markAllAsRead(user.uid),
            tooltip: "Mark all as read",
          )
        ],
      ),
      body: ResponsiveWrapper( // ✅ Responsive
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: NotificationService().streamNotifications(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_rounded,
                      size: 64,
                      color: isDark ? Colors.white24 : Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No notifications yet",
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey[500],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final isRead = notif['isRead'] == true;
                final title = notif['title']?.toString() ?? 'Notification';
                final body = notif['body']?.toString() ?? '';
                final createdAt = (notif['createdAt'] as Timestamp?)?.toDate();
                final String type = (notif['type'] ?? 'info').toString().toLowerCase();

                // Determine Icon & Color
                IconData icon = Icons.info_rounded;
                Color color = Colors.blue;

                final String combinedText = "$title $body".toLowerCase();

                if (combinedText.contains('approved')) {
                  icon = Icons.check_circle_rounded;
                  color = Colors.teal;
                } else if (combinedText.contains('rejected')) {
                  icon = Icons.cancel_rounded;
                  color = Colors.red;
                } else if (combinedText.contains('comp-off') || notif['leaveType'] == 'COMP') {
                  icon = Icons.stars_rounded;
                  color = Colors.orange;
                } else if (type == 'status_change') {
                  icon = Icons.assignment_turned_in_rounded;
                  color = Colors.deepPurple;
                }

                // Format Time
                String timeAgo = '';
                if (createdAt != null) {
                  final diff = DateTime.now().difference(createdAt);
                  if (diff.inMinutes < 1) {
                    timeAgo = 'Just now';
                  } else if (diff.inMinutes < 60) {
                    timeAgo = '${diff.inMinutes}m ago';
                  } else if (diff.inHours < 24) {
                    timeAgo = '${diff.inHours}h ago';
                  } else {
                    timeAgo = DateFormat('MMM dd').format(createdAt);
                  }
                }

                return Dismissible(
                  key: Key(notif['id']),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                     // In real app, delete from Firestore
                  },
                  background: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: InkWell(
                    onTap: () async {
                      if (!isRead) {
                        await NotificationService().markAsRead(notif['id']);
                      }
                      // Navigate if needed
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRead 
                              ? theme.dividerColor.withOpacity(0.5) 
                              : color.withOpacity(0.5),
                          width: isRead ? 1 : 1.5,
                        ),
                        boxShadow: isRead ? [] : [
                           BoxShadow(
                             color: color.withOpacity(0.1),
                             blurRadius: 8,
                             offset: const Offset(0, 4)
                           )
                        ]
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                          fontSize: 15,
                                          color: theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  body,
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    timeAgo,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
