import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http; // ✅ For OneSignal Rest API
import 'package:onesignal_flutter/onesignal_flutter.dart'; // ✅ For Mobile/Desktop

// 🛡️ Conditional Import for JS Interop (Web)
import 'notification_service_stub.dart' if (dart.library.html) 'notification_service_web.dart' as js_helper;
import '../main.dart';

@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  debugPrint("🔥 [FCM Background] Message ID: ${message.messageId}");
}

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  String? _currentUserId; // ✅ Store current user for token association
  
  // 🧭 Navigation Stream
  final _navController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get navigationStream => _navController.stream;
  
  Map<String, dynamic>? _pendingData; // ✅ Handles "Terminated State" clicks
  Map<String, dynamic>? get pendingNavigation => _pendingData;
  void clearPendingNavigation() => _pendingData = null;

  /// Request notification permissions (System Level)
  Future<void> requestPermission() async {
    if (kIsWeb) {
      // Browsers handle this via OneSignal Web SDK
      return; 
    } else {
      await OneSignal.Notifications.requestPermission(true);
    }
  }

  Future<void> init() async {
    final String appId = '76f30b3e-82fb-48cb-8c8a-88cd994e1a1c';
    
    // 🔔 1. ONESIGNAL INIT
    if (kIsWeb) {
      debugPrint("🌍 NotificationService: Using JS OneSignal helper.");
      js_helper.initOneSignal(appId);
    } else {
      try {
        OneSignal.initialize(appId);
        OneSignal.Notifications.requestPermission(true);
      } catch (e) {
        debugPrint("❌ OneSignal Mobile Init Failed: $e");
      }

      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        if (data != null) {
          debugPrint("🔔 OneSignal Clicked (Plugin): $data");
          final mappedData = Map<String, dynamic>.from(data);
          if (_navController.hasListener) {
            _navController.add(mappedData);
          } else {
            _pendingData = mappedData;
          }
        }
      });
    }

    // 🔔 2. FCM INIT (Safety Layer)
    try {
      if (!kIsWeb) {
         // Request Permissions for Android 13+
         await _fcm.requestPermission(alert: true, badge: true, sound: true);
         
         // Get FCM Token for safe fallback / direct messaging
         String? fcmToken = await _fcm.getToken();
         if (fcmToken != null) {
           debugPrint("🔥 FCM DEVICE TOKEN: $fcmToken");
         }

         // Foreground FCM listener
         FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            debugPrint("🔥 [FCM Foreground] Title: ${message.notification?.title}");
            if (message.notification != null) {
               showLocalNotification(
                  id: message.hashCode,
                  title: message.notification!.title!,
                  body: message.notification!.body!,
                  payload: jsonEncode(message.data),
               );
            }
         });

         // Background FCM click listener (app in background)
         FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
            debugPrint("🔥 [FCM Background Click]: ${message.data}");
            if (_navController.hasListener) {
              _navController.add(message.data);
            } else {
              _pendingData = message.data;
            }
         });

         // ✅ Handle Terminated State Click (app was fully closed)
         final initialMessage = await _fcm.getInitialMessage();
         if (initialMessage != null) {
            debugPrint("🔥 [FCM Terminated Click]: ${initialMessage.data}");
            _pendingData = initialMessage.data;
            _navController.add(initialMessage.data); // Notify active listeners too
         }
      }
    } catch (e) {
      debugPrint("⚠️ FCM Init Error: $e");
    }

    // 🔔 3. LOCAL NOTIFICATIONS (For Heads-up)
    try {
       if (defaultTargetPlatform == TargetPlatform.android) {
         const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
         const initSettings = InitializationSettings(android: androidSettings);
         
         await _localNotifications.initialize(
            initSettings,
            onDidReceiveNotificationResponse: (details) {
               if (details.payload != null) {
                  try {
                    final data = jsonDecode(details.payload!);
                    final mappedData = Map<String, dynamic>.from(data);
                    if (_navController.hasListener) {
                      _navController.add(mappedData);
                    } else {
                      _pendingData = mappedData;
                    }
                  } catch (e) {
                    debugPrint("Error handling notification payload: $e");
                  }
               }
            },
         );

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

    // 🌐 WEB DEEP LINK CHECK
    if (kIsWeb) {
      final params = Uri.base.queryParameters;
      if (params.containsKey('type') && params.containsKey('id')) {
        final mappedData = Map<String, dynamic>.from(params);
        mappedData['relatedId'] = params['id'];
        mappedData['academicYearId'] = params['year'];
        _navController.add(mappedData);
      }
    }
  }

  void _handleInteraction(RemoteMessage message) {
    debugPrint("🔔 FCM Interaction: ${message.data}");
    _navController.add(message.data);
  }

  void setUserId(String? userId) {
    _currentUserId = userId;
    if (userId != null) {
      // 🛡️ Start real-time Firestore listener for results/approvals
      listenForNewNotifications(userId);

      if (kIsWeb) {
        js_helper.setOneSignalUser(userId);
      } else {
        OneSignal.login(userId);

        // 🔥 Safely link FCM Token to Firestore for this user
        _fcm.getToken().then((token) {
          if (token != null) {
            _saveToken(token, userId);
          }
        });
      }
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
      // 🔑 Deterministic ID to prevent duplicates (UserId + RelatedId + Type)
      // Removing minute to ensure a single unique notification exists per action
      final String uniqueId = "${toUserId}_${relatedId ?? 'info'}_${type ?? 'general'}";

      // 1. Save to Firestore (Real-time DB)
      final String? upperDept = targetDepartment?.trim().toUpperCase();
      
      await _db.collection('notifications').doc(uniqueId).set({
        'toUserId': toUserId,
        'title': title,
        'body': body,
        'type': type ?? 'info',
        'relatedId': relatedId,
        'leaveType': leaveType,
        'academicYearId': academicYearId,
        'targetDepartment': upperDept, 
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Trigger OneSignal Push (Background)
      await sendOneSignalPush(
        toUserId: toUserId,
        title: title,
        body: body,
        data: {
          'type': type ?? 'info',
          'relatedId': relatedId ?? '',
          'leaveType': leaveType ?? '',
          'academicYearId': academicYearId ?? '',
          'targetDepartment': upperDept ?? '',
        },
      );
    } catch (e) {
      debugPrint("Error sending notification: $e");
    }
  }

  Future<void> sendOneSignalPush({
    required String toUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      const String onesignalRestKey = "os_v2_app_o3zqwpuc7nemxdekrdgzstq2dsdwpeskurnuminkdxxxrcstohcv6do2woumo7wyydr7dts3adn7bdrv5i52ioq4qrgqk3nq2tbgm2q"; 
      const String appId = "76f30b3e-82fb-48cb-8c8a-88cd994e1a1c";

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $onesignalRestKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_aliases': {
            'external_id': [toUserId]
          },
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data,
          'priority': 10,
          'android_channel_id': 'leave_status_channel',
          'android_visibility': 1,
          'web_url': 'https://leavex-staff.web.app/#/notifications',
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("❌ OneSignal Push Failed (${response.statusCode}): ${response.body}");
        if (response.body.contains("Access denied")) {
          debugPrint("⚠️ TIP: Your REST API Key might be invalid. Check OneSignal Dashboard > Settings > Keys & IDs.");
        }
      } else {
        debugPrint("🚀 OneSignal Push Sent to $toUserId");
      }
    } catch (e) {
      debugPrint("OneSignal Push Error: $e");
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
        // 🔥 Use Future.delayed or call without await to avoid blocking if OneSignal fails
        sendNotification(
          toUserId: uid,
          title: title,
          body: body,
          type: type,
          relatedId: relatedId,
          leaveType: leaveType,
          academicYearId: academicYearId,
          targetDepartment: targetDepartment?.trim().toUpperCase(),
        ).catchError((e) => debugPrint("Error notifying admin $uid: $e"));
      }
      debugPrint("📢 Sent request alerts to ${recipientIds.length} admins (Target: $sanitizedTarget)");
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

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      if (notificationId.isEmpty) return;
      await _db.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }
}
