
const functions = require("firebase-functions");
const { admin, db } = require("./fb");


/*
 * ============================================================
 * HELPERS
 * ============================================================
 */

function numberValue(value, fallback = 0) {
  const n = Number(value);

  return Number.isFinite(n)
    ? n
    : fallback;
}


function stringValue(value, fallback = "") {
  if (value === null || value === undefined) {
    return fallback;
  }

  return String(value).trim();
}


function toTimestamp(value) {

  if (!value) {
    return admin.firestore.Timestamp.now();
  }


  if (
    value instanceof admin.firestore.Timestamp
  ) {
    return value;
  }


  if (
    value &&
    typeof value.toDate === "function"
  ) {

    return admin.firestore.Timestamp.fromDate(
      value.toDate()
    );
  }


  if (value instanceof Date) {

    return admin.firestore.Timestamp.fromDate(
      value
    );
  }


  const date =
    new Date(value);


  if (
    !Number.isNaN(
      date.getTime()
    )
  ) {

    return admin.firestore.Timestamp.fromDate(
      date
    );
  }


  return admin.firestore.Timestamp.now();
}



function normalizeSalesItem(item, transaction) {

  if (
    !item ||
    typeof item !== "object"
  ) {

    throw new Error(
      "Invalid sales item."
    );
  }


  const companyid =
    stringValue(
      item.companyid ||
      transaction.companyId
    );


  const branchid =
    stringValue(
      item.branchid ||
      transaction.branchId
    );


  const branchname =
    stringValue(
      item.branchname ||
      transaction.branchName
    );


  const branchtype =
    stringValue(
      item.branchtype ||
      transaction.branchType ||
      branchname
    );


  /*
   * ------------------------------------------------------------
   * ITEM ID
   * ------------------------------------------------------------
   */

  const itemid =
    stringValue(
      item.itemid
    ) ||
    `${companyid}_${stringValue(item.item)}`
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "");


  /*
   * ------------------------------------------------------------
   * NUMERIC VALUES
   * ------------------------------------------------------------
   */

  const quantity =
    numberValue(
      item.quantity,
      0
    );


  const pieces =
    numberValue(
      item.pieces,
      quantity
    );


  const price =
    numberValue(
      item.selling_price ??
      item.price,
      0
    );


  const cp =
    numberValue(
      item.cost_price ??
      item.cp ??
      item.originalcp,
      0
    );


  const totalamount =
    numberValue(
      item.total,
      price * quantity
    );


  const discount =
    numberValue(
      item.discount,
      0
    );


  const profit =
    numberValue(
      item.profit,
      totalamount - (cp * quantity)
    );


  /*
   * ------------------------------------------------------------
   * RETURN SALES ITEM
   * ------------------------------------------------------------
   */
  return {

    barcode:
      stringValue(
        item.barcode ||
        item.item
      ),


    boxpiece:
      stringValue(
        item.boxpieces ??
        item.boxpiece ??
        "1"
      ),


    branchid:
      branchid,


    branchname:
      branchname,


    branchtype:
      branchtype,


    cp:
      String(
        item.cost_price ??
        item.cp ??
        item.originalcp ??
        "0"
      ),


    discount:
      String(
        item.discount ??
        "0"
      ),


    grosstotalamount:
      totalamount.toFixed(2),


    item:
      stringValue(
        item.item
      ),


    itemid:
      itemid,


    mode:
      stringValue(
        item.modes ??
        item.mode ??
        item.stockingmode,
        "Single"
      ),


    modeqty:
      String(
        item.modeqty ??
        "1"
      ),


    pcategory:
      stringValue(
        item.product_category ??
        item.pcategory
      ),


    price:
      String(
        item.selling_price ??
        item.price ??
        "0"
      ),


    pricemode:
      stringValue(
        item.pricemode ??
        item.pricingtype,
        "retail"
      ),


    producttype:
      stringValue(
        item.product_type ??
        item.producttype,
        "product"
      ),


    profit:
      String(
        item.profit ??
        profit
      ),


    quantity:
      String(
        item.quantity ??
        "0"
      ),


    stockCheckStatus:
      stringValue(
        item.stockCheckStatus,
        "approved"
      ),


    totalamount:
      String(
        item.total ??
        totalamount
      ),


    totalpieces:
      String(
        item.pieces ??
        item.quantity ??
        "0"
      ),


    month:
      stringValue(
        item.month ||
        transaction.month
      )
  };
}


