const admin = require("firebase-admin");

const {
  initializeApp,
  getApps,
} = require("firebase-admin/app");

const {
  getFirestore,
  FieldValue,
  FieldPath,
  Timestamp,
} = require("firebase-admin/firestore");

// Initialize Firebase once
if (getApps().length === 0) {
  initializeApp();
}

// Get Firestore instance
const db = getFirestore();

/*
 * ------------------------------------------------------------------
 * BACKWARD COMPATIBILITY FOR EXISTING CODE
 * ------------------------------------------------------------------
 *
 * Existing project code uses:
 *
 *   admin.firestore()
 *   admin.firestore.FieldValue.increment()
 *   admin.firestore.FieldValue.serverTimestamp()
 *   admin.firestore.FieldPath
 *   admin.firestore.Timestamp
 *
 * Firebase Admin SDK v14 exposes these through modular APIs.
 * This restores the namespace expected by the existing code.
 * ------------------------------------------------------------------
 */

const firestoreCompat = function () {
  return db;
};

firestoreCompat.FieldValue = FieldValue;
firestoreCompat.FieldPath = FieldPath;
firestoreCompat.Timestamp = Timestamp;

admin.firestore = firestoreCompat;

module.exports = {
  admin,
  db,
};