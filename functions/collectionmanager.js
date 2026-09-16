
const functions = require("firebase-functions");
const { admin, db } = require("./fb");

// Collections you never want touched from this tool, even by a super admin
// (adjust to match your app — e.g. keep audit logs / config safe).
const PROTECTED_COLLECTIONS = ["_config", "audit_logs"];

// Field names your collections use, inconsistently, to store the
// owning company's id. We check each one per collection.
const COMPANY_FIELD_VARIANTS = ["companyId", "companyID", "companied"];

async function getCallerProfile(context) {
  const email = context.auth.token.email;
  if (!email) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Signed-in account has no email on its auth token."
    );
  }
  const snap = await db.collection("staff").doc(email).get();
  if (!snap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "No staff profile found for this account."
    );
  }
  return snap.data();
}

function assertIsSuperAdmin(profile) {
  if (profile.accessLevel !== "super admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only super admins can perform this action."
    );
  }
}

/**
 * Callable: listFirestoreCollections
 * Returns the names of all top-level collections.
 */
exports.listFirestoreCollections = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  // Anyone signed in can *view* the list; only super admins can delete.
  // (Tighten this to assertIsSuperAdmin if you want the list itself gated too.)
  const collections = await db.listCollections();
  return {
    collections: collections.map((c) => c.id).sort(),
  };
});

/**
 * Callable: clearFirestoreCollections
 * data: { collectionNames: string[], staffId: string }
 *
 * Re-validates on the server:
 *  1. Caller is authenticated
 *  2. Caller's accessLevel === 'super admin'
 *  3. The staffId passed in matches the caller's own staffId
 *     (defense in depth against a hijacked client sending a stale/forged call)
 *
 * For each requested collection, deletes ONLY the documents whose
 * companyId / companyID / companied field equals the caller's own
 * companyId. Documents belonging to other companies are never touched.
 */
exports.clearFirestoreCollections = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const { collectionNames, staffId } = data;

  if (!Array.isArray(collectionNames) || collectionNames.length === 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "collectionNames must be a non-empty array."
    );
  }
  if (!staffId || typeof staffId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "staffId is required."
    );
  }

  const profile = await getCallerProfile(context);
  assertIsSuperAdmin(profile);

  if (profile.staffId !== staffId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Staff ID does not match the signed-in account."
    );
  }

  // NOTE: field is "companyid" (lowercase) to match the staff document
  // schema used by the Flutter client. If you rename the field in
  // Firestore, update this alongside collection_manager_page.dart.
  const companyId = profile.companyid;
  if (!companyId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Your staff profile has no companyid set — cannot scope deletion."
    );
  }

  const blocked = collectionNames.filter((c) => PROTECTED_COLLECTIONS.includes(c));
  if (blocked.length > 0) {
    throw new functions.https.HttpsError(
      "permission-denied",
      `These collections are protected and cannot be cleared: ${blocked.join(", ")}`
    );
  }

  const results = {};
  for (const name of collectionNames) {
    results[name] = await deleteCompanyDocs(name, companyId, 300);
  }

  // Optional: audit trail of who wiped what and when
  await db.collection("audit_logs").add({
    action: "clear_company_documents",
    performedBy: context.auth.uid,
    performedByEmail: context.auth.token.email,
    staffId,
    companyId,
    collections: collectionNames,
    deletedCounts: results,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { deletedCounts: results };
});

/**
 * Deletes documents in `collectionPath` whose company field matches
 * `companyId`, checking each field-name variant in
 * COMPANY_FIELD_VARIANTS in turn. Returns the total number of
 * documents deleted (deduplicated by doc path, in case a document
 * somehow matched more than one variant).
 */
async function deleteCompanyDocs(collectionPath, companyId, batchSize) {
  const collectionRef = db.collection(collectionPath);
  const deletedPaths = new Set();

  for (const field of COMPANY_FIELD_VARIANTS) {
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const snapshot = await collectionRef
        .where(field, "==", companyId)
        .limit(batchSize)
        .get();

      if (snapshot.empty) break;

      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
        deletedPaths.add(doc.ref.path);
      });
      await batch.commit();

      if (snapshot.size < batchSize) break;
    }
  }

  return deletedPaths.size;
}