function normalizePayment(item, transaction) {

  const amount =
    numberValue(
      item.amountPaid ??
      item.amount ??
      item.total,
      transaction.totalamount
    );


  const method =
    stringValue(
      item.paymentmethod ??
      item.method ??
      transaction.transMode,
      "cash"
    );


  const accountName =
    stringValue(
      item.accountName ??
      item.payaccount ??
      transaction.paymentAccount ??
      method
    );


  const accountNumber =
    stringValue(
      item.accountNumber ??
      item.accountnumber ??
      item.payaccount ??
      accountName
    );


  const reference =
    stringValue(
      item.reference ??
      item.paymentreference ??
      item.invoiceno ??
      transaction.id
    );


  return {

    accountName:
      accountName,

    accountNumber:
      accountNumber,

    amount:
      amount,

    method:
      method,

    reference:
      reference,

    statustrue:
      true
  };
}

async function createCreditCustomer(transaction) {

  if (transaction.transMode !== "credit") {
    return null;
  }

  const contact =
    stringValue(
      transaction.customerPhone
    );

  if (
    !contact ||contact.toLowerCase() === "cash"
  ) {
    throw new Error(
      `Credit sale ${transaction.id} is missing customer phone number.`
    );
  }

  const customerId =`${transaction.companyId}_${contact}`.toLowerCase();

  const customerRef =db.collection("customers") .doc(customerId);

  const now =admin.firestore.Timestamp.now();

  const customerData = {

    branchid:transaction.branchId,

    branchname: transaction.branchName,

    companyid: transaction.companyId,

    companyname: transaction.companyname,

    contact: contact,
    name: transaction.customerName,

    createdat: now,
//creditBalance:
//        admin.firestore.FieldValue.increment(
//          transaction.totalamount
//        ),

    date:new Date().toISOString().split("T")[0],

    id: customerId,

    iscashcustoma:
      "Credit"
  };

  await customerRef.set(
    customerData,
    {
      merge: true
    }
  );

  return customerId;
}

