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

  if (
    value === null ||
    value === undefined
  ) {
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


  if (
    value instanceof Date
  ) {

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


/*
 * ============================================================
 * CREATE SAFE FIRESTORE ID
 * ============================================================
 */

function makeItemId(
  companyid,
  name
) {

  return `${companyid}${name}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "");
}


/*
 * ============================================================
 * CREATE BRANCH ID
 * ============================================================
 */

function makeBranchId(
  companyid,
  branchname
) {

  if (!branchname) {
    return "";
  }

  return `${companyid}${branchname}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}


/*
 * ============================================================
 * NORMALIZE ITEMSREG PRODUCT
 * ============================================================
 */

function normalizeItemsregItem(
  item,
  extra = {}
) {

  if (
    !item ||
    typeof item !== "object"
  ) {

    throw new Error(
      "Invalid itemsreg product."
    );
  }


  /*
   * ==========================================================
   * COMPANY
   * ==========================================================
   */

  const companyid =
    stringValue(
      extra.companyid ||
      extra.companyId ||
      item.companyid ||
      item.companyId
    );


  if (!companyid) {

    throw new Error(
      "Missing companyid."
    );
  }


  /*
   * ==========================================================
   * PRODUCT NAME
   * ==========================================================
   */

  const name =
    stringValue(
      item.name ||
      item.item
    );


  if (!name) {

    throw new Error(
      "Missing product name."
    );
  }


  /*
   * ==========================================================
   * BARCODE
   * ==========================================================
   */

  const barcode =
    stringValue(
      item.barcode ||
      item.sysbarcode ||
      name
    );


  /*
   * ==========================================================
   * COST PRICE
   *
   * Existing itemsreg schema stores cp as STRING.
   * ==========================================================
   */

  const cp =
    stringValue(
      item.cost_price ||
      item.cp,
      "0"
    );



  const sellingPrice =
    stringValue(
      item.sselling_price ||
      item.selling_price ||
      item.wselling_price,
      "0"
    );


  const retailPrice =
    stringValue(
      item.sselling_price ||
      item.selling_price,
      sellingPrice
    );


  const wholesalePrice =
    stringValue(
      item.wselling_price ||
      item.sselling_price ||
      item.selling_price,
      sellingPrice
    );


  /*
   * ==========================================================
   * BOX PIECES
   * ==========================================================
   */

  const boxpieces =
    stringValue(
      item.boxpieces,
      "1"
    );




  const endpointMode =
    stringValue(
      item.mode,
      "Single"
    );


  const modeKey =
    endpointMode
      .toLowerCase()
      .replace(/\s+/g, "");



  const branchname =
    stringValue(
      extra.branchname ||
      extra.branchName ||
      item.branch ||
      item.branchname
    );


  const branchid =
    stringValue(
      extra.branchid ||
      extra.branchId ||
      item.branchid
    ) ||
    makeBranchId(
      companyid,
      branchname
    );




  const balance =
    numberValue(
      item.balance,
      0
    );



  const branchbalance = {};


  if (branchid) {

    branchbalance[branchid] = {

      balance:
        balance,

      branchid:
        branchid,

      branchname:
        branchname
    };
  }


  /*
   * ==========================================================
   * MODES
   *
   * Existing itemsreg structure:
   *
   * modes
   *   carton
   *   half
   *   quarter
   *   single
   *
   * ==========================================================
   */

  const modes = {};


  /*
   * ----------------------------------------------------------
   * SINGLE
   * ----------------------------------------------------------
   */

  modes.single = {

    cp:
      cp,

    id:
      "single",

    name:
      "Single",

    qty:
      "1",

    rp:
      retailPrice,

    sp:
      retailPrice,

    wp:
      wholesalePrice
  };


  /*
   * ----------------------------------------------------------
   * CARTON
   * ----------------------------------------------------------
   */

  modes.carton = {

    cp:
      cp,

    id:
      "carton",

    name:
      "Carton",

    qty:
      boxpieces,

    rp:
      retailPrice,

    sp:
      retailPrice,

    wp:
      wholesalePrice
  };


  /*
   * ----------------------------------------------------------
   * HALF CARTON
   *
   * Only create calculated modes when boxpieces > 1.
   * ----------------------------------------------------------
   */

  const boxQty =
    numberValue(
      boxpieces,
      1
    );


  if (boxQty > 1) {

    const halfQty =
      boxQty / 2;


    const quarterQty =
      boxQty / 4;


    modes.half = {

      cp:
        (
          numberValue(cp) *
          0.5
        ).toFixed(2),

      id:
        "half",

      name:
        "Half Carton",

      qty:
        String(halfQty),

      rp:
        (
          numberValue(retailPrice) *
          0.5
        ).toFixed(2),

      sp:
        (
          numberValue(retailPrice) *
          0.5
        ).toFixed(2),

      wp:
        (
          numberValue(wholesalePrice) *
          0.5
        ).toFixed(2)
    };


    modes.quarter = {

      cp:
        (
          numberValue(cp) *
          0.25
        ).toFixed(2),

      id:
        "quarter",

      name:
        "Quarter Carton",

      qty:
        String(quarterQty),

      rp:
        (
          numberValue(retailPrice) *
          0.25
        ).toFixed(2),

      sp:
        (
          numberValue(retailPrice) *
          0.25
        ).toFixed(2),

      wp:
        (
          numberValue(wholesalePrice) *
          0.25
        ).toFixed(2)
    };
  }


  /*
   * ==========================================================
   * DATE
   * ==========================================================
   */

  const now =
    admin.firestore.Timestamp.now();


  const createdat =
    item.createdat ||
    item.createdAt ||
    item.date
      ? toTimestamp(
          item.createdat ||
          item.createdAt ||
          item.date
        )
      : now;


  /*
   * ==========================================================
   * DOCUMENT ID
   *
   * Example:
   *
   * KS000 + Lavita 80g ×100
   *
   * =>
   *
   * ks000lavita80g100
   * ==========================================================
   */

  const id =
    stringValue(
      item.id
    ) &&
    stringValue(
      item.id
    ) !== "0"
      ? makeItemId(
          companyid,
          name
        )
      : makeItemId(
          companyid,
          name
        );


  /*
   * ==========================================================
   * FINAL ITEMSREG DOCUMENT
   * ==========================================================
   */

  return {

    barcode:
      barcode,


    branchbalance:
      branchbalance,


    branchprices:
      null,


    company:
      stringValue(
        extra.company ||
        extra.companyname ||
        item.company
      ),


    companyid:
      companyid,


    cp:
      cp,


    createdat:
      createdat,


    dailytransactions:
      null,


    day:
      stringValue(
        extra.day ||
        item.day
      ),


    deletedat:
      null,


    deletedby:
      null,


    id:
      id,


    imageurl:
      stringValue(
        item.image ||
        item.imageurl
      ),


    isActive:
      true,


    isHamper:
      false,


    items:
      null,


    lastModified:
      now,


    lastStockTransactionId:
      stringValue(
        item.lastStockTransactionId
      ),


    modemore:
      true,


    modes:
      modes,


    month:
      stringValue(
        extra.month ||
        item.month
      ),


    name:
      name.toUpperCase(),


    openingstock:
      "",


    pcategory:
      stringValue(
        item.category ||
        item.pcategory
      ),


    pricingmode:
      false,


    producttype:
      stringValue(
        item.product_type ||
        item.producttype,
        "product"
      ),


    retailmarkup:
      stringValue(
        item.rmarkup,
        ""
      ),


    retailprice:
      retailPrice,


    sminqty:
      "",


    staff:
      stringValue(
        extra.staff ||
        item.staff
      ),


    updatedat:
      null,


    updatedby:
      null,


    warehouse:
      stringValue(
        item.warehouse
      ),


    week:
      stringValue(
        extra.week ||
        item.week
      ),


    wholesalemarkup:
      stringValue(
        item.wmarkup,
        ""
      ),


    wholesaleprice:
      wholesalePrice,


    wminqty:
      "",


    year:
      stringValue(
        extra.year ||
        item.year
      )
  };
}


/*
 * ============================================================
 * UPLOAD ITEMSREG
 * ============================================================
 */

exports.uploadItemsreg =
  functions.https.onRequest(
    async (req, res) => {


      /*
       * ========================================================
       * CORS
       * ========================================================
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
          "ITEMSREG UPLOAD ENDPOINT"
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
         * GET API PRODUCTS
         * ======================================================
         */

        let apiItems = [];


        if (
          body &&
          Array.isArray(
            body.data
          )
        ) {

          apiItems =
            body.data;

        }

        else if (
          Array.isArray(body)
        ) {

          apiItems =
            body;

        }

        else if (
          body &&
          typeof body === "object"
        ) {

          apiItems = [
            body
          ];

        }

        else {

          return res.status(400).json({

            success:
              false,

            error:
              "Invalid request body."
          });
        }


        /*
         * ======================================================
         * EMPTY CHECK
         * ======================================================
         */

        if (
          apiItems.length === 0
        ) {

          return res.status(400).json({

            success:
              false,

            error:
              "No products supplied."
          });
        }


        console.log(
          "API PRODUCTS:",
          apiItems.length
        );


        /*
         * ======================================================
         * EXTRA / WRAPPER VALUES
         * ======================================================
         */

        const extra =
          body &&
          !Array.isArray(body) &&
          Array.isArray(body.data)
            ? body
            : {};


        /*
         * ======================================================
         * RESULTS
         * ======================================================
         */

        const successfulIds =
          [];


        const successfulProducts =
          [];


        /*
         * ======================================================
         * PROCESS EACH PRODUCT
         * ======================================================
         */

        for (
          const item
          of apiItems
        ) {


          console.log("");
          console.log(
            "================================================"
          );


          console.log(
            "PROCESSING PRODUCT"
          );


          console.log(
            "NAME:",
            item.name
          );


          console.log(
            "COMPANY:",
            item.companyid
          );


          console.log(
            "================================================"
          );


          /*
           * ----------------------------------------------------
           * NORMALIZE
           * ----------------------------------------------------
           */

          const document =
            normalizeItemsregItem(
              item,
              extra
            );


          /*
           * ----------------------------------------------------
           * LOG TARGET DOCUMENT ID
           * ----------------------------------------------------
           */

          console.log(
            "Itemsreg document ID:",
            document.id
          );


          /*
           * ----------------------------------------------------
           * LOG COMPLETE DOCUMENT
           * ----------------------------------------------------
           */

          console.log("");
          console.log(
            "================================================"
          );


          console.log(
            "COMPLETE ITEMSREG DOCUMENT"
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
           * ----------------------------------------------------
           */

          const docRef =
            db
              .collection(
                "itemsreg"
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
           * ----------------------------------------------------
           * VERIFY
           * ----------------------------------------------------
           */

          const savedDoc =
            await docRef.get();


          if (
            !savedDoc.exists
          ) {

            throw new Error(
              `Firestore write verification failed for ${document.id}.`
            );
          }


          console.log(
            "Firestore saved:",
            document.id
          );


          /*
           * ----------------------------------------------------
           * SUCCESS
           * ----------------------------------------------------
           */
  const endpointId =
    stringValue(item.id);



    successfulIds.push(
      endpointId
    );


          successfulProducts.push({

            id:
              endpointId,

            name:
              document.name,

            companyid:
              document.companyid,

            firestoreSaved:
              true
          });
        }


        /*
         * ======================================================
         * SUCCESS RESPONSE
         * ======================================================
         */

        console.log("");
        console.log(
          "================================================"
        );


        console.log(
          "ALL ITEMSREG PRODUCTS SAVED"
        );


        console.log(
          "IDS:",
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

          ids:
            successfulIds,

          message:
            "Products remapped and saved to itemsreg successfully."
        });


      }

      catch (error) {


        console.error("");
        console.error(
          "================================================"
        );


        console.error(
          "ITEMSREG REMAPPING ERROR"
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
            "Failed to remap and save itemsreg product."
        });
      }
    }
  );