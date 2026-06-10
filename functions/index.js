const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Sunucu tarafında otomatik yetkilendirme (Daha güvenli ve hatasız)
admin.initializeApp();

exports.adminChangeUserPassword = onCall(async (request) => {
  // 1. Check if caller is authenticated
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
  }

  // 2. Check if caller is admin (based on email - constants dosyasındaki adminEmail ile eşleşmeli)
  const adminEmail = 'fatihkull17@gmail.com';
  if (request.auth.token.email !== adminEmail) {
    throw new HttpsError('permission-denied', 'Bu işlem için yetkiniz yok.');
  }

  const { uid, newPassword } = request.data;

  if (!uid || !newPassword) {
    throw new HttpsError('invalid-argument', 'UID ve Yeni Şifre zorunludur.');
  }

  if (newPassword.length < 6) {
    throw new HttpsError('invalid-argument', 'Şifre en az 6 karakter olmalıdır.');
  }

  try {
    await admin.auth().updateUser(uid, {
      password: newPassword
    });
    console.log(`Admin (${request.auth.token.email}) kullanıcı (${uid}) şifresini değiştirdi.`);

    // Log Admin Action
    await admin.firestore().collection('admin_logs').add({
      action: 'password_change',
      adminEmail: request.auth.token.email,
      targetUid: uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: 'Admin tarafından manuel şifre değişikliği yapıldı.'
    });

    return { message: 'Şifre başarıyla güncellendi.' };
  } catch (error) {
    console.error('Şifre değiştirme hatası:', error);
    throw new HttpsError('internal', error.message);
  }
});

exports.adminVerifyUserEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
  }

  const adminEmail = 'fatihkull17@gmail.com';
  if (request.auth.token.email !== adminEmail) {
    throw new HttpsError('permission-denied', 'Bu işlem için yetkiniz yok.');
  }

  const { uid } = request.data;
  if (!uid) {
    throw new HttpsError('invalid-argument', 'UID zorunludur.');
  }

  try {
    await admin.auth().updateUser(uid, { emailVerified: true });
    await admin.firestore().collection('users').doc(uid).update({ 'emailVerified': true });

    // Log Admin Action
    await admin.firestore().collection('admin_logs').add({
      action: 'email_verify',
      adminEmail: request.auth.token.email,
      targetUid: uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { message: 'E-posta başarıyla onaylandı.' };
  } catch (error) {
    console.error('E-posta onaylama hatası:', error);
    throw new HttpsError('internal', error.message);
  }
});

// YENİ: Kullanıcı Verilerini Güvenli ve Toplu Silme (Wipe)
exports.adminWipeUserData = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Giriş gerekli.');

  const adminEmail = 'fatihkull17@gmail.com';
  if (request.auth.token.email !== adminEmail) throw new HttpsError('permission-denied', 'Yetkisiz erişim.');

  const { uid } = request.data;
  const db = admin.firestore();

  try {
    const batch = db.batch();

    // 1. Kullanıcı yorumlarını bul ve sil (Toplu)
    const comments = await db.collectionGroup('comments').where('userId', '==', uid).get();
    comments.forEach(doc => batch.delete(doc.ref));

    // 2. Kullanıcının verdiği oyları sil
    const ratings = await db.collection('ratings').where('fromId', '==', uid).get();
    ratings.forEach(doc => batch.delete(doc.ref));

    // 3. Kullanıcıya verilen oyları sil
    const targetRatings = await db.collection('ratings').where('toId', '==', uid).get();
    targetRatings.forEach(doc => batch.delete(doc.ref));

    // 4. Kullanıcı dokümanını sil
    batch.delete(db.collection('users').doc(uid));

    await batch.commit();

    // 5. Firebase Auth Hesabını sil
    await admin.auth().deleteUser(uid);

    // Log action
    await db.collection('admin_logs').add({
      action: 'wipe_data',
      adminEmail: request.auth.token.email,
      targetUid: uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { message: 'Kullanıcı ve tüm ilişkili veriler başarıyla silindi.' };
  } catch (error) {
    console.error('Wipe hatası:', error);
    throw new HttpsError('internal', error.message);
  }
});

// YENİ: Otomatik Küfür ve Yasaklı Kelime Filtresi
exports.moderateComment = onDocumentCreated("events/{eventId}/comments/{commentId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return null;
  const data = snapshot.data();
  const text = (data.text || "").toLowerCase();

  // Basit bir yasaklı kelime listesi (Admin panelinden dinamik hale getirilebilir)
  const forbiddenWords = ["küfür1", "argo2", "spamlink", "hakaret"];

  const containsForbidden = forbiddenWords.some(word => text.includes(word));

  if (containsForbidden) {
    console.log(`Yasaklı içerik tespit edildi: ${snapshot.id}`);
    return snapshot.ref.update({
      text: "Bu mesaj topluluk kuralları gereği gizlenmiştir. ⚠️",
      isAutoModerated: true,
      originalText: data.text // Admin incelemesi için saklanabilir
    });
  }
  return null;
});

exports.archivePastEvents = onSchedule("every 1 hours", async (event) => {
  const now = admin.firestore.Timestamp.now();
  const db = admin.firestore();

  try {
    const expiredEvents = await db.collection("events")
      .where("eventDate", "<", now)
      .where("isArchived", "==", false)
      .get();

    if (expiredEvents.empty) {
      console.log("Arşivlenecek etkinlik bulunamadı.");
      return null;
    }

    const batch = db.batch();
    expiredEvents.forEach((doc) => {
      batch.update(doc.ref, { isArchived: true });
    });

    await batch.commit();
    console.log(`${expiredEvents.size} etkinlik başarıyla arşivlendi.`);
  } catch (error) {
    console.error("Etkinlikler arşivlenirken hata oluştu:", error);
  }
});

exports.sendPushNotification = onDocumentCreated("push_notifications/{docId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return null;

  const data = snapshot.data();
  if (!data || !data.to) return null;

  const message = {
    notification: {
      title: data.notification.title || 'Eventful',
      body: data.notification.body || ''
    },
    data: data.data || {},
    android: {
      priority: 'high',
      notification: {
        channelId: 'event_channel'
      }
    }
  };

  // Support for both tokens and topics
  if (data.to.startsWith('/topics/')) {
    message.topic = data.to.replace('/topics/', '');
  } else {
    message.token = data.to;
  }

  try {
    const response = await admin.messaging().send(message);
    console.log('Bildirim başarıyla gönderildi:', event.params.docId, 'MessageId:', response);
    return snapshot.ref.update({
      status: 'sent',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      messageId: response
    });
  } catch (error) {
    console.error('Bildirim gönderilirken hata oluştu:', error);
    return snapshot.ref.update({
      status: 'error',
      error: error.message,
      failedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
});
