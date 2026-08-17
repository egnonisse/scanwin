'use strict';

const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
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
