// File generated for NovaSpend Firebase apps.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAKkrXbrXOgaphR9IxjTi_Y6gvPFG5G8fM',
    appId: '1:598409230916:web:dd3030eb1ee950e7c3da11',
    messagingSenderId: '598409230916',
    projectId: 'auto-expense-tracker-2026',
    authDomain: 'auto-expense-tracker-2026.firebaseapp.com',
    storageBucket: 'auto-expense-tracker-2026.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBMC_TaDLVv0ufh9XlkG3-8LZIcowYR8vU',
    appId: '1:598409230916:android:8b05e4c6d4dfb276c3da11',
    messagingSenderId: '598409230916',
    projectId: 'auto-expense-tracker-2026',
    storageBucket: 'auto-expense-tracker-2026.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCaGSM8bvCj2yeG2FggzYLjwYallaps33Y',
    appId: '1:598409230916:ios:9001f5cfd81459eac3da11',
    messagingSenderId: '598409230916',
    projectId: 'auto-expense-tracker-2026',
    storageBucket: 'auto-expense-tracker-2026.firebasestorage.app',
    iosBundleId: 'com.example.novaSpend',
  );
}
