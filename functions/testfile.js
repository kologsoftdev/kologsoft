const axios = require("axios");

/**
 * ================================================================
 * CONFIG
 * ================================================================
 */

const STOCK_API_URL = "https://amyent.com/pos/firebase/stock";
/**
 * ================================================================
 * HELPERS
 * ================================================================
 */

function numberValue(value, fallback = 0) {
  const n = Number(value);

  return Number.isFinite(n)
    ? n
    : fallback;
}


function round2(value) {
  return Number(
    numberValue(value).toFixed(2),
  );
}


function sanitize(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(
      /[^a-z0-9]+/g,
      "_",
    )
    .replace(
      /^_+|_+$/g,
      "");
}


/**
 * ================================================================
 * GET STOCK FROM API
 * ================================================================
 */

async function getStockFromApi() {

  console.log("");
  console.log(
    "================================================",
  );

  console.log(
    "GET STOCK FROM API",
  );

  console.log(
    "================================================",
  );


  const response =
    await axios.get(
      STOCK_API_URL,
      {
        timeout: 300000,
      },
    );


  console.log(
    "API status:",
    response.status,
  );

  console.log(
    "API success:",
    response.data?.success,
  );

  console.log(
    "API count:",
    response.data?.count,
  );


  return response.data?.data || [];
}


function groupByTid(records) {

  const grouped =
    new Map();


  for (
    const record
    of records
  ) {

    const tid =
      String(
        record.tid ?? "",
      ).trim();


    if (!tid) {

      console.warn(
        "Skipping record without tid:",
        record.id,
      );

      continue;
    }


    if (!grouped.has(tid)) {

      grouped.set(
        tid,
        [],
      );
    }


    grouped
      .get(tid)
      .push(record);
  }


  return grouped;
}


/**
 * ================================================================
 * BUILD ITEMS
 * ================================================================
 */

function buildTransactionItems(
  rows,
) {

  return rows.map(
    (record) => {

      const pieces =
        numberValue(
          record.pieces ??
          record.quantity ??
          0,
        );


      const quantity =
        numberValue(
          record.quantity ??
          0,
        );


      const costPrice =
        numberValue(
          record.cost_price ??
          0,
        );


      const discount =
        numberValue(
          record.discount ??
          0,
        );


      const vat =
        numberValue(
          record.vat ??
          0,
        );


      const stockValue =
        round2(
          costPrice *
          pieces,
        );


      const itemName =
        String(
          record.item ?? "",
        ).trim();


      const companyId =
        String(
          record.companyid ?? "",
        ).trim();


      const itemid =
        `${sanitize(companyId)}_` +
        `${sanitize(itemName)}`;


      return {

        itemid:
          itemid,

        item:
          itemName,

        barcode:
          String(
            record.barcode ??
            "",
          ),

        pieces:
          pieces,

        quantity:
          quantity,

        price:
          costPrice,

        originalcp:
          costPrice,

        total:
          stockValue,

        gross:
          stockValue,

        discount:
          discount,

        vat:
          vat,

        stockingmode:
          String(
            record.modes ??
            "single",
          ),

        modeqty:
          "1",

        boxpiece:
          "1",

        pcategory:
          String(
            record.product_category ??
            "",
          ),

        producttype:
          String(
            record.product_type ??
            "Product",
          ),

        branchname:
          String(
            record.branchname ??
            "",
          ),

        stockin_pieces:
          pieces,

        stock_value:
          stockValue,

        syncstatus:
          false,
      };
    },
  );
}


/**
 * ================================================================
 * BUILD ONE FIRESTORE TRANSACTION DOCUMENT
 * ================================================================
 */

