---
description: How to run the app on an Android device via USB
---

1.  **Connect your Android Phone** via USB cable.
2.  **Enable Developer Options** on your phone (usually tapping Build Number 7 times in Settings > About Phone).
3.  **Enable USB Debugging** in Developer Options.
4.  **Check for Popup**: Look at your phone screen. You should see a prompt "Allow USB debugging?".
    *   Check "Always allow from this computer".
    *   Tap **Allow**.
5.  **Run the App**:
    *   Open your terminal in VS Code.
    *   Run: `flutter run`
6.  **Troubleshooting**:
    *   If it says "Unauthorized", unplug and replug the USB cable, or toggle USB Debugging off and on.
