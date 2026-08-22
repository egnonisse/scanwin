'use strict';

const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions/logger');
const admin = require('firebase-admin');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

admin.initializeApp();

const db = getFirestore();

const POINTS_PER_RECEIPT = 10;

/** Normalise un nom (médicament, pharmacie) : minuscules, sans accents. */
function normalizeName(value) {
  if (typeof value !== 'string') return '';
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/** Hash déterministe du contenu d'un reçu (identifiant d'unicité). */
function hashReceipt({ pharmacyId, dateTicket, montant, items }) {
  const canonicalItems = (items || [])
    .map((item) => {
      const name = normalizeName(item && item.name);
      const price = Number(item && item.price);
      const quantity = Number((item && item.quantity) || 1);
      return `${name}|${Number.isFinite(price) ? price : 0}|${Number.isFinite(quantity) ? quantity : 1}`;
    })
    .filter((entry) => entry.startsWith('|') === false)
    .sort()
    .join('#');

  return crypto
    .createHash('sha256')
    .update([pharmacyId, dateTicket || '', montant ?? '', canonicalItems].join('||'))
    .digest('hex');
}

/** Valide et normalise un montant (nombre positif fini). */
function parseMontant(value) {
  if (value === undefined || value === null || value === '') return null;
  const montant = Number(value);
  if (!Number.isFinite(montant) || montant < 0) {
    throw new HttpsError('invalid-argument', 'Montant invalide.');
  }
  return montant;
}

/** Valide une date (ISO 8601 ou timestamp). Retourne un Date. */
function parseDateTicket(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError('invalid-argument', 'Date invalide.');
  }
  return date;
}

/** Valide et normalise la liste des lignes de médicaments. */
function parseItems(value) {
  if (!Array.isArray(value) || value.length === 0) {
    throw new HttpsError(
      'invalid-argument',
      'Le reçu doit contenir au moins une ligne de médicament.'
    );
  }

  return value.map((item) => {
    const name = normalizeName(item && item.name);
    if (name.length < 2) {
      throw new HttpsError(
        'invalid-argument',
        'Nom de médicament invalide.'
      );
    }
    const price = Number(item && item.price);
    if (!Number.isFinite(price) || price <= 0) {
      throw new HttpsError(
        'invalid-argument',
        `Prix invalide pour "${item && item.name}".`
      );
    }
    const quantity = Number((item && item.quantity) || 1);
    return {
      name,
      price,
      quantity: Number.isFinite(quantity) && quantity > 0 ? quantity : 1,
    };
  });
}

/** Slug d'un nom de pharmacie (identifiant stable dans Firestore). */
function slugify(value) {
  return normalizeName(value).replace(/\s+/g, '-');
}

/**
 * Soumet un reçu de pharmacie scanné : écrit le reçu (unicité par hash),
 * la table de recherche des prix, et crédite les points.
 *
 * Structure écrite :
 * - pharmacies/{slug}                 : créée si absente (nom seul au MVP)
 * - receipts/{hash}                   : archive du reçu (items en tableau)
 * - priceEntries/{autoId}             : 1 document par ligne (recherche prix)
 * - users/{uid}.points                : incrément atomique
 * - users/{uid}/pointsEvents/{autoId} : événement d'historique
 */