function normalizeSalesTransaction(
  items,
  extra = {}
) {

  if (
    !Array.isArray(items) ||
    items.length === 0
  ) {

    throw new Error(
      "No sales items supplied."
    );
  }


  const first =
    items[0];


  const rawTransMode = stringValue(first.transmode ||first.transMode,"cash").toLowerCase();

  const transMode = rawTransMode === "cash sales" ? "cash" : rawTransMode === "credit sales" ? "credit" : rawTransMode;

  const companyId =
    stringValue(
      extra.companyid ||
      extra.companyId ||
      first.companyid ||
      first.companyId
    );


  if (!companyId) {

    throw new Error(
      "Missing companyid."
    );
  }


  /*
   * ==========================================================
   * TID
   * ==========================================================
   */

  const tid =
    stringValue(
      extra.tid ||
      first.tid
    );


  if (!tid) {

    throw new Error(
      "Missing tid."
    );
  }


  /*
   * ==========================================================
   * BRANCH
   * ==========================================================
   */

  const branchName =
    stringValue(
      extra.branchname ||
      extra.branchName ||
      first.branchname ||
      first.branchName ||
      first.supplybranch
    );


  if (!branchName) {

    throw new Error(
      "Missing branchname."
    );
  }


  const branchId =
    stringValue(
      extra.branchid ||
      extra.branchId ||
      first.branchid ||
      first.branchId
    ) ||
    `${companyId}${branchName}`
      .toLowerCase()
      .replace(/\s+/g, "_");


  const branchType =
    stringValue(
      extra.branchType ||
      first.branchType,
      "Sales Branch"
    );


  const apiId =
    stringValue(
      first.id
    );


  if (!apiId) {

    throw new Error(
      `API item is missing id for TID ${tid}.`
    );
  }

const transactionId = `${companyId}_${tid}`;




  const now = admin.firestore.Timestamp.now();


  const createdAt =
    first.createdat ||
    first.createdAt
      ? toTimestamp(
          first.createdat ||
          first.createdAt
        )
      : now;


  const invoiceDate =
    first.date
      ? toTimestamp(
          first.date
        )
      : now;


  /*
   * ==========================================================
   * TOTALS
   * ==========================================================
   */

  let totalAmount = 0;
  let totalDiscount = 0;


  items.forEach((item) => {

    totalAmount +=
      numberValue(
        item.total
      );


    totalDiscount +=
      numberValue(
        item.discount
      );
  });


  /*
   * Allow explicit total from API when available.
   */

  const finalTotal =
    numberValue(
      extra.totalamount ??
      extra.totalAmount ??
      first.totalamount,
      totalAmount
    );


  const amountPaid =
    numberValue(
      extra.amountPaid ??
      first.amountPaid,
      finalTotal
    );


  const change =
    numberValue(
      extra.change ??
      first.change,
      Math.max(
        amountPaid - finalTotal,
        0
      )
    );


  /*
   * ==========================================================
   * ITEMS MAP
   *
   * SALES SCHEMA REQUIRES:
   *
   * items:
   * {
   *   item_0: {...},
   *   item_1: {...}
   * }
   * ==========================================================
   */

  const itemMap = {};


  items.forEach(
    (item, index) => {

      itemMap[`item_${index}`] =
        normalizeSalesItem(
          item,
          {
            companyId:
              companyId,

            branchId:
              branchId,

            branchName:
              branchName,

            branchType:
              branchType,

            month:
              stringValue(
                first.month
              )
          }
        );
    }
  );


  /*
   * ==========================================================
   * PAYMENT
   * ==========================================================
   */

 const payment = normalizePayment(
   first,
   {
     totalamount:
       finalTotal,

     transMode:
       transMode,

     paymentAccount:
       stringValue(
         first.payaccount
       ),

     id:
       apiId
   }
 );


  /*
   * ==========================================================
   * FINAL SALES DOCUMENT
   * ==========================================================
   */
//const transactionId = `${companyId}_${tid}`;

  return {

    amountPaid:
      amountPaid,


    approvedby:
      stringValue(
        first.approvedby ||
        first.approvedBy ||
        first.staff
      ),


    branchId:
      branchId,


    branchName:
      branchName,


    branchType:
      branchType,


    change:
      change,


    companyId:
      companyId,


    companyname:
      stringValue(
        extra.company ||
        extra.companyname ||
        first.company ||
        first.companyname
      ),


    createdAt:
      createdAt,


    createdBy:
      stringValue(
        first.staff ||
        first.createdby ||
        first.createdBy
      ),

customerId:stringValue(first.customerid ||first.customerId ) ||
  (
    stringValue(first.cphone) ? `${companyId}_${stringValue(first.cphone)}`.toLowerCase(): "cash"

  ),


    customerName:stringValue(first.tname ||"cash customer"),


    customerPhone:
      stringValue(
        first.cphone ||
        "cash"
      ),


    dateymd:
      stringValue(
        first.dateymd ||
        first.date
      ),


    day:
      stringValue(
        first.day
      ),


    discount:
      totalDiscount,


    /*
     * API ID
     *
     * This is the ID returned to the caller.
     */

    id:
      apiId,


    isreturned:
      false,


    itemCount:
      items.length,


    items:
      itemMap,


    month:
      stringValue(
        first.month
      ),


    paymentStatus:
      amountPaid >= finalTotal
        ? "paid"
        : "partial",


    payments:
      [
        payment
      ],


    pricingtype:
      stringValue(
        first.pricingtype ||
        first.pricemode,
        branchType
      ),


    printed:
      first.printed === true,


    printedat:
      first.printedat
        ? toTimestamp(
            first.printedat
          )
        : null,


    printedby:
      stringValue(
        first.printedby
      ),


    receiptNumber:
      stringValue(
        first.receiptnumber ||
        first.receiptNumber ||
        first.invoiceno
      ),


    receiptat:
      first.receiptat
        ? toTimestamp(
            first.receiptat
          )
        : null,


    receiptby:
      stringValue(
        first.receiptby
      ),


    reciepted:
      first.reciepted === true,


    staffPosition:
      numberValue(
        first.staffPosition,
        0
      ),


    staffemail:
      stringValue(
        extra.staffemail ||
        first.staffemail
      ),


    stockCheckStatus:
      stringValue(
        first.stockCheckStatus,
        "approved"
      ),


    stockCheckedAt:
      first.stockCheckedAt
        ? toTimestamp(
            first.stockCheckedAt
          )
        : now,


    timestamp:
      Number(
        first.timestamp ||
        Date.now()
      ),


    totalamount:
      finalTotal,


   transMode:
     transMode,

    week:
      stringValue(
        first.week
      ),


    year:
      stringValue(
        first.year
      )
  };
}


