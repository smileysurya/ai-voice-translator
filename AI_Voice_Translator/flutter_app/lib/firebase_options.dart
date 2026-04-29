// Generated Firebase options for this project.
// DO NOT commit this file to public repositories.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    // Fallback to web config for other platforms (add Android/iOS configs if needed)
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAle36Qk7JVrsWdKCF1BbV1E__gA46surM',
    appId: '1:356343902599:web:1046e2f9a013f484026322',
    messagingSenderId: '356343902599',
    projectId: 'translator-7c9c0',
    authDomain: 'translator-7c9c0.firebaseapp.com',
    storageBucket: 'translator-7c9c0.firebasestorage.app',
    measurementId: 'G-KJJ6V4JN7B',
  );
}
