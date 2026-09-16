const functions = require("firebase-functions");
const { admin, db } = require("./fb");

function numberValue(value, fallback = 0) {
  const n = Number(value);

  return Number.isFinite(n) ? n : fallback;
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
    value && typeof value.toDate === "function"
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


  const date = new Date(value);


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


/*
 * ============================================================
 * CREATE BRANCH ID
 * ============================================================
 */

function createBranchId(
  companyid,
  branchname
) {

  const company = stringValue(companyid);

  const branch = stringValue(branchname);

  if (!company || !branch) {
    return "";
  }

  return `${company}${branch}`.toLowerCase().replace(/\s+/g, "_");
}

function createItemId(item) {

  const companyid =stringValue(item.companyid);

  const suppliedItemId = stringValue(item.itemid);

  if (suppliedItemId) {return suppliedItemId; }

  const itemName =stringValue(item.item);

  if (!itemName) {
    return "";
  }

  return `${companyid}_${itemName}`.toLowerCase().replace(/[^a-z0-9]+/g, "");

}

function normalizeLegacyItem( item,transaction) {

  if (
    !item ||
    typeof item !== "object"
  ) {
    throw new Error(
      "Invalid legacy stock item."
    );
  }

  const companyid =stringValue(item.companyid ||transaction.companyid);

  const branchid =stringValue(item.branchid || transaction.branchid);
  const branchname =  stringValue( item.branchname ||item.supplybranch ||transaction.branchname);
 const itemid =createItemId(
      {
        ...item,
        companyid
      }
    );


  if (!itemid) {
    throw new Error(
      `Missing item name/itemid for API ID ${stringValue(item.id)}.`
    );
  }

  const quantity = numberValue(item.quantity,0);

  const pieces = numberValue(item.pieces,quantity );

  const price =
    numberValue(
      item.selling_price ??
      item.price ??
      item.total_selling_price,
      0
    );


  const originalcp =
    numberValue(
      item.cost_price ??
      item.originalcp ??
      item.cp ??
      item.total_cost_price,
      0
    );


  const total =
    numberValue(
      item.total,
      0
    );


  const discount =
    numberValue(
      item.discount,
      0
    );


  return {

    itemid:itemid,
      item:
      stringValue(
        item.item ||
        item.name
      ),


    barcode:
      stringValue(
        item.barcode ||
        item.item
      ),


    pieces:
      pieces,


    quantity:
      quantity,


    price:
      price,


    originalcp:
      originalcp,


    total:
      total,


    gross:
      numberValue(
        item.gross,
        total
      ),


    discount:
      discount,


    vat:
      numberValue(
        item.vat,
        0
      ),


    stockingmode:
      stringValue(
        item.modes ||
        item.mode ||
        item.stockingmode,
        "Single"
      ),


    modeqty:
      stringValue(
        item.modeqty,
        "1"
      ),


    boxpiece:
      stringValue(
        item.boxpieces ??
        item.boxpiece,
        "1"
      ),


    pcategory:
      stringValue(
        item.product_category ||
        item.pcategory ||
        item.category
      ),


    producttype:
      stringValue(
        item.product_type ||
        item.producttype,
        "Product"
      ),


    branchname:
      branchname,


    stockin_pieces:
      numberValue(
        item.stockin_pieces,
        pieces
      ),


    stock_value:
      numberValue(
        item.stock_value,
        total
      ),


    syncstatus:
      item.syncstatus === true
  };
}

function normalizePurchaseType(value) {

  const mode =stringValue(value).toLowerCase();

  if (mode === "credit purchase") {
    return "credit";
  }

  if (mode === "cash purchase") {
    return "cash";
  }

  return mode;
}


async function createCreditSupplier(transaction) {

  if (
    transaction.purchasetype !== "credit"
  ) {
    return null;
  }


  const supplier =
    stringValue(
      transaction.suppliername
    );


  if (!supplier) {

    throw new Error(
      `Credit purchase ${transaction.transactionid} is missing supplier name.`
    );
  }


  const supplierId =
    `${transaction.companyid}_${supplier}`.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");


  const supplierRef =db .collection("suppliers").doc(supplierId);
  const now =admin.firestore.Timestamp.now();
  const existing =await supplierRef.get();

  if (!existing.exists) {

    await supplierRef.set({

      branchid: transaction.branchid,

      company:transaction.company,

      companyid:transaction.companyid,

      contact: stringValue(transaction.suppliercontact),

      datecreated: now,

      id:  supplierId,

      lastupdate: now,

      staff: transaction.createdby,

      supplier:  supplier

    });


  } else {


    await supplierRef.update({

      branchid: transaction.branchid,

      company: transaction.company,

      companyid: transaction.companyid,

      contact:  stringValue( transaction.suppliercontact ),

      lastupdate: now,

      staff: transaction.createdby,

      supplier:  supplier

    });
  }


  console.log(
    "CREDIT SUPPLIER SAVED:",
    supplierId
  );


  return supplierId;
}
function normalizeStockTransaction(
  items,
  extra = {}
) {

  if (
    !Array.isArray(items) ||
    items.length === 0
  ) {
    throw new Error(
      "No stock items supplied."
    );
  }


  const first =
    items[0];



  const companyid =
    stringValue(
      extra.companyid ||
      extra.companyId ||
      first.companyid ||
      first.companyId
    );


  if (!companyid) {
    throw new Error(
      `Missing companyid for endpoint ID ${stringValue(first.id)}.`
    );
  }




  const tid =
    stringValue(
      extra.tid ||
      first.tid
    );


  if (!tid) {
    throw new Error(
      `Missing tid for company ${companyid}, endpoint ID ${stringValue(first.id)}.`
    );
  }



  const branchname =
    stringValue(
      extra.branchname ||
      extra.branchName ||
      first.branchname ||
      first.branchName ||
      first.supplybranch
    );


  if (!branchname) {
    throw new Error(
      `Missing branchname for TID ${tid}.`
    );
  }


  const branchid =
    stringValue(
      extra.branchid ||
      extra.branchId ||
      first.branchid ||
      first.branchId
    ) ||
    createBranchId(
      companyid,
      branchname
    );



  const transactionid =
    `${companyid}_${tid}`;


  const docid = transactionid;


  const now =admin.firestore.Timestamp.now();


  const createdat =
    first.createdat ||
    first.createdAt
      ? toTimestamp(
          first.createdat ||
          first.createdAt
        )
      : now;


  const invoicedate =
    first.date
      ? toTimestamp(
          first.date
        )
      : now;


  const itemArray = [];


  let gross = 0;


  items.forEach(
    (item) => {

      const normalizedItem =
        normalizeLegacyItem(
          item,
          {
            companyid:
              companyid,

            branchid:
              branchid,

            branchname:
              branchname
          }
        );


      itemArray.push(
        normalizedItem
      );


      gross +=
        numberValue(
          item.total
        );
    }
  );


  /*
   * ------------------------------------------------------------
   * NET VALUE
   * ------------------------------------------------------------
   */

  const netval =
    numberValue(
      extra.netval,
      gross
    );



  const suppliername =
    stringValue(
      first.tname ||
      extra.suppliername
    );


  const supplierid =
    stringValue(
      extra.supplierid
    ) ||
    (
      suppliername
        ? `${companyid}_${suppliername}`
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, "_")
            .replace(/^_|_$/g, "")
        : ""
    );


  return {

    branchType:
      stringValue(
        extra.branchType,
        "Sales Branch"
      ),


    branchid:
      branchid,


    branchname:
      branchname,


    company:
      stringValue(
        extra.company ||
        extra.companyname ||
        first.company ||
        first.companyname ||
        first.tname
      ),


    companyid:
      companyid,


    createdat:
      createdat,


    createdby:
      stringValue(
        first.staff ||
        first.createdby ||
        first.createdBy
      ),


    date:
      stringValue(
        first.date
      ),


    day:
      stringValue(
        first.day
      ),


    discount:
      numberValue(
        first.discount,
        0
      ),


    docid:
      docid,


    gross:
      gross,


    invoice:
      stringValue(
        first.invoiceno
      ),


    invoicedate:
      invoicedate,


    itemCount:
      itemArray.length,


    items:
      itemArray,


    lastSyncAttemptAt:
      now,


    lastSyncedAt:
      now,


    month:
      stringValue(
        first.month
      ),


    netval:
      netval,


    paymentaccount:
      stringValue(
        first.payaccount
      ),


   purchasetype:
     normalizePurchaseType(
       first.transmode ||
       first.transMode
     ),


    staffbranch:
      branchname,


    staffbranchid:
      branchid,


    staffemail:
      stringValue(
        extra.staffemail ||
        first.staffemail
      ),


    stocktype:
      stringValue(
        first.stocktype
      ),


    supplierid:
      supplierid,


    suppliername:
      suppliername,


    syncstatus:
      true,


    syncstatuu:
      true,


    tax:
      numberValue(
        first.tax ||
        first.vat,
        0
      ),


    tid:
      tid,


    timestamp:
      Number(
        first.timestamp ||
        Date.now()
      ),


    transactionid:
      transactionid,


    uploadedby:
      stringValue(
        first.staff
      ),


    waybill:
      stringValue(
        first.waybill
      ),


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
 * CREATE DAMAGE MODE MAP
 * ============================================================
 *
 * The endpoint normally supplies:
 *
 * modes: "Carton"
 * selling_price: "48"
 * cost_price: "46"
 * boxpieces: "1"
 *
 * We create the selected mode using those values.
 */

function createDamageModes(item) {

  const modeName =
    stringValue(
      item.modes ||
      item.mode ||
      item.stockingmode,
      "Single"
    );


  const modeId =
    modeName
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "");


  const cp =
    numberValue(
      item.cost_price ||
      item.cp,
      0
    );


  const sp =
    numberValue(
      item.selling_price ||
      item.price,
      0
    );


  const wp =
    numberValue(
      item.wselling_price ||
      item.wholesaleprice ||
      sp,
      sp
    );


  const rp =
    numberValue(
      item.selling_price ||
      item.retailprice ||
      sp,
      sp
    );


  const qty =
    stringValue(
      item.boxpieces,
      "1"
    );


  const modes = {};


  modes[modeId] = {

    cp:
      String(cp),


    id:
      modeId,


    name:
      modeName,


    qty:
      qty,


    rp:
      String(rp),


    sp:
      String(sp),


    wp:
      String(wp)
  };


  /*
   * If the endpoint mode is not Single,
   * also provide a Single mode.
   */

  if (
    modeId !== "single"
  ) {

    modes.single = {

      cp:
        String(cp),

      id:
        "single",

      name:
        "Single",

      qty:
        "1",

      rp:
        String(sp),

      sp:
        String(sp),

      wp:
        String(wp)
    };
  }


  return modes;
}


/*
 * ============================================================
 * NORMALIZE DAMAGE ITEM
 * ============================================================
 */

function normalizeDamageItem(
  item,
  transaction,
  index
) {

  if (
    !item ||
    typeof item !== "object"
  ) {
    throw new Error(
      "Invalid damage item."
    );
  }


  const companyid =
    stringValue(
      item.companyid ||
      transaction.companyid
    );


  const branchid =
    stringValue(
      item.branchid ||
      transaction.branchid
    );


  const branchname =
    stringValue(
      item.branchname ||
      item.supplybranch ||
      transaction.branchname
    );


  const itemid =
    createItemId(
      {
        ...item,
        companyid
      }
    );


  if (!itemid) {
    throw new Error(
      `Missing item name/itemid for damage item ${index}.`
    );
  }


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


  const cp =
    numberValue(
      item.cost_price ||
      item.cp,
      0
    );


  const total =
    numberValue(
      item.total,
      cp * quantity
    );


  const now =
    admin.firestore.Timestamp.now();


  return {

    barcode:
      stringValue(
        item.barcode ||
        item.item
      ),


    boxpiece:
      stringValue(
        item.boxpieces ||
        item.boxpiece,
        "1"
      ),


    branchid:
      branchid,


    branchname:
      branchname,


    cp:
      String(cp),


    dateymd:
      stringValue(
        item.dateymd ||
        item.date ||
        transaction.dateymd
      ),


    day:
      stringValue(
        item.day ||
        transaction.day
      ),


    grandtotal:
      total.toFixed(2),


    item:
      stringValue(
        item.item ||
        item.name
      ),


    itemid:
      itemid,


    mode:
      stringValue(
        item.modes ||
        item.mode ||
        item.stockingmode,
        "Single"
      ),


    modeqty:
      stringValue(
        item.modeqty,
        "1"
      ),


    modes:
      createDamageModes(
        item
      ),


    month:
      stringValue(
        item.month ||
        transaction.month
      ),


    quantity:
      String(
        quantity
      ),


    reason:
      stringValue(
        item.reason,
        "Damaged"
      ),


    supplier:
      stringValue(
        item.tname ||
        item.supplier ||
        transaction.suppliername
      ),


    totalpieces:
      pieces,


    week:
      stringValue(
        item.week ||
        transaction.week
      ),


    year:
      stringValue(
        item.year ||
        transaction.year
      )
  };
}


/*
 * ============================================================
 * NORMALIZE DAMAGE TRANSACTION
 * ============================================================
 *
 * Firestore:
 *
 * damageitems/{companyid_tid}
 *
 * Schema:
 *
 * {
 *   item: {
 *      item_0: {...},
 *      item_1: {...}
 *   }
 * }
 */

function normalizeDamageTransaction(
  items,
  extra = {}
) {

  if (
    !Array.isArray(items) ||
    items.length === 0
  ) {
    throw new Error(
      "No damage items supplied."
    );
  }


  const first =
    items[0];


  /*
   * ------------------------------------------------------------
   * COMPANY
   * ------------------------------------------------------------
 */

  const companyid =
    stringValue(
      extra.companyid ||
      extra.companyId ||
      first.companyid ||
      first.companyId
    );


  if (!companyid) {
    throw new Error(
      `Missing companyid for damage endpoint ID ${stringValue(first.id)}.`
    );
  }


  /*
   * ------------------------------------------------------------
   * TID
   * ------------------------------------------------------------
   */

  const tid =
    stringValue(
      extra.tid ||
      first.tid
    );


  if (!tid) {
    throw new Error(
      `Missing tid for damage company ${companyid}, endpoint ID ${stringValue(first.id)}.`
    );
  }


  /*
   * ------------------------------------------------------------
   * BRANCH
   * ------------------------------------------------------------
 */

  const branchname =
    stringValue(
      extra.branchname ||
      extra.branchName ||
      first.branchname ||
      first.branchName ||
      first.supplybranch
    );


  if (!branchname) {
    throw new Error(
      `Missing branchname for damage TID ${tid}.`
    );
  }


  const branchid =
    stringValue(
      extra.branchid ||
      extra.branchId ||
      first.branchid ||
      first.branchId
    ) ||
    createBranchId(
      companyid,
      branchname
    );


  /*
   * ------------------------------------------------------------
   * TRANSACTION ID
   * ------------------------------------------------------------
 */

  const transactionid =
    `${companyid}_${tid}`;


  /*
   * ------------------------------------------------------------
   * TIMESTAMP
   * ------------------------------------------------------------
 */

  const now =
    admin.firestore.Timestamp.now();


  const createdat =
    first.createdat ||
    first.createdAt
      ? toTimestamp(
          first.createdat ||
          first.createdAt
        )
      : now;


  /*
   * ------------------------------------------------------------
   * DAMAGE ITEMS MAP
   * ------------------------------------------------------------
 */

  const itemMap = {};


  let grandtotal = 0;


  let totalpieces = 0;


  items.forEach(
    (item, index) => {

      const damageItem =
        normalizeDamageItem(
          item,
          {
            companyid:
              companyid,

            branchid:
              branchid,

            branchname:
              branchname,

            dateymd:
              stringValue(
                first.dateymd ||
                first.date
              ),

            day:
              stringValue(
                first.day
              ),

            month:
              stringValue(
                first.month
              ),

            week:
              stringValue(
                first.week
              ),

            year:
              stringValue(
                first.year
              ),

            suppliername:
              stringValue(
                first.tname
              )
          },
          index
        );


      itemMap[
        `item_${index}`
      ] =
        damageItem;


      grandtotal +=
        numberValue(
          item.total,
          numberValue(
            item.cost_price,
            0
          ) *
          numberValue(
            item.quantity,
            0
          )
        );


      totalpieces +=
        numberValue(
          item.pieces,
          item.quantity
        );
    }
  );


  /*
   * ------------------------------------------------------------
   * DAMAGE DOCUMENT ID
   * ------------------------------------------------------------
 */

  const docid =
    transactionid;


  /*
   * ------------------------------------------------------------
   * FINAL DAMAGE DOCUMENT
   * ------------------------------------------------------------
 */

  return {

    branchid:
      branchid,


    branchname:
      branchname,


    company:
      stringValue(
        extra.company ||
        extra.companyname ||
        first.company ||
        first.companyname ||
        first.tname
      ),


    companyid:
      companyid,


    createdat:
      createdat,


    createdby:
      stringValue(
        first.staff ||
        first.createdby ||
        first.createdBy
      ),


    dateymd:
      stringValue(
        first.dateymd ||
        first.date
      ),


    deletedat:
      null,


    deletedby:
      null,


    description:
      stringValue(
        first.description
      ),


    grandtotal:
      grandtotal.toFixed(2),


    id:
      docid,


    item:
      itemMap,


    itemcount:
      String(
        items.length
      ),


    staffposition:
      String(
        first.staffposition ??
        first.staffPosition ??
        "0"
      ),


    updatedat:
      null,


    updatedby:
      null
  };
}


/*
 * ============================================================
 * DETERMINE TRANSACTION TYPE
 * ============================================================
 */

function getTransactionType(
  items,
  extra = {}
) {

  const first =
    items[0];


  return stringValue(
    extra.transmode ||
    extra.transMode ||
    first.transmode ||
    first.transMode
  ).toLowerCase();
}


/*
 * ============================================================
 * UPLOAD STOCK
 * ============================================================
 */

exports.uploadStock =
  functions.https.onRequest(
    async (req, res) => {



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

        return res
          .status(405)
          .json({

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
          "STOCK / DAMAGE UPLOAD ENDPOINT"
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
          "BODY RECEIVED:"
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
         * GET ENDPOINT ITEMS
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

          return res
            .status(400)
            .json({

              success:
                false,

              error:
                "Invalid request body."
            });
        }


        if (
          legacyItems.length === 0
        ) {

          return res
            .status(400)
            .json({

              success:
                false,

              error:
                "No stock items supplied."
            });
        }


        console.log(
          "ENDPOINT ITEMS:",
          legacyItems.length
        );


        /*
         * ======================================================
         * GROUP BY TID
         * ======================================================
         *
         * Same TID = ONE transaction.
         *
         * Example:
         *
         * id 1119, tid 1786005883
         * id 1120, tid 1786005883
         *
         * becomes:
         *
         * KS000_1786005883
         *
         * with:
         *
         * item_0
         * item_1
         *
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


          const companyid =
            stringValue(
              item.companyid
            );


          if (!companyid) {

            throw new Error(
              `Endpoint record ${stringValue(item.id)} is missing companyid.`
            );
          }


          if (!tid) {

            throw new Error(
              `Endpoint record ${stringValue(item.id)} is missing tid.`
            );
          }


          /*
           * IMPORTANT:
           *
           * Group by company + tid,
           * not just tid.
           *
           * This prevents:
           *
           * KS000 + 123
           *
           * and
           *
           * KS001 + 123
           *
           * from being combined.
           */

          const groupKey =
            `${companyid}_${tid}`;


          if (
            !grouped[groupKey]
          ) {

            grouped[groupKey] = [];
          }


          grouped[groupKey].push(
            item
          );
        }


        console.log(
          "TRANSACTIONS FOUND:",
          Object.keys(grouped)
        );


        /*
         * ======================================================
         * RESPONSE ARRAYS
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
          const [
            groupKey,
            items
          ]
          of Object.entries(
            grouped
          )
        ) {

          console.log("");
          console.log(
            "================================================"
          );


          console.log(
            "PROCESSING:",
            groupKey
          );


          console.log(
            "ITEM COUNT:",
            items.length
          );


          console.log(
            "================================================"
          );


          /*
           * ----------------------------------------------------
           * REQUEST WRAPPER
           * ----------------------------------------------------
           */

          const extra =
            body &&
            !Array.isArray(body) &&
            Array.isArray(body.data)
              ? body
              : {};


          /*
           * ----------------------------------------------------
           * DETERMINE TRANSACTION TYPE
           * ----------------------------------------------------
           */

          const transmode =
            getTransactionType(
              items,
              extra
            );


          console.log(
            "TRANSMODE:",
            transmode
          );


          /*
           * ====================================================
           * DAMAGE
           * ====================================================
           */

          if (
            transmode === "damages" ||
            transmode === "damage"
          ) {

            console.log(
              "ROUTE: damageitems"
            );


            const document =
              normalizeDamageTransaction(
                items,
                extra
              );


            console.log(
              "DAMAGE DOCUMENT ID:",
              document.id
            );


            console.log(
              "DAMAGE ITEM COUNT:",
              document.itemcount
            );


            console.log(
              "DAMAGE GRAND TOTAL:",
              document.grandtotal
            );


            console.log("");
            console.log(
              "================================================"
            );


            console.log(
              "COMPLETE DAMAGE DOCUMENT"
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
             * --------------------------------------------------
             * SAVE TO DAMAGEITEMS
             * --------------------------------------------------
             */

            const docRef =
              db
                .collection(
                  "damageitems"
                )
                .doc(
                  document.id
                );


            await docRef.set(
              document,
              {
                merge:
                  true
              }
            );


            /*
             * --------------------------------------------------
             * VERIFY
             * --------------------------------------------------
             */

            const savedDoc =
              await docRef.get();


            if (
              !savedDoc.exists
            ) {

              throw new Error(
                `Firestore damage write verification failed for ${document.id}.`
              );
            }


            /*
             * --------------------------------------------------
             * RETURN ORIGINAL ENDPOINT IDS
             * --------------------------------------------------
             */

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
              "ENDPOINT IDS:",
              apiIds
            );


            successfulIds.push(
              ...apiIds
            );


            successfulTransactions.push({

              tid:
                stringValue(
                  items[0].tid
                ),

              type:
                "damages",

              collection:
                "damageitems",

              firestoreId:
                document.id,

              endpointIds:
                apiIds,

              itemCount:
                document.itemcount,

              firestoreSaved:
                true
            });


            continue;
          }


          /*
           * ====================================================
           * STOCK TRANSACTION
           * ====================================================
           *
           * cash purchase
           * credit purchase
           * opening balance
           * ====================================================
           */

          if (
            transmode === "cash purchase" ||
            transmode === "credit purchase" ||
            transmode === "opening balance"
          ) {

            console.log(
              "ROUTE: stock_transactions"
            );


            const document =
              normalizeStockTransaction(
                items,
                extra
              );


            console.log(
              "STOCK DOCUMENT ID:",
              document.docid
            );


            console.log(
              "TRANSACTION ID:",
              document.transactionid
            );


            console.log(
              "ITEM COUNT:",
              document.itemCount
            );


            console.log(
              "GROSS:",
              document.gross
            );


            console.log(
              "NET VALUE:",
              document.netval
            );


            console.log("");
            console.log(
              "================================================"
            );


            console.log(
              "COMPLETE STOCK TRANSACTION DOCUMENT"
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
            if (
              document.purchasetype === "credit"
            ) {

              const supplierId =await createCreditSupplier(document);

              console.log(
                "SUPPLIER ID:",
                supplierId
              );
            }

            const docRef = db .collection( "stock_transactions").doc( document.docid);
            await docRef.set( document, {merge: true } );
            const savedDoc =await docRef.get();

            if (
              !savedDoc.exists
            ) {

              throw new Error(
                `Firestore stock write verification failed for ${document.docid}.`
              );
            }



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
              "ENDPOINT IDS:",
              apiIds
            );


            successfulIds.push(
              ...apiIds
            );


            successfulTransactions.push({

              tid:
                document.tid,

              type:
                transmode,

              collection:
                "stock_transactions",

              firestoreId:
                document.docid,

              endpointIds:
                apiIds,

              itemCount:
                document.itemCount,

              firestoreSaved:
                true
            });


            continue;
          }


          /*
           * ====================================================
           * UNSUPPORTED TRANSACTION TYPE
           * ====================================================
           */

          throw new Error(
            `Unsupported transmode "${transmode}" for TID ${stringValue(items[0].tid)}. ` +
            `Expected damages, cash purchase, credit purchase, or opening balance.`
          );
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
          "ALL TRANSACTIONS SAVED SUCCESSFULLY"
        );


        return res
          .status(200)
          .json({

            success:
              true,


            saved:
              true,


            count:
              successfulIds.length,


            /*
             * ORIGINAL ENDPOINT IDs
             */

            ids:
              successfulIds,


            message:
              "saved successfully."
          });


      } catch (error) {

        console.error("");
        console.error(
          "================================================"
        );


        console.error(
          "STOCK / DAMAGE REMAPPING ERROR"
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


        return res
          .status(500)
          .json({

            success:
              false,


            saved:
              false,


            firestoreWrite:
              false,


            error:
              error.message ||
              "Failed to remap and save transaction."
          });
      }
    }
  );