/*
 * ============================================================
 * UPLOAD STOCK / SALES
 * ============================================================
 */

exports.uploadSales=
  functions.https.onRequest(
    async (req, res) => {

      /*
       * --------------------------------------------------------
       * CORS
       * --------------------------------------------------------
       */

      res.set(
        "Access-Control-Allow-Origin",
        "*"
      );

      res.set(
        "Access-Control-Allow-Methods",
        "POST, OPTIONS"
      );

      res.set(
        "Access-Control-Allow-Headers",
        "Content-Type"
      );


      if (
        req.method === "OPTIONS"
      ) {

        return res
          .status(204)
          .send("");
      }


      if (
        req.method !== "POST"
      ) {

        return res.status(405).json({

          success:
            false,

          error:
            "Only POST requests are allowed."
        });
      }


      try {

        console.log("");
        console.log(
          "================================================"
        );

        console.log(
          "SALES UPLOAD ENDPOINT"
        );

        console.log(
          "================================================"
        );


        const body =
          req.body;


        console.log(
          "Content-Type:",
          req.headers["content-type"]
        );


        console.log(
          "Body received:"
        );


        console.log(
          JSON.stringify(
            body,
            null,
            2
          )
        );


        /*
         * ======================================================
         * GET API ITEMS
         * ======================================================
         */

        let legacyItems = [];


        if (
          body &&
          Array.isArray(
            body.data
          )
        ) {

          legacyItems =
            body.data;

        } else if (
          Array.isArray(body)
        ) {

          legacyItems =
            body;

        } else if (
          body &&
          typeof body === "object"
        ) {

          legacyItems = [
            body
          ];

        } else {

          return res.status(400).json({

            success:
              false,

            error:
              "Invalid request body."
          });
        }


        if (
          legacyItems.length === 0
        ) {

          return res.status(400).json({

            success:
              false,

            error:
              "No sales records supplied."
          });
        }


        console.log(
          "API records:",
          legacyItems.length
        );


        /*
         * ======================================================
         * GROUP BY TID
         *
         * Example:
         *
         * id A + tid 1787
         * id B + tid 1787
         * id C + tid 1787
         *
         * becomes ONE sales document.
         * ======================================================
         */

        const grouped = {};


        for (
          const item
          of legacyItems
        ) {

          const tid =
            stringValue(
              item.tid
            );


          if (!tid) {

            throw new Error(
              "API record is missing tid."
            );
          }


          if (
            !grouped[tid]
          ) {

            grouped[tid] = [];
          }


          grouped[tid].push(
            item
          );
        }


        console.log(
          "TIDs FOUND:",
          Object.keys(grouped)
        );


        /*
         * ======================================================
         * SAVE RESULTS
         * ======================================================
         */

        const successfulIds =
          [];


        const successfulTransactions =
          [];


        /*
         * ======================================================
         * PROCESS EACH TRANSACTION
         * ======================================================
         */

        for (
          const [tid, items]
          of Object.entries(grouped)
        ) {

          console.log("");
          console.log(
            "================================================"
          );


          console.log(
            "PROCESSING TID:",
            tid
          );


          console.log(
            "ITEMS:",
            items.length
          );


          console.log(
            "================================================"
          );


          /*
           * Wrapper values
           */

          const extra =
            body &&
            !Array.isArray(body) &&
            Array.isArray(body.data)
              ? body
              : {};


          /*
           * ----------------------------------------------------
           * REMAP TO SALES SCHEMA
           * ----------------------------------------------------
           */

          const document =
            normalizeSalesTransaction(
              items,
              extra
            );


          // console.log(
          //   "Sales document ID:",
          //   transactionId
          // );





          console.log(
            "Item count:",
            document.itemCount
          );


          console.log(
            "Total amount:",
            document.totalamount
          );


          /*
           * ----------------------------------------------------
           * LOG COMPLETE SALES DOCUMENT
           * ----------------------------------------------------
           */

          console.log("");
          console.log(
            "================================================"
          );


          console.log(
            "COMPLETE SALES DOCUMENT"
          );


          console.log(
            "================================================"
          );


          console.log(
            JSON.stringify(
              document,
              null,
              2
            )
          );


          console.log(
            "================================================"
          );


          /*
           * ----------------------------------------------------
           * FIRESTORE
           *
           * Use API ID as the Firestore document ID.
           * ----------------------------------------------------
           */
const firestoreDocId =`${document.companyId}_${tid}`;

            if (
            document.transMode === "credit"
            ) {

           const customerId = await createCreditCustomer(document);

            console.log(
            "CREDIT CUSTOMER SAVED:",customerId);
                        }

          const docRef =db.collection("sales").doc(firestoreDocId);

          await docRef.set(
            document,
            {
              merge:
                true
            }
          );


          const savedDoc =await docRef.get();


          if (
            !savedDoc.exists
          ) {

            throw new Error(
              `Firestore write verification failed for API ID ${document.id}.`
            );
          }


          console.log(
            "Firestore saved:",
            document.id
          );


          const apiIds =
            items
              .map(
                item =>
                  item.id
              )
              .filter(
                id =>
                  id !== null &&
                  id !== undefined
              );


          console.log(
            "API IDs:",
            apiIds
          );


          successfulIds.push(
            ...apiIds
          );


          successfulTransactions.push({

            tid:
              tid,

            id:
              document.id,

            apiIds:
              apiIds,

            itemCount:
              document.itemCount,

            firestoreSaved:
              true
          });
        }


        /*
         * ======================================================
         * SUCCESS
         * ======================================================
         */

        console.log("");
        console.log(
          "================================================"
        );


        console.log(
          "ALL SALES SAVED SUCCESSFULLY"
        );


        console.log(
          "API IDS RETURNED:",
          successfulIds
        );


        console.log(
          "================================================"
        );


        return res.status(200).json({

          success:
            true,

          saved:
            true,

          count:
            successfulIds.length,

          /*
           * These are the ORIGINAL IDs
           * received from the API.
           */

          ids:
            successfulIds,

          message:
            "Sales data remapped and saved successfully."
        });


      } catch (error) {

        console.error("");
        console.error(
          "================================================"
        );


        console.error(
          "SALES REMAPPING ERROR"
        );


        console.error(
          "================================================"
        );


        console.error(
          error
        );


        console.error(
          "================================================"
        );


        return res.status(500).json({

          success:
            false,

          saved:
            false,

          firestoreWrite:
            false,

          error:
            error.message ||
            "Failed to remap and save sales transaction."
        });
      }
    }
  );

