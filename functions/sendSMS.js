const { onCall, HttpsError } =
  require("firebase-functions/v2/https");

const { onDocumentCreated } =
  require("firebase-functions/v2/firestore");

const https = require("https");
const querystring = require("querystring");

const { admin, db } = require("./fb");

// ================================================================
// SMS CONFIG
// ================================================================

async function resolveSmsConfig(companyId, fallbackSenderId) {
  const normalizedCompanyId =
    String(companyId || "").trim();

  if (!normalizedCompanyId) {
    return {
      apiKey:
        process.env.KOLOGSMS_API_KEY ||
        process.env.SMS_API_KEY ||
        "",

      senderid:
        fallbackSenderId || "",
    };
  }

  const snapshot = await db
    .collection("sms_config")
    .where(
      "companyid",
      "==",
      normalizedCompanyId
    )
    .limit(1)
    .get();

  const config =
    snapshot.empty
      ? null
      : snapshot.docs[0].data() || {};

  return {
    apiKey:
      config.key ||
      config.api_key ||
      process.env.KOLOGSMS_API_KEY ||
      process.env.SMS_API_KEY ||
      "",

    senderid:
      config.senderid ||
      fallbackSenderId ||
      "",
  };
}

// ================================================================
// PROCESS SINGLE PENDING SMS
// GEN 2 CALLABLE
// ================================================================

exports.processPendingSMS = onCall(
  async (request) => {
    const data = request.data;
    const context = request;

    // Verify the user is authenticated
    if (!context.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to send SMS."
      );
    }

    const { docId } = data;

    if (
      !docId ||
      typeof docId !== "string"
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Document ID is required."
      );
    }

    try {
      // Get the SMS record from Firestore
      const smsDoc = await db
        .collection("sms_logs")
        .doc(docId)
        .get();

      if (!smsDoc.exists) {
        throw new Error(
          "SMS record not found"
        );
      }

      const smsData = smsDoc.data();

      // Only process pending SMS
      if (smsData.status !== "pending") {
        return {
          success: false,
          message:
            `SMS already processed with status: ${smsData.status}`,
        };
      }

      const {
        message,
        recipient,
        senderid,
      } = smsData;

      const companyId =
        smsData.companyid ||
        smsData.companyId ||
        null;

      try {
        // Send SMS via API
        const result =
          await sendSMSToKologAPI(
            message,
            recipient,
            senderid,
            companyId
          );

        // Update record with success status
        await db
          .collection("sms_logs")
          .doc(docId)
          .update({
            status: "sent",

            successMessage:
              result.message ||
              "SMS sent successfully",

            apiResponse: result,

            updatedAt:
              admin.firestore.Timestamp.now(),
          });

        return {
          success: true,
          message:
            "SMS sent and database updated successfully",
        };
      } catch (sendError) {
        // Update record with failure status
        await db
          .collection("sms_logs")
          .doc(docId)
          .update({
            status: "failed",

            failureReason:
              sendError.message,

            updatedAt:
              admin.firestore.Timestamp.now(),
          });

        console.error(
          "SMS sending error for doc",
          docId,
          ":",
          sendError
        );

        return {
          success: false,

          message:
            "SMS sending failed. Database updated with failure reason.",

          error:
            sendError.message,
        };
      }
    } catch (error) {
      console.error(
        "Error processing SMS record:",
        error
      );

      throw new HttpsError(
        "internal",
        error.message
      );
    }
  }
);

// ================================================================
// FIRESTORE TRIGGER
// ALREADY GEN 2
// ================================================================