exports.submitReceipt = onCall(async (request) => {
  const data = request.data || {};
  const userId = request.auth && request.auth.uid;
  logger.info('submitReceipt called', {
    hasAuth: Boolean(request.auth),
    authKeys: request.auth ? Object.keys(request.auth) : null,
    uid: userId,
  });
  if (!userId) {
    throw new HttpsError(
      'unauthenticated',
      'Authentification requise.'
    );
  }

  const pharmacyName = typeof data.pharmacyName === 'string'
    ? data.pharmacyName.trim()
    : '';
  if (!pharmacyName) {
    throw new HttpsError(
      'invalid-argument',
      'Pharmacie manquante.'
    );
  }
  const pharmacyId = slugify(pharmacyName);

  const montant = parseMontant(data.montant);
  if (montant === null || montant === 0) {
    throw new HttpsError(
      'invalid-argument',
      'Montant total requis.'
    );
  }

  const dateTicket = parseDateTicket(data.dateTicket);
  const items = parseItems(data.items);

  const receiptId = hashReceipt({ pharmacyId, dateTicket, montant, items });

  // Déplace la photo du reçu (uploadée en pending/ par le client) vers
  // receipts/{hash}.jpg — hors transaction (opération Storage).
  let photoPath = null;
  const storageBucket = getStorage().bucket();
  const pendingPhoto = typeof data.photoPath === 'string'
    ? data.photoPath
    : null;
  if (pendingPhoto && pendingPhoto.startsWith('pending/')) {
    const srcFile = storageBucket.file(pendingPhoto);
    const [srcExists] = await srcFile.exists();
    if (srcExists) {
      const destPath = `receipts/${receiptId}.jpg`;
      await srcFile.copy(destPath);
      await srcFile.delete();
      photoPath = destPath;
    }
  }

  const receiptRef = db.collection('receipts').doc(receiptId);

  try {
    return await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(receiptRef);
      if (existing.exists) {
        throw new HttpsError(
          'already-exists',
          'Ce reçu a déjà été soumis.'
        );
      }

      // Crée la pharmacie si elle n'existe pas encore (nom seul au MVP).
      const pharmacyRef = db.collection('pharmacies').doc(pharmacyId);
      const pharmacyDoc = await transaction.get(pharmacyRef);
      if (!pharmacyDoc.exists) {
        transaction.set(pharmacyRef, {
          name: pharmacyName,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.set(receiptRef, {
        pharmacyId,
        scannedBy: userId,
        scannedAt: FieldValue.serverTimestamp(),
        dateTicket: Timestamp.fromDate(dateTicket),
        montant,
        itemCount: items.length,
        items,
        // Un reçu soumis par l'app est validé d'office (corrigeable ensuite
        // par l'admin : la correction régénère les priceEntries).
        status: 'validated',
        ...(photoPath !== null ? { photoPath } : {}),
      });

      // Table de recherche prix (1 document par ligne de médicament).
      items.forEach((item) => {
        transaction.set(db.collection('priceEntries').doc(), {
          medicationName: item.name,
          pharmacyId,
          // Dénormalisé pour l'affichage direct dans la recherche (pas de N+1).
          pharmacyName,
          price: item.price,
          quantity: item.quantity,
          scannedAt: FieldValue.serverTimestamp(),
          receiptId,
        });
      });

      const userRef = db.collection('users').doc(userId);
      transaction.update(userRef, {
        points: FieldValue.increment(POINTS_PER_RECEIPT),
        // Compteur de contribution (reçus validés) — alimente le statut
        // contributeur (Bronze/Argent/Or) affiché dans la home.
        contributions: FieldValue.increment(1),
      });

      transaction.set(userRef.collection('pointsEvents').doc(), {
        pointsAdded: POINTS_PER_RECEIPT,
        receiptId,
        montant,
        createdAt: FieldValue.serverTimestamp(),
      });

      return { success: true, pointsAdded: POINTS_PER_RECEIPT, receiptId };
    });
  } catch (error) {
    if (error instanceof HttpsError) {
      // La photo a été copiée avant la transaction : la nettoyer si la
      // soumission a échoué (ex: reçu déjà soumis).
      if (photoPath !== null) {
        try {
          await storageBucket.file(photoPath).delete();
        } catch (_) { /* best effort */ }
      }
      throw error;
    }
    logger.error('submitReceipt failed', { userId }, error);
    throw new HttpsError(
      'internal',
      'Erreur interne. Réessaie dans un instant.'
    );
  }
});

const ADMIN_EMAILS = ['egnonisse@gmail.com', 'tobossinonleonard@gmail.com'];

/** Déclencheur : le dashboard écrit un doc dans pushRequests → on envoie le
 *  push FCM à tous les utilisateurs et on écrit le résultat dans le doc
 *  (pattern Firestore, fiable sur web — évite le bug Int64 de
 *  cloud_functions/dart2js). */
exports.sendPushOnRequest = onDocumentCreated('pushRequests/{requestId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const data = snapshot.data();
  const { title, body, imageUrl } = data || {};
  if (typeof title !== 'string' || title.trim().length === 0 ||
      typeof body !== 'string' || body.trim().length === 0) {
    await snapshot.ref.set(
      { status: 'error', error: 'Titre et message requis.', sent: 0, failed: 0 },
      { merge: true }
    );
    return;
  }

  try {
    // Récupérer tous les tokens FCM enregistrés.
    const usersSnapshot = await db.collection('users').get();
    const tokens = [];
    for (const doc of usersSnapshot.docs) {
      const token = doc.data().fcmToken;
      if (typeof token === 'string' && token.length > 0) {
        tokens.push(token);
      }
    }

    if (tokens.length === 0) {
      await snapshot.ref.set(
        { status: 'done', sent: 0, failed: 0, message: 'Aucun appareil enregistré.' },
        { merge: true }
      );
      return;
    }

    const payload = {
      notification: { title: title.trim(), body: body.trim() },
      data: imageUrl && typeof imageUrl === 'string' ? { imageUrl } : {},
      android: { priority: 'high' },
    };

    let sent = 0;
    let failed = 0;
    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      const result = await admin.messaging().sendEachForMulticast({
        tokens: batch,
        ...payload,
      });
      sent += result.successCount;
      failed += result.failureCount;
    }

    logger.info('sendPushOnRequest', { sent, failed });
    await snapshot.ref.set(
      { status: 'done', sent, failed, completedAt: Timestamp.now() },
      { merge: true }
    );
  } catch (error) {
    logger.error('sendPushOnRequest failed', error);
    await snapshot.ref.set(
      { status: 'error', error: 'Erreur interne.', sent: 0, failed: 0 },
      { merge: true }
    );
  }
});

