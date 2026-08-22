// Repro exacte de sendPushOnRequest (Node, firebase-admin local).
const path = require('path');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

admin.initializeApp({
  credential: admin.credential.cert(require(path.join(__dirname, '..', 'play', 'firebase-adminsdk.json'))),
});

const { getFirestore } = require('firebase-admin/firestore');
const db = getFirestore();

(async () => {
  const usersSnapshot = await db.collection('users').get();
  const tokens = [];
  for (const doc of usersSnapshot.docs) {
    const token = doc.data().fcmToken;
    if (typeof token === 'string' && token.length > 0) tokens.push(token);
  }
  console.log('tokens:', tokens.length);

  const payload = {
    notification: { title: 'repro node', body: 'repro node' },
    android: { priority: 'high' },
  };

  try {
    const result = await admin.messaging().sendEachForMulticast({
      tokens,
      ...payload,
    });
    console.log('OK success:', result.successCount, 'failure:', result.failureCount);
    for (const resp of result.responses) {
      console.log('  response:', resp.messageId || resp.error);
    }
  } catch (e) {
    console.log('EXCEPTION:', e.message, '\n', JSON.stringify(e, null, 1).slice(0, 500));
  }
  process.exit(0);
})();
