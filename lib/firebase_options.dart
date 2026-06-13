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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBR9xopMqOuvTgAuohhs9qam3AmncRvpSI',
    appId: '1:327687814157:android:e6707946a25753814f2944',
    messagingSenderId: '327687814157',
    projectId: 'eventful-f579a',
    storageBucket: 'eventful-f579a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBR9xopMqOuvTgAuohhs9qam3AmncRvpSI',
    appId: '1:327687814157:ios:1ee1c921bc1d2aca4f2944',
    messagingSenderId: '327687814157',
    projectId: 'eventful-f579a',
    storageBucket: 'eventful-f579a.firebasestorage.app',
    iosBundleId: 'com.appeventful.eventful',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBR9xopMqOuvTgAuohhs9qam3AmncRvpSI',
    appId: '1:327687814157:web:1ee1c921bc1d2aca4f2944',
    messagingSenderId: '327687814157',
    projectId: 'eventful-f579a',
    storageBucket: 'eventful-f579a.firebasestorage.app',
  );
}