function buildTransactionDocument(
  rows,
) {

  const first =
    rows[0];


  /**
   * --------------------------------------------------------------
   * BASIC API VALUES
   * --------------------------------------------------------------
   */

  const companyId =
    String(
      first.companyid ?? "",
    ).trim();


  const companyName =
    String(
      first.company ??
      first.companyname ??
      first.tname ??
      "",
    ).trim();


  const staffName =
    String(
      first.staff ??
      "",
    ).trim();


  const staffEmail =
    String(
      first.staffemail ??
      "",
    ).trim();


  const branchName =
    String(
      first.branchname ??
      "",
    ).trim();


  const branchType =
    String(
      first.branchType ??
      first.branchtype ??
      "Sales Branch",
    ).trim();


  const tid =
    String(
      first.tid ??
      "",
    ).trim();


  /**
   * --------------------------------------------------------------
   * BRANCH ID
   *
   * This creates:
   *
   * KS005 + STORE RETAIL
   *
   * =>
   *
   * ks005store_retail
   * --------------------------------------------------------------
   */

  const branchid =
    `${companyId
      .trim()
      .toLowerCase()}` +
    `${branchName
      .trim()
      .toLowerCase()
      .replace(
        /[^a-z0-9]+/g,
        "_",
      )}`;


  /**
   * --------------------------------------------------------------
   * DOCUMENT ID
   *
   * Example:
   *
   * ks005_storeretail_1758282528
   * --------------------------------------------------------------
   */

  const docid =
    `${sanitize(companyId)}_` +
    `${branchName
      .trim()
      .toLowerCase()
      .replace(
        /[^a-z0-9]+/g,
        "",
      )}_` +
    `${sanitize(tid)}`;


  /**
   * --------------------------------------------------------------
   * DATE
   * --------------------------------------------------------------
   */

  const date =
    String(
      first.date ??
      new Date()
        .toISOString()
        .slice(0, 10),
    ).trim();


  const dateParts =
    date.split("-");


  const year =
    Number(
      dateParts[0],
    );


  const month =
    Number(
      dateParts[1],
    );


  const day =
    Number(
      dateParts[2],
    );


  /**
   * --------------------------------------------------------------
   * DAY NAME
   * --------------------------------------------------------------
   */

  const dateObject =
    new Date(
      Date.UTC(
        year,
        month - 1,
        day,
      ),
    );


  const dayName =
    dateObject.toLocaleDateString(
      "en-US",
      {
        weekday: "long",
        timeZone: "UTC",
      },
    );


  /**
   * --------------------------------------------------------------
   * WEEK
   *
   * Your API already contains values such as:
   *
   * 2025.38
   *
   * so preserve that actual API value.
   * --------------------------------------------------------------
   */

  const week =
    String(
      first.week ??
      "",
    );


  /**
   * --------------------------------------------------------------
   * INVOICE
   * --------------------------------------------------------------
   */

  const invoice =
    String(
      first.invoice ??
      first.invoiceno ??
      "",
    );


  /**
   * --------------------------------------------------------------
   * WAYBILL
   * --------------------------------------------------------------
   */

  const waybill =
    String(
      first.waybill ??
      first.invoiceno ??
      "",
    );


  /**
   * --------------------------------------------------------------
   * TRANSACTION MODE
   *
   * Your API has:
   *
   * "credit purchase"
   *
   * If you want Firestore to contain:
   *
   * "credit"
   *
   * then normalize it here.
   * --------------------------------------------------------------
   */

  const rawTransmode =
    String(
      first.transmode ??
      "",
    )
      .trim()
      .toLowerCase();


  const transMode =
    rawTransmode
      .includes("credit")
      ? "credit"
      : rawTransmode;


  /**
   * --------------------------------------------------------------
   * SUPPLIER
   * --------------------------------------------------------------
   */

  const supplier =
    String(
      first.tname ??
      "",
    ).trim();


  const supplierid =
    `${companyId
      .trim()
      .toLowerCase()}_` +
    `${supplier
      .trim()
      .toLowerCase()
      .replace(
        /[^a-z0-9]+/g,
        "",
      )}`;


  /**
   * --------------------------------------------------------------
   * ITEMS
   * --------------------------------------------------------------
   */

  const items =
    buildTransactionItems(
      rows,
    );


  /**
   * --------------------------------------------------------------
   * TOTALS
   * --------------------------------------------------------------
   */

  const gross =
    round2(
      items.reduce(
        (
          total,
          item,
        ) =>
          total +
          numberValue(
            item.gross,
          ),
        0,
      ),
    );


  const discount =
    round2(
      items.reduce(
        (
          total,
          item,
        ) =>
          total +
          numberValue(
            item.discount,
          ),
        0,
      ),
    );


  /**
   * --------------------------------------------------------------
   * ACTUAL FIRESTORE DOCUMENT STRUCTURE
   *
   * IMPORTANT:
   *
   * This is the structure that will be saved.
   *
   * It is NOT the callable payload structure.
   * --------------------------------------------------------------
   */

  const document = {

    branchType:
      branchType,

    branchid:
      branchid,

    branchname:
      branchName,

    company:
      companyName,

    companyid:
      companyId,

    /**
     * This is represented as an ISO string here because this
     * test file is only PRINTING the structure.
     *
     * In the Cloud Function use:
     *
     * admin.firestore.Timestamp.now()
     */

    createdat:
      new Date()
        .toISOString(),

    createdby:
      staffName,

    date:
      date,

    day:
      dayName,

    discount:
      discount,

    docid:
      docid,

    gross:
      gross,

    invoice:
      invoice,

    /**
     * In the actual Cloud Function this must be:
     *
     * admin.firestore.Timestamp.fromDate(...)
     */

    invoicedate:
      new Date(
        Date.UTC(
          year,
          month - 1,
          day,
        ),
      ).toISOString(),

    itemCount:
      items.length,

    items:
      items,

    /**
     * These represent the synchronization timestamps.
     *
     * In the actual Cloud Function:
     *
     * admin.firestore.Timestamp.now()
     */

    lastSyncAttemptAt:
      new Date()
        .toISOString(),

    lastSyncedAt:
      new Date()
        .toISOString(),

    month:
      `${year}.${month}`,

    netval:
      gross,

    paymentaccount:
      transMode,

    purchasetype:
      transMode,

    staffemail:
      staffEmail,

    stocktype:
      "uploaded",

    supplierid:
      supplierid,

    suppliername:
      supplier,

    syncstatus:
      true,

    syncstatuu:
      true,

    tid:
      tid,

    timestamp:
      Date.now(),

    transactionid:
      docid,

    uploadedby:
      staffName,

    waybill:
      waybill,

    week:
      week,

    year:
      String(year),
  };


  return document;
}


