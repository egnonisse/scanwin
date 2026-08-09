'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const POINTS_PER_TICKET = 10;

/**
 * Normalise un identifiant de ticket : trim, majuscules, sans espaces.
 * Retourne null si la valeur est invalide ou trop courte.
 */
function normalizeTicketId(value) {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toUpperCase().replace(/\s+/g, '');
  return normalized.length >= 4 ? normalized : null;
}

/**
 * Valide un montant optionnel (nombre positif fini).
 * Retourne le nombre ou null si absent.
 */
function parseMontant(value) {
  if (value === undefined || value === null || value === '') return null;
  const montant = Number(value);
  if (!Number.isFinite(montant) || montant < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Montant invalide.');
  }
  return montant;
}

/**
 * Valide une date optionnelle (ISO 8601 ou timestamp).
 * Retourne un Date ou null si absent.
 */
function parseDateTicket(value) {
  if (value === undefined || value === null || value === '') return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new functions.https.HttpsError('invalid-argument', 'Date invalide.');
  }
  return date;
}

/**
 * Crédite des points pour un ticket scanné.
 *
 * Gardien de l'unicité : la transaction échoue (already-exists)
 * si le ticket a déjà été scanné, quel que soit l'utilisateur.
 *
 * Structure écrite :
 * - scannedTickets/{ticketId}          : preuve d'unicité
 * - users/{uid}.points                 : incrément atomique
 * - users/{uid}/pointsEvents/{autoId}  : événement d'historique
 */
exports.creditPoints = functions.https.onCall(async (data, context) => {
  const userId = context.auth && context.auth.uid;
  if (!userId) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentification requise.'
    );
  }

  const ticketId = normalizeTicketId(data && data.ticketId);
  if (!ticketId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Numéro de ticket invalide.'
    );
  }

  const montant = parseMontant(data && data.montant);
  const dateTicket = parseDateTicket(data && data.dateTicket);

  const db = admin.firestore();
  const ticketRef = db.collection('scannedTickets').doc(ticketId);

  try {
    return await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(ticketRef);
      if (existing.exists) {
        throw new functions.https.HttpsError(
          'already-exists',
          'Ce ticket a déjà été scanné.'
        );
      }

      transaction.set(ticketRef, {
        scannedBy: userId,
        scannedAt: admin.firestore.FieldValue.serverTimestamp(),
        montant,
        dateTicket: dateTicket || null,
      });

      const userRef = db.collection('users').doc(userId);
      transaction.update(userRef, {
        points: admin.firestore.FieldValue.increment(POINTS_PER_TICKET),
      });

      transaction.set(userRef.collection('pointsEvents').doc(), {
        pointsAdded: POINTS_PER_TICKET,
        ticketId,
        amount: montant,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, pointsAdded: POINTS_PER_TICKET, ticketId };
    });
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    functions.logger.error('creditPoints failed', { userId, ticketId }, error);
    throw new functions.https.HttpsError(
      'internal',
      'Erreur interne. Réessaie dans un instant.'
    );
  }
});
