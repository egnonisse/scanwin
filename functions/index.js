'use strict';

const crypto = require('crypto');
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

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
    throw new functions.https.HttpsError('invalid-argument', 'Montant invalide.');
  }
  return montant;
}

/** Valide une date (ISO 8601 ou timestamp). Retourne un Date. */
function parseDateTicket(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new functions.https.HttpsError('invalid-argument', 'Date invalide.');
  }
  return date;
}

/** Valide et normalise la liste des lignes de médicaments. */
function parseItems(value) {
  if (!Array.isArray(value) || value.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Le reçu doit contenir au moins une ligne de médicament.'
    );
  }

  return value.map((item) => {
    const name = normalizeName(item && item.name);
    if (name.length < 2) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Nom de médicament invalide.'
      );
    }
    const price = Number(item && item.price);
    if (!Number.isFinite(price) || price <= 0) {
      throw new functions.https.HttpsError(
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
exports.submitReceipt = functions.https.onCall(async (data, context) => {
  const userId = context.auth && context.auth.uid;
  if (!userId) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentification requise.'
    );
  }

  const pharmacyName = data && typeof data.pharmacyName === 'string'
    ? data.pharmacyName.trim()
    : '';
  if (!pharmacyName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Pharmacie manquante.'
    );
  }
  const pharmacyId = slugify(pharmacyName);

  const montant = parseMontant(data && data.montant);
  if (montant === null || montant === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Montant total requis.'
    );
  }

  const dateTicket = parseDateTicket(data && data.dateTicket);
  const items = parseItems(data && data.items);

  const receiptId = hashReceipt({ pharmacyId, dateTicket, montant, items });

  const db = admin.firestore();
  const receiptRef = db.collection('receipts').doc(receiptId);

  try {
    return await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(receiptRef);
      if (existing.exists) {
        throw new functions.https.HttpsError(
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
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      transaction.set(receiptRef, {
        pharmacyId,
        scannedBy: userId,
        scannedAt: admin.firestore.FieldValue.serverTimestamp(),
        dateTicket: admin.firestore.Timestamp.fromDate(dateTicket),
        montant,
        itemCount: items.length,
        items,
      });

      // Table de recherche prix (1 document par ligne de médicament).
      items.forEach((item) => {
        transaction.set(db.collection('priceEntries').doc(), {
          medicationName: item.name,
          pharmacyId,
          price: item.price,
          quantity: item.quantity,
          scannedAt: admin.firestore.FieldValue.serverTimestamp(),
          receiptId,
        });
      });

      const userRef = db.collection('users').doc(userId);
      transaction.update(userRef, {
        points: admin.firestore.FieldValue.increment(POINTS_PER_RECEIPT),
      });

      transaction.set(userRef.collection('pointsEvents').doc(), {
        pointsAdded: POINTS_PER_RECEIPT,
        receiptId,
        montant,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, pointsAdded: POINTS_PER_RECEIPT, receiptId };
    });
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    functions.logger.error('submitReceipt failed', { userId }, error);
    throw new functions.https.HttpsError(
      'internal',
      'Erreur interne. Réessaie dans un instant.'
    );
  }
});
