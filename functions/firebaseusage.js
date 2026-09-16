const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { admin, db } = require("./fb");
const monitoring = require("@google-cloud/monitoring");

const monitoringClient = new monitoring.MetricServiceClient();

exports.getFirebaseUsage = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (request) => {
    try {
      // Optional: require authentication
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in to view Firebase usage."
        );
      }

      const projectId = process.env.GCLOUD_PROJECT;

      const startDate = request.data?.startDate
        ? new Date(request.data.startDate)
        : new Date(Date.now() - 24 * 60 * 60 * 1000);

      const endDate = request.data?.endDate
        ? new Date(request.data.endDate)
        : new Date();

      if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
        throw new HttpsError(
          "invalid-argument",
          "Invalid startDate or endDate."
        );
      }

      if (startDate >= endDate) {
        throw new HttpsError(
          "invalid-argument",
          "startDate must be before endDate."
        );
      }

      const reads = await getMetricTotal({
        projectId,
        metricType: "firestore.googleapis.com/document/read_count",
        startDate,
        endDate,
      });

      const writes = await getMetricTotal({
        projectId,
        metricType: "firestore.googleapis.com/document/write_count",
        startDate,
        endDate,
      });

      const deletes = await getMetricTotal({
        projectId,
        metricType: "firestore.googleapis.com/document/delete_count",
        startDate,
        endDate,
      });

      return {
        success: true,
        projectId,

        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),

        reads,
        writes,
        deletes,

        totalOperations: reads + writes + deletes,
      };
    } catch (error) {
      console.error("getFirebaseUsage error:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        error.message || "Unable to retrieve Firebase usage."
      );
    }
  }
);


/**
 * Query a Cloud Monitoring DELTA metric and
 * calculate the total value over the requested period.
 */
async function getMetricTotal({
  projectId,
  metricType,
  startDate,
  endDate,
}) {
  const request = {
    name: `projects/${projectId}`,

    filter: `
      metric.type = "${metricType}"
    `,

    interval: {
      startTime: {
        seconds: Math.floor(startDate.getTime() / 1000),
      },
      endTime: {
        seconds: Math.floor(endDate.getTime() / 1000),
      },
    },

    aggregation: {
      alignmentPeriod: {
        seconds: 3600,
      },

      perSeriesAligner: "ALIGN_SUM",

      crossSeriesReducer: "REDUCE_SUM",
    },

    view: "FULL",
  };

  let total = 0;

  const [timeSeries] = await monitoringClient.listTimeSeries(request);

  for (const series of timeSeries) {
    for (const point of series.points || []) {
      const value = point.value;

      if (value?.int64Value !== undefined) {
        total += Number(value.int64Value);
      } else if (value?.doubleValue !== undefined) {
        total += Number(value.doubleValue);
      }
    }
  }

  return Math.round(total);
}