// ---------------------------------------------------------------------------
// Structuration des reçus par IA : l'OCR mobile est bruité sur les reçus
// thermiques → un LLM reconstruit montants, dates, items, quantités à partir
// du texte brut. L'IMAGE n'est jamais envoyée ici (texte seul).
//
// Le provider, le modèle et la clé sont paramétrés depuis le DASHBOARD
// (collection aiSettings, admin uniquement). Formats supportés :
// API OpenAI-compatible (DeepSeek, OpenAI, proxys custom via baseUrl).
// ---------------------------------------------------------------------------

const PARSE_SYSTEM_PROMPT = `Tu es un extracteur de reçus de pharmacie ivoiriens.
Tu reçois le texte brut d'un reçu (OCR imparfait : fautes, espaces cassés,
chiffres mal lus). Reconstruis-le en JSON STRICT, sans commentaire, avec ces
champs exacts :
{
  "pharmacyName": "nom de la pharmacie (sans le mot pharmacie si possible)",
  "dateTicket": "JJ/MM/AAAA ou null si introuvable",
  "heure": "HH:MM ou null",
  "items": [{"name": "nom médicament (sans dosage si illisible)", "qty": nombre, "price": nombre entier FCFA}],
  "total": nombre entier FCFA ou null,
  "confiance": "haute|moyenne|faible"
}
Règles :
- Les prix ivoiriens sont en FCFA : "2.400" ou "2 400" → 2400 (entier, sans
  virgule). "1.500F" → 1500.
- Si un montant semble aberrant (ex: 24000 au lieu de 2400) et qu'il y a un
  total cohérent, corrige avec le total.
- Ignore les lignes hors médicaments (adresse, téléphone, TVA, merci).
- Si le texte est illisible, renvoie confiance "faible" avec le meilleur
  effort.
- Réponds UNIQUEMENT le JSON (pas de markdown, pas d'explication).`;

const DEFAULT_AI_URLS = {
  deepseek: 'https://api.deepseek.com/chat/completions',
  openai: 'https://api.openai.com/v1/chat/completions',
};

/** Lit les réglages IA depuis Firestore (aiSettings/default). */
async function loadAiSettings() {
  const doc = await db.collection('aiSettings').doc('default').get();
  if (!doc.exists) return null;
  const data = doc.data();
  return {
    enabled: data.enabled !== false,
    provider: typeof data.provider === 'string' ? data.provider : 'deepseek',
    baseUrl: typeof data.baseUrl === 'string' && data.baseUrl.trim()
      ? data.baseUrl.trim()
      : null,
    model: typeof data.model === 'string' && data.model.trim()
      ? data.model.trim()
      : 'deepseek-chat',
    apiKey: typeof data.apiKey === 'string' ? data.apiKey.trim() : '',
  };
}

exports.parseReceiptWithAI = onCall(
  { timeoutSeconds: 45 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Connexion requise.');
    }

    const rawText = request.data && request.data.rawText;
    if (typeof rawText !== 'string' || rawText.trim().length < 20) {
      throw new HttpsError('invalid-argument', 'Texte du reçu requis.');
    }

    const cfg = await loadAiSettings();
    if (!cfg || !cfg.enabled || !cfg.apiKey) {
      throw new HttpsError(
        'failed-precondition',
        'IA non configurée. Configure-la depuis le dashboard.'
      );
    }

    const url = cfg.baseUrl || DEFAULT_AI_URLS[cfg.provider] || DEFAULT_AI_URLS.deepseek;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${cfg.apiKey}`,
      },
      body: JSON.stringify({
        model: cfg.model,
        messages: [
          { role: 'system', content: PARSE_SYSTEM_PROMPT },
          { role: 'user', content: rawText.trim().slice(0, 6000) },
        ],
        temperature: 0,
        max_tokens: 1200,
        response_format: { type: 'json_object' },
      }),
    });

    if (!response.ok) {
      logger.error('parseReceiptWithAI DeepSeek HTTP', response.status);
      throw new HttpsError('internal', 'Analyse IA indisponible.');
    }

    const body = await response.json();
    const content = body && body.choices && body.choices[0]
      && body.choices[0].message ? body.choices[0].message.content : '';

    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      logger.error('parseReceiptWithAI JSON parse failed', content);
      throw new HttpsError('internal', 'Analyse IA invalide.');
    }

    // Nettoyage : types corrects.
    const items = (Array.isArray(parsed.items) ? parsed.items : [])
      .map((item) => ({
        name: String(item.name || '').trim(),
        qty: Number(item.qty) || 1,
        price: Math.round(Number(item.price)) || 0,
      }))
      .filter((item) => item.name.length > 0 && item.price > 0);

    return {
      pharmacyName: String(parsed.pharmacyName || '').trim(),
      dateTicket: parsed.dateTicket || null,
      heure: parsed.heure || null,
      items,
      total: parsed.total ? Math.round(Number(parsed.total)) : null,
      confiance: parsed.confiance || 'moyenne',
    };
  }
);