/**
 * ================================================================
 * MAIN TEST
 *
 * NO POST
 * NO CLOUD FUNCTION CALL
 * NO FIRESTORE WRITE
 *
 * ONLY:
 *
 * API -> GROUP -> FIRESTORE STRUCTURE -> PRINT
 * ================================================================
 */

async function testUploadStock() {

  try {

    /**
     * ------------------------------------------------------------
     * 1. GET API
     * ------------------------------------------------------------
     */

    const records =
      await getStockFromApi();


    if (
      !Array.isArray(records) ||
      records.length === 0
    ) {

      throw new Error(
        "API returned zero stock records.",
      );
    }


    console.log("");
    console.log(
      "API records received:",
      records.length,
    );


    /**
     * ------------------------------------------------------------
     * 2. GROUP BY TID
     * ------------------------------------------------------------
     */

    const grouped =
      groupByTid(
        records,
      );


    console.log("");
    console.log(
      "Transactions:",
      grouped.size,
    );


    /**
     * ------------------------------------------------------------
     * 3. BUILD EACH FIRESTORE DOCUMENT
     * ------------------------------------------------------------
     */

    let transactionNumber = 0;


    for (
      const [
        tid,
        rows,
      ]
      of grouped.entries()
    ) {

      transactionNumber++;


      const document =
        buildTransactionDocument(
          rows,
        );


      console.log("");
      console.log(
        "================================================",
      );

      console.log(
        `TRANSACTION ${transactionNumber}`,
      );

      console.log(
        "================================================",
      );

      console.log(
        "TID:",
        tid,
      );

      console.log(
        "Document ID:",
        document.docid,
      );

      console.log(
        "Items:",
        document.itemCount,
      );

      console.log(
        "Gross:",
        document.gross,
      );


      console.log("");
      console.log(
        "ACTUAL FIRESTORE DOCUMENT STRUCTURE",
      );

      console.log(
        "================================================",
      );


      console.log(
        JSON.stringify(
          document,
          null,
          2,
        ),
      );
    }


    /**
     * ------------------------------------------------------------
     * 4. CONFIRM NOTHING WAS POSTED
     * ------------------------------------------------------------
     */

    console.log("");
    console.log(
      "================================================",
    );

    console.log(
      "TEST COMPLETE",
    );

    console.log(
      "================================================",
    );

    console.log(
      "API was READ only.",
    );

    console.log(
      "No axios POST was performed.",
    );

    console.log(
      "No Cloud Function was called.",
    );

    console.log(
      "No Firestore document was written.",
    );

  } catch (error) {

    console.log("");
    console.log(
      "================================================",
    );

    console.log(
      "TEST ERROR",
    );

    console.log(
      "================================================",
    );

    console.error(
      "Message:",
      error.message,
    );

    if (error.response) {

      console.error(
        "HTTP status:",
        error.response.status,
      );

      console.error(
        "Response:",
        JSON.stringify(
          error.response.data,
          null,
          2,
        ),
      );
    }

    console.error(
      error.stack,
    );
  }
}


testUploadStock();