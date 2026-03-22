// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void initOneSignal(String appId) {
  js.context.callMethod('initOneSignal', [appId]);
}

void setOneSignalUser(String userId) {
  js.context.callMethod('setOneSignalUser', [userId]);
}