exports.onSMSCreated =onDocumentCreated(
    "sms_logs/{docId}",
    async (event) => {
      const smsData =
        event.data.data();

      const docId =
        event.params.docId;

      // Only auto-process if status is pending
      if (
        smsData.status !== "pending"
      ) {
        return null;
      }

      // ============================================================
      // HANDLE INDIVIDUAL SMS
      // ============================================================

      if (
        smsData.type === "single" ||
        smsData.type === "bulk_individual"
      ) {
        const {
          message,
          recipient,
          senderid,
        } = smsData;

        const companyId =
          smsData.companyid ||
          smsData.companyId ||
          null;

        try {
          // Send SMS via API
          const result =
            await sendSMSToKologAPI(
              message,
              recipient,
              senderid,
              companyId
            );

          // Update record with success status
          await db.collection("sms_logs").doc(docId).update({
              status: "sent",

              successMessage:result.message ||result.rawResponse ||null,
              apiResponse:result, updatedAt:admin.firestore.Timestamp.now(),
            });
            await db.collection("dashbaord_stats").doc(companyId).update({
            successMessage:result.message ||result.rawResponse ||null,
            smsBalance:result.balance, updatedAt:admin.firestore.Timestamp.now(),
            })
          console.log(
            `SMS sent successfully for doc ${docId}`
          );
        } catch (error) {
          // Update record with failure status
          await db.collection("sms_logs") .doc(docId) .update({
              status: "failed",

              failureReason: error.message,

              updatedAt: admin.firestore.Timestamp.now(),
            });
         await db.collection("dashbaord_stats").doc(companyId).update({
            successMessage:result.message ||result.rawResponse ||null,
            smsBalance:result.balance, updatedAt:admin.firestore.Timestamp.now(),
            })
          console.error(
            `SMS sending failed for doc ${docId}:`,
            error.message
          );
        }
      }

      // ============================================================
      // HANDLE BULK SMS WITH FILTERS
      // ============================================================

      else if (
        smsData.type === "bulk"
      ) {
        const {
          message,
          senderid,
          companyid,
          bulkFilterType,
          bulkFilterValue,
        } = smsData;

        try {
          // Query customers/farmers based on filter
          let query = db
            .collection("customers")
            .where(
              "companyid",
              "==",
              companyid
            );

          switch (bulkFilterType) {
            case "customerType":
              query =
                query.where(
                  "customertype",
                  "==",
                  bulkFilterValue
                );
              break;

            case "cropMajor":
              query =
                query.where(
                  "majorcrop",
                  "==",
                  bulkFilterValue
                );
              break;

            case "language":
              query =
                query.where(
                  "languagespokens",
                  "array-contains",
                  bulkFilterValue
                );
              break;

            case "branch":
              query =
                query.where(
                  "branchid",
                  "==",
                  bulkFilterValue
                );
              break;

            case "community":
              query =
                query.where(
                  "community",
                  "==",
                  bulkFilterValue
                );
              break;

            case "gender":
              query =
                query.where(
                  "gender",
                  "==",
                  bulkFilterValue
                );
              break;

            case "educationLevel":
              query =
                query.where(
                  "educationlevel",
                  "==",
                  bulkFilterValue
                );
              break;
          }

          // Fetch all matching customers
          const snapshot =
            await query.get();

          if (snapshot.empty) {
            await db
              .collection("sms_logs")
              .doc(docId)
              .update({
                status: "completed",

                recipientCount: 0,

                successCount: 0,

                failureCount: 0,

                resultMessage:
                  `No customers found with ${bulkFilterType}: ${bulkFilterValue}`,

                updatedAt:
                  admin.firestore.Timestamp.now(),
              });

            return null;
          }

          // Extract phone numbers
          let successCount = 0;
          let failureCount = 0;

          const batchSize = 5;

          const phoneNumbers = [];

          snapshot.docs.forEach(
            (doc) => {
              const data =
                doc.data();

              const phone =
                data.contact ||
                data.phone ||
                data.phonenumber;

              if (phone) {
                phoneNumbers.push(
                  phone
                );
              }
            }
          );

          // Send SMS with rate limiting
          for (
            let i = 0;
            i < phoneNumbers.length;
            i += batchSize
          ) {
            const batch =
              phoneNumbers.slice(
                i,
                i + batchSize
              );

            const promises =
              batch.map(
                async (contact) => {
                  try {
                    const result =
                      await sendSMSToKologAPI(
                        message,
                        contact,
                        senderid,
                        companyid
                      );

                    successCount++;

                    // Save individual SMS record
                    await db
                      .collection(
                        "sms_logs"
                      )
                      .add({
                        companyid:
                          companyid,

                        staff:
                          smsData.staff,

                        branchid:
                          smsData.branchid,

                        message:
                          message,

                        senderid:
                          senderid,

                        recipient:
                          contact,

                        type:
                          "bulk_individual",

                        bulkParentId:
                          docId,

                        status:
                          "sent",

                       successMessage:
                         result.message ||
                         result.rawResponse ||
                         null,

                       apiResponse:
                         result,

                        createdAt:
                          admin.firestore.Timestamp.now(),

                        updatedAt:
                          admin.firestore.Timestamp.now(),
                      });

                  } catch (error) {
                    failureCount++;

                    // Save failed SMS record
                    await db
                      .collection(
                        "sms_logs"
                      )
                      .add({
                        companyid:
                          companyid,

                        staff:
                          smsData.staff,

                        branchid:
                          smsData.branchid,

                        message:
                          message,

                        senderid:
                          senderid,

                        recipient:
                          contact,

                        type:
                          "bulk_individual",

                        bulkParentId:
                          docId,

                        status:
                          "failed",

                        failureReason:
                          result.message,

                        createdAt:
                          admin.firestore.Timestamp.now(),

                        updatedAt:
                          admin.firestore.Timestamp.now(),
                      });
                  }
                }
              );

            await Promise.all(
              promises
            );

            // Delay between batches
            if (
              i + batchSize <
              phoneNumbers.length
            ) {
              await new Promise(
                (resolve) =>
                  setTimeout(
                    resolve,
                    1000
                  )
              );
            }
          }

          // Update bulk SMS record
          await db
            .collection("sms_logs")
            .doc(docId)
            .update({
              status: "completed",

              recipientCount:
                phoneNumbers.length,

              successCount:
                successCount,

              failureCount:
                failureCount,

              resultMessage:
                `Sent to ${successCount}/${phoneNumbers.length} recipients`,

              updatedAt:
                admin.firestore.Timestamp.now(),
            });
 await db.collection("dashbaord_stats").doc(companyId).update({
            successMessage:result.message ||result.rawResponse ||null,
            smsBalance:result.balance, updatedAt:admin.firestore.Timestamp.now(),
            })
          console.log(
            `Bulk SMS processing completed for doc ${docId}: ${successCount} sent, ${failureCount} failed`
          );
        } catch (error) {
          // Update bulk SMS record with error status
          await db
            .collection("sms_logs")
            .doc(docId)
            .update({
              status: "failed",

              failureReason:
                result.message,

              updatedAt:
                admin.firestore.Timestamp.now(),
            });
 await db.collection("dashbaord_stats").doc(companyId).update({
            successMessage:result.message ||result.rawResponse ||null,
            smsBalance:result.balance, updatedAt:admin.firestore.Timestamp.now(),
            })
          console.error(
            `Bulk SMS processing failed for doc ${docId}:`,
            error.message
          );
        }
      }

      return null;
    }
  );

