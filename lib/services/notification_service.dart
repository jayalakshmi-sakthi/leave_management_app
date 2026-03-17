import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // for kIsWeb, defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  String? _currentUserId; // ✅ Store current user for token association
  final _navController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get navigationStream => _navController.stream;

  Future<void> init() async {
    // 1. WEB GUARD
    // On Web, LocalNotifications/Android Channels cause crashes or errors if not handled.
    if (kIsWeb) {
      debugPrint("🌍 NotificationService: Running on Web. Skipping Android setup.");
      // Skip straight to FCM or return if FCM is also partial
      // We will try FCM only
    } else {
      // 2. ANDROID / iOS SETUP (Mobile Only)
      try {
           // Use defaultTargetPlatform from foundation (web-safe)
           if (defaultTargetPlatform == TargetPlatform.android) {
             const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
             const initSettings = InitializationSettings(android: androidSettings);
             
             await _localNotifications.initialize(
                initSettings,
                onDidReceiveNotificationResponse: (details) {
                   if (details.payload != null) {
                      try {
                        final data = jsonDecode(details.payload!);
                      final type = data['type'];
                      final relatedId = data['relatedId'];
                      final academicYearId = data['academicYearId'];
          
                      if (type == 'status_change' && relatedId != null) {
                        navigatorKey.currentState?.pushNamed(
                          AppRoutes.detail,
                          arguments: {
                            'leaveId': relatedId,
                            'academicYearId': academicYearId ?? '2024-2025',
                          },
                        );
                      }
                    } catch (e) {
                      debugPrint("Error handling notification payload: $e");
                    }
                 }
              },
           );
  
          // Create Channel
          const channel = AndroidNotificationChannel(
            'leave_status_channel',
            'Leave Status Updates',
            description: 'Notifications for leave approvals and rejections',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          );
  
          
            await _localNotifications
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.createNotificationChannel(channel);
           }
      } catch (e) {
         debugPrint("⚠️ LocalNotification Init Error: $e");
      }
    }

    // 3. FCM SETUP (Safe for Web if Service Worker exists)
    try {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      await _fcm.requestPermission(alert: true, badge: true, sound: true);

      // Background Message Handler - CRITICAL: Not supported on Web in the same way or requires worker
      if (!kIsWeb) {
         FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Broadcast to UI regardless 
        _navController.add(message.data);
        
        // Skip System Tray Notification in Foreground for Staff App 
        // because listenForNewNotifications handles Firestore document added.
        debugPrint("🔔 FCM Foreground Message (Staff App): ${message.data}");
      });

      // Handle Background Click (App Opened)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleInteraction(message);
      });
      
      // Check Initial Message (Terminated State)
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleInteraction(initialMessage);
      }

      // Token Refresh
       _fcm.onTokenRefresh.listen((newToken) {
        _saveToken(newToken, _currentUserId);
      });

      // 🌐 WEB DEEP LINK CHECK
      if (kIsWeb) {
        final params = Uri.base.queryParameters;
        if (params.containsKey('type') && params.containsKey('id')) {
          debugPrint("🌐 Web Launch Params Detected: $params");
          // Map URL keys to internal keys
          final mappedData = Map<String, dynamic>.from(params);
          mappedData['relatedId'] = params['id'];
          mappedData['academicYearId'] = params['year'];
          _handleInteraction(RemoteMessage(data: mappedData));
        }
      }
      
    } catch (e) {
      debugPrint("⚠️ FCM Init Error: $e");
    }
  }

  void _handleInteraction(RemoteMessage message) {
    debugPrint("🔔 FCM Interaction: ${message.data}");
    _navController.add(message.data);
  }

  void setUserId(String? userId) {
    _currentUserId = userId;
    if (userId != null) {
      _fcm.getToken().then((token) => _saveToken(token, userId));
    }
  }

  Future<void> _saveToken(String? token, String? userId) async {
    if (token == null || userId == null || userId.isEmpty) return;
    try {
      await _db.collection('users').doc(userId).update({
        'fcmToken': token,
        'tokens': FieldValue.arrayUnion([token]), 
        'lastActive': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Token saved for $userId");
    } catch (e) {
      debugPrint("Error saving token: $e");
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    Color? color,
  }) async {
    try {
      final sanitizedTitle = title
          .replaceAll('(Placement Cell)', '')
          .replaceAll('Placement Cell', '')
          .replaceAll('()', '')
          .trim();
      final sanitizedBody = body
          .replaceAll('(Placement Cell)', '')
          .replaceAll('Placement Cell', '')
          .replaceAll('()', '')
          .trim();

      final androidDetails = AndroidNotificationDetails(
        'leave_status_channel',
        'Leave Status Updates',
        channelDescription: 'Notifications for leave approvals and rejections',
        importance: Importance.max,
        priority: Priority.max,
        color: color ?? const Color(0xFF4F46E5),
        ledColor: color,
        ledOnMs: 1000,
        ledOffMs: 500,
        enableLights: true,
        timeoutAfter: 5000, // ✅ Auto-dismiss after 5 seconds
        category: AndroidNotificationCategory.message,
        styleInformation: const BigTextStyleInformation(''),
      );

      final details = NotificationDetails(android: androidDetails);
      await _localNotifications.show(id, sanitizedTitle, sanitizedBody, details, payload: payload);
    } catch (e) {
      debugPrint("Logged: Local Notification (Skipped on Web): $title - $body");
    }
  }

  void listenForNewNotifications(String userId) {
    _db.collection('notifications')
       .where('toUserId', isEqualTo: userId)
       .where('isRead', isEqualTo: false)
       .snapshots()
       .listen((snap) {
         for (var change in snap.docChanges) {
           if (change.type == DocumentChangeType.added) {
             final data = change.doc.data();
             final createdAt = (data?['createdAt'] as Timestamp?)?.toDate();
             
             // Only notify if created within the last 5 minutes
             final isRecent = createdAt != null && createdAt.isAfter(DateTime.now().subtract(const Duration(minutes: 5)));
             
             if (isRecent) {
               // Determine color based on title/body or a status field if available
               Color? statusColor;
               if (data?['title']?.toString().toLowerCase().contains('approved') ?? false) {
                 statusColor = Colors.teal;
               } else if (data?['title']?.toString().toLowerCase().contains('rejected') ?? false) {
                 statusColor = Colors.red;
               }

               // Create structured payload for redirection
               final payloadMap = {
                 'type': data?['type'],
                 'relatedId': data?['relatedId'],
                 'academicYearId': data?['academicYearId'],
               };

               showLocalNotification(
                 id: change.doc.id.hashCode,
                 title: data?['title'] ?? 'New Notification',
                 body: data?['body'] ?? 'You have a new update.',
                 payload: jsonEncode(payloadMap),
                 color: statusColor,
               );
             }
           }
         }
       });
  }

  Future<void> sendNotification({
    required String toUserId,
    required String title,
    required String body,
    String? type,
    String? relatedId, // e.g., leaveId
    String? leaveType, // ✅ Added
    String? academicYearId, // ✅ Added
    String? targetDepartment, // ✅ Added
  }) async {
    try {
      // 1. Save to Firestore (Real-time DB)
      await _db.collection('notifications').add({
        'toUserId': toUserId,
        'title': title,
        'body': body,
        'type': type ?? 'info',
        'relatedId': relatedId,
        'leaveType': leaveType,
        'academicYearId': academicYearId,
        'targetDepartment': targetDepartment, // ✅ Added for filtering
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Trigger FCM Push (Background/System Tray)
      await sendFcmPush(
        toUserId: toUserId,
        title: title,
        body: body,
        data: {
          'type': type ?? 'info',
          'relatedId': relatedId ?? '',
          'leaveType': leaveType ?? '',
          'academicYearId': academicYearId ?? '',
        },
      );
    } catch (e) {
      debugPrint("Error sending notification: $e");
    }
  }

  Future<void> sendFcmPush({
    required String toUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final userDoc = await _db.collection('users').doc(toUserId).get();
      final token = userDoc.data()?['fcmToken'];
      if (token == null) return;

      await _db.collection('fcm_queue').add({
        'token': token,
        'title': title,
        'body': body,
        'data': data,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint("🚀 FCM Push Queued for $toUserId");
    } catch (e) {
      debugPrint("FCM Push Error: $e");
    }
  }

  Future<void> notifyAdmins({
    required String title,
    required String body,
    String? type,
    String? relatedId,
    String? leaveType,
    String? academicYearId,
    String? targetDepartment,
    String? triggeringUserId,
  }) async {
    try {
      final sanitizedTarget = targetDepartment?.trim();
      final adminsSnap = await _db.collection('users')
          .where('role', whereIn: ['admin', 'super_admin'])
          .get();
      
      final Set<String> recipientIds = {};

      for (var doc in adminsSnap.docs) {
          if (doc.id == triggeringUserId) continue;

          final data = doc.data();
          final String role = data['role'] ?? 'staff';
          final String? adminDept = (data['department'] as String?)?.trim();
          bool shouldNotify = false;

          if (role == 'super_admin') {
            shouldNotify = true;
          } else if (role == 'admin') {
            if (adminDept == 'All') {
              shouldNotify = true;
            } else if (sanitizedTarget != null && adminDept?.toLowerCase() == sanitizedTarget.toLowerCase()) {
              shouldNotify = true;
            } else if (sanitizedTarget == null && adminDept == null) {
              shouldNotify = true;
            }
          }
          if (shouldNotify) recipientIds.add(doc.id);
      }

      for (var uid in recipientIds) {
        await sendNotification(
          toUserId: uid,
          title: title,
          body: body,
          type: type,
          relatedId: relatedId,
          leaveType: leaveType,
          academicYearId: academicYearId,
          targetDepartment: targetDepartment,
        );
      }
      debugPrint("📢 Notifications sent to ${recipientIds.length} admins (Target: $sanitizedTarget)");
    } catch (e) {
      debugPrint("Error notifying admins: $e");
    }
  }

  /// Stream notifications for the current user
  Stream<List<Map<String, dynamic>>> streamNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .limit(50)
        .snapshots()
        .map((snap) {
          final notifications = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
          
          // Sort in memory by createdAt descending
          notifications.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          
          return notifications;
        });
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  /// Mark all notifications for a user as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _db.batch();
      final unreadSnap = await _db
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadSnap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking all as read: $e");
    }
  }

  /// Get unread count stream
  Stream<int> getUnreadCount(String userId) {
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
