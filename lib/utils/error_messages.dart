import 'package:firebase_auth/firebase_auth.dart';

class ErrorMessages {
  static String parseAuthError(dynamic e) {
    if (e == null) return 'Bilinmeyen bir hata oluştu.';
    
    // Eğer hata zaten bir açıklama metni (String) ise doğrudan döndür
    if (e is String && e.isNotEmpty) return e;

    String errorCode = "";
    
    if (e is FirebaseAuthException) {
      errorCode = e.code;
    } else if (e.toString().contains(']')) {
      // Firebase'den gelen ham hata formatını ayıkla: [firebase_auth/email-already-in-use] ...
      errorCode = e.toString().split(']').first.split('/').last;
    } else {
      // Diğer tipteki hataları (örn: Firestore, Storage) okunabilir hale getir
      String errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission-denied')) return 'Yetki hatası: Veritabanına erişim reddedildi.';
      if (errorStr.contains('unavailable')) return 'Servis şu an kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
      if (errorStr.contains('network')) return 'İnternet bağlantısı hatası oluştu.';
      return 'Bir hata oluştu: ${e.toString()}';
    }

    switch (errorCode) {
      case 'invalid-credential':
        return 'E-posta adresi veya şifre hatalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme yaptınız. Güvenliğiniz için erişiminiz geçici olarak kısıtlandı. Lütfen birkaç dakika bekleyin.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten başka bir hesap tarafından kullanılıyor.';
      case 'invalid-email':
        return 'Geçersiz bir e-posta adresi girdiniz.';
      case 'weak-password':
        return 'Şifre çok zayıf. Lütfen en az 6 karakterli daha güçlü bir şifre seçin.';
      case 'user-not-found':
        return 'Bu e-posta adresi ile kayıtlı bir kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Girdiğiniz şifre hatalı.';
      case 'network-request-failed':
        return 'İnternet bağlantısı kurulamadı. Lütfen bağlantınızı kontrol edin.';
      case 'operation-not-allowed':
        return 'Bu işlem şu an devre dışı bırakılmış.';
      case 'channel-error':
        return 'Lütfen tüm alanları eksiksiz doldurun.';
      default:
        return 'İşlem başarısız: $errorCode';
    }
  }
}