// ================================================================
// SEND SMS
// GEN 2 CALLABLE
// ================================================================

exports.sendSMS = onCall(
  async (request) => {
    const data = request.data;
    const context = request;

    // Verify the user is authenticated
    if (!context.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to send SMS."
      );
    }

    const {
      message,
      contact,
      senderid,
      companyId,
    } = data;

    // Validate input
    if (
      !message ||
      typeof message !== "string"
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Message is required and must be a string."
      );
    }

    if (
      !contact ||
      typeof contact !== "string"
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Contact number is required and must be a string."
      );
    }

    try {
      const result =
        await sendSMSToKologAPI(
          message,
          contact,
          senderid,
          companyId
        );

      return {
        success: true,

        data: result,

        message:
          "SMS sent successfully",
      };
    } catch (error) {
      console.error(
        "SMS sending error:",
        error
      );

      return {
        success: false,

        error:
          error.message,

        message:
          "Failed to send SMS",
      };
    }
  }
);

// ================================================================
// SEND SMS VIA KOLOGSOFT API
// ================================================================


async function sendSMSToKologAPI(
  message,
  contact,
  senderid,
  companyId
) {
  const {
    apiKey,
    senderid: configuredSenderId,
  } = await resolveSmsConfig(
    companyId,
    senderid
  );

  const effectiveSenderId =
    configuredSenderId ||
    senderid;

  if (!apiKey) {
    throw new Error(
      "No SMS API key configured for this company."
    );
  }

  if (!effectiveSenderId) {
    throw new Error(
      "No SMS sender ID configured for this company."
    );
  }

  return new Promise(
    (resolve, reject) => {
      const params =
        querystring.stringify({
          action: "send-sms",

          api_key:
            apiKey,

          to:
            contact,

          from:
            effectiveSenderId,

          sms:
            message,
        });

      const url =
        `https://sms.kologsoft.com/sms/api?${params}`;

      https
        .get(
          url,
          (res) => {
            let data = "";

            res.on(
              "data",
              (chunk) => {
                data += chunk;
              }
            );

            res.on(
              "end",
              () => {
                try {
                  const json =
                    JSON.parse(data);

                  // Return exactly what the SMS API returned
                  resolve(json);
                } catch (error) {
                  // Return the exact raw response if it is not JSON
                  resolve({
                    rawResponse: data,
                  });
                }
              }
            );
          }
        )
        .on(
          "error",
          (err) => {
            reject(
              new Error(
                `HTTP request failed: ${err.message}`
              )
            );
          }
        )
        .setTimeout(
          10000,
          function () {
            this.destroy();

            reject(
              new Error(
                "SMS API request timeout"
              )
            );
          }
        );
    }
  );
}


