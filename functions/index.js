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

    // 5. Firebase Auth Hesabını sil (Eğer kullanıcı zaten silinmişse hatayı görmezden gel)
    try {
      await admin.auth().deleteUser(uid);
    } catch (authError) {
      if (authError.code !== 'auth/user-not-found') {
        console.error('Auth silme hatası:', authError);
        // User not found değilse kritik bir hatadır, fırlatabiliriz ama veriler silindiği için devam da edebiliriz.
      }
    }

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

exports.onEventCreated = onDocumentCreated("events/{eventId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return null;

  const eventData = snapshot.data();
  const creatorId = eventData.creatorId;
  const eventTitle = eventData.title || "Yeni Etkinlik";

  if (!creatorId) return null;

  const db = admin.firestore();

  try {
    // 1. Get creator info
    const creatorDoc = await db.collection("users").doc(creatorId).get();
    const creatorName = creatorDoc.data()?.username || creatorDoc.data()?.name || "Takip ettiğin biri";

    // 2. Get followers
    const userDoc = await db.collection("users").doc(creatorId).get();
    const followers = userDoc.data()?.followers || [];

    if (followers.length === 0) return null;

    // 3. Create entries for each follower
    const batch = db.batch();
    followers.forEach((followerId) => {
      // In-app notification
      const inAppNotifRef = db.collection("users").doc(followerId).collection("notifications").doc();
      batch.set(inAppNotifRef, {
        type: "new_event_from_following",
        senderId: creatorId,
        senderName: creatorName,
        content: `yeni bir etkinlik oluşturdu: ${eventTitle}`,
        relatedId: event.params.eventId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      });

      // Push notification
      const pushNotifRef = db.collection("push_notifications").doc();
      batch.set(pushNotifRef, {
        recipientId: followerId,
        notification: {
          title: "Yeni Etkinlik! 🆕",
          body: `${creatorName} yeni bir etkinlik oluşturdu: ${eventTitle}`,
        },
        data: {
          type: "new_event_from_following",
          eventId: event.params.eventId,
          creatorId: creatorId,
        },
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        fcmVersion: "v1",
      });
    });

    await batch.commit();
    console.log(`${followers.length} takipçiye hem uygulama içi hem push bildirim kuyruğa alındı.`);
  } catch (error) {
    console.error("onEventCreated hatası:", error);
  }
});

exports.checkUpcomingEvents = onSchedule("every 15 minutes", async (event) => {
  const now = admin.firestore.Timestamp.now();
  const thirtyMinsLater = admin.firestore.Timestamp.fromMillis(now.toMillis() + 30 * 60 * 1000);
  const fortyFiveMinsLater = admin.firestore.Timestamp.fromMillis(now.toMillis() + 45 * 60 * 1000);

  const db = admin.firestore();

  try {
    const upcomingEvents = await db.collection("events")
      .where("eventDate", ">", thirtyMinsLater)
      .where("eventDate", "<", fortyFiveMinsLater)
      .where("isApproved", "==", true)
      .where("isArchived", "==", false)
      .get();

    if (upcomingEvents.empty) return null;

    const batch = db.batch();
    upcomingEvents.forEach((doc) => {
      const eventData = doc.data();
      const participants = eventData.participants || [];
      const eventTitle = eventData.title;

      participants.forEach((uid) => {
        // In-app notification
        const inAppNotifRef = db.collection("users").doc(uid).collection("notifications").doc();
        batch.set(inAppNotifRef, {
          type: "event_reminder",
          title: "Etkinlik Yaklaşıyor! ⏰",
          content: `"${eventTitle}" etkinliği yaklaşıyor. Hazır mısın?`,
          eventId: doc.id,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
        });

        // Push notification
        const pushNotifRef = db.collection("push_notifications").doc();
        batch.set(pushNotifRef, {
          recipientId: uid,
          notification: {
            title: "Etkinlik Yaklaşıyor! ⏰",
            body: `"${eventTitle}" etkinliği yaklaşıyor. Hazır mısın?`,
          },
          data: {
            type: "event_reminder",
            eventId: doc.id,
          },
          status: "pending",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          fcmVersion: "v1",
        });
      });
    });

    await batch.commit();
    console.log("Yaklaşan etkinlik bildirimleri gönderildi.");
  } catch (error) {
    console.error("checkUpcomingEvents hatası:", error);
  }
});

exports.dailyCityReminder = onSchedule("every day 10:00", async (event) => {
  const db = admin.firestore();

  try {
    // Tüm kullanıcılara veya aktif kullanıcılara genel bir "Göz at" bildirimi
    // Alternatif: /topics/all_users kullanmak daha verimli
    const notifRef = db.collection("push_notifications").doc();
    await notifRef.set({
      to: "/topics/all_users",
      notification: {
        title: "Bugün Neler Var? 🔍",
        body: "Şehrindeki yeni etkinlikleri kaçırma, hemen göz at!",
      },
      data: {
        type: "daily_reminder",
      },
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      fcmVersion: "v1",
    });
    console.log("Günlük hatırlatma kuyruğa alındı.");
  } catch (error) {
    console.error("dailyCityReminder hatası:", error);
  }
});

exports.sendPushNotification = onDocumentCreated("push_notifications/{docId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return null;

  const data = snapshot.data();
  if (!data) return null;

  let targetToken = data.to;

  // If no 'to' but 'recipientId', fetch user's FCM token
  if (!targetToken && data.recipientId) {
    try {
      const userDoc = await admin.firestore().collection("users").doc(data.recipientId).get();
      targetToken = userDoc.data()?.fcmToken;
    } catch (e) {
      console.error("Token fetch error:", e);
    }
  }

  if (!targetToken) {
    console.log("Hedef token bulunamadı, bildirim iptal edildi:", event.params.docId);
    return snapshot.ref.update({ status: 'error', error: 'No token found' });
  }

  const message = {
    notification: {
      title: data.notification.title || 'Eventful',
      body: data.notification.body || ''
    },
    data: (data.data || {}).map ? data.data : (data.data || {}), // Ensure it's a map
    android: {
      priority: 'high',
      notification: {
        channelId: 'event_channel'
      }
    }
  };

  // Ensure all data values are strings (FCM V1 requirement)
  if (message.data) {
    Object.keys(message.data).forEach(key => {
      message.data[key] = String(message.data[key]);
    });
  }

  // Support for both tokens and topics
  if (targetToken.startsWith('/topics/')) {
    message.topic = targetToken.replace('/topics/', '');
  } else {
    message.token = targetToken;
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