// ================================================================
// BATCH SEND SMS
// GEN 2 CALLABLE
// ================================================================

exports.sendBulkSMS = onCall(
  async (request) => {
    const data = request.data;
    const context = request;

    if (!context.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to send SMS."
      );
    }

    const {
      message,
      contacts,
      senderid,
      companyId,
    } = data;

    if (
      !message ||
      typeof message !== "string"
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Message is required."
      );
    }

    if (
      !Array.isArray(contacts) ||
      contacts.length === 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Contacts must be a non-empty array."
      );
    }

    const results = {
      total:
        contacts.length,

      successful: 0,

      failed: 0,

      details: [],
    };

    // Send SMS with rate limiting
    const batchSize = 5;

    for (
      let i = 0;
      i < contacts.length;
      i += batchSize
    ) {
      const batch =
        contacts.slice(
          i,
          i + batchSize
        );

      const promises =
        batch.map(
          async (contact) => {
            try {
              const result =
                await sendSMSToKologAPI(
                  message,
                  contact,
                  senderid,
                  companyId
                );

              results.successful++;

              results.details.push({
                contact,

                status:
                  "sent",

                result,
              });
            } catch (error) {
              results.failed++;

              results.details.push({
                contact,

                status:
                  "failed",

                error:
                  error.message,
              });
            }
          }
        );

      await Promise.all(
        promises
      );

      // Delay between batches
      if (
        i + batchSize <
        contacts.length
      ) {
        await new Promise(
          (resolve) =>
            setTimeout(
              resolve,
              1000
            )
        );
      }
    }

    return {
      success:
        results.successful > 0,

      data:
        results,

      message:
        `Sent to ${results.successful}/${results.total} recipients`,
    };
  }
);

// ================================================================
// BULK SMS WITH FILTERS
// GEN 2 CALLABLE
// ================================================================

exports.sendBulkSMSWithFilters =
  onCall(
    async (request) => {
      const data =
        request.data;

      const context =
        request;

      if (!context.auth) {
        throw new HttpsError(
          "unauthenticated",
          "User must be authenticated to send SMS."
        );
      }

      const {
        message,
        senderid,
        companyId,
        filterType,
        filterValue,
      } = data;

      // Validate required fields
      if (
        !message ||
        typeof message !== "string"
      ) {
        throw new HttpsError(
          "invalid-argument",
          "Message is required and must be a string."
        );
      }

      if (
        !companyId ||
        typeof companyId !== "string"
      ) {
        throw new HttpsError(
          "invalid-argument",
          "Company ID is required."
        );
      }

      if (
        !filterType ||
        ![
          "customerType",
          "cropMajor",
          "language",
          "branch",
          "community",
          "gender",
        ].includes(filterType)
      ) {
        throw new HttpsError(
          "invalid-argument",
          "Valid filterType is required: customerType, cropMajor, language, branch, community, or gender"
        );
      }

      if (!filterValue) {
        throw new HttpsError(
          "invalid-argument",
          "Filter value is required."
        );
      }

      try {
        // Query customers/farmers based on filter
        let query =
          db
            .collection(
              "customers"
            )
            .where(
              "companyid",
              "==",
              companyId
            );

        switch (filterType) {
          case "customerType":
            query =
              query.where(
                "customertype",
                "==",
                filterValue
              );
            break;

          case "cropMajor":
            query =
              query.where(
                "majorcrop",
                "==",
                filterValue
              );
            break;

          case "language":
            query =
              query.where(
                "languagesspoken",
                "array-contains",
                filterValue
              );
            break;

          case "branch":
            query =
              query.where(
                "branchid",
                "==",
                filterValue
              );
            break;

          case "community":
            query =
              query.where(
                "community",
                "==",
                filterValue
              );
            break;

          case "gender":
            query =
              query.where(
                "gender",
                "==",
                filterValue
              );
            break;
        }

        // Fetch all matching customers
        const snapshot =
          await query.get();

        if (snapshot.empty) {
          return {
            success: false,

            message:
              `No customers found with ${filterType}: ${filterValue}`,

            data: {
              total: 0,

              successful: 0,

              failed: 0,

              details: [],
            },
          };
        }

        // Extract phone numbers
        const contacts = [];

        snapshot.docs.forEach(
          (doc) => {
            const data =
              doc.data();

            const phone =
              data.contact ||
              data.phone ||
              data.phonenumber;

            if (phone) {
              contacts.push(
                phone
              );
            }
          }
        );

        if (
          contacts.length === 0
        ) {
          return {
            success: false,

            message:
              "No valid phone numbers found for selected customers",

            data: {
              total:
                snapshot.size,

              successful: 0,

              failed: 0,

              details: [],
            },
          };
        }

        const results = {
          total:
            contacts.length,

          successful: 0,

          failed: 0,

          details: [],

          filterType,

          filterValue,
        };

        // Send SMS with rate limiting
        const batchSize = 5;

        for (
          let i = 0;
          i < contacts.length;
          i += batchSize
        ) {
          const batch =
            contacts.slice(
              i,
              i + batchSize
            );

          const promises =
            batch.map(
              async (contact) => {
                try {
                  const result =
                    await sendSMSToKologAPI(
                      message,
                      contact,
                      senderid,
                      companyId
                    );

                  results.successful++;

                  results.details.push({
                    contact,

                    status:
                      "sent",

                    result,
                  });
                } catch (error) {
                  results.failed++;

                  results.details.push({
                    contact,

                    status:
                      "failed",

                    error:
                      error.message,
                  });
                }
              }
            );

          await Promise.all(
            promises
          );

          // Delay between batches
          if (
            i + batchSize <
            contacts.length
          ) {
            await new Promise(
              (resolve) =>
                setTimeout(
                  resolve,
                  1000
                )
            );
          }
        }

        return {
          success:
            results.successful >
            0,

          data:
            results,

          message:
            `Sent to ${results.successful}/${results.total} recipients matching ${filterType}: ${filterValue}`,
        };
      } catch (error) {
        console.error(
          "Error sending bulk SMS with filters:",
          error
        );

        throw new HttpsError(
          "internal",
          error.message
        );
      }
    }
  );