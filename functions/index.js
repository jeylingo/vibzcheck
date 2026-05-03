const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

exports.dispatchRoomEventNotification = onDocumentCreated(
  "rooms/{roomId}/events/{eventId}",
  async (event) => {
    if (!event.data) {
      return;
    }

    const roomId = event.params.roomId;
    const eventData = event.data.data() || {};
    const title = (eventData.title || "Room Update").toString();
    const body = (eventData.body || "Something changed in your room.").toString();
    const type = (eventData.type || "room_event").toString();
    const targetUserIds = Array.isArray(eventData.targetUserIds)
      ? eventData.targetUserIds.map((id) => id.toString()).filter((id) => id)
      : [];

    if (targetUserIds.length === 0) {
      logger.info("No target users for room event", { roomId, type });
      return;
    }

    const tokenSet = new Set();

    await Promise.all(
      targetUserIds.map(async (uid) => {
        const userSnap = await admin.firestore().collection("users").doc(uid).get();
        if (!userSnap.exists) {
          return;
        }

        const userData = userSnap.data() || {};
        const fcmTokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];
        for (const token of fcmTokens) {
          if (typeof token === "string" && token.length > 0) {
            tokenSet.add(token);
          }
        }
      })
    );

    const tokens = [...tokenSet];
    if (tokens.length === 0) {
      logger.info("No FCM tokens found for room event", { roomId, type, targetUserIds });
      return;
    }

    const message = {
      notification: {
        title,
        body,
      },
      data: {
        roomId,
        type,
        eventId: event.params.eventId,
      },
      tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    const invalidTokens = [];
    response.responses.forEach((result, index) => {
      if (!result.success) {
        const code = result.error && result.error.code ? result.error.code : "unknown";
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        ) {
          invalidTokens.push(tokens[index]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      await Promise.all(
        targetUserIds.map(async (uid) => {
          await admin.firestore().collection("users").doc(uid).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
          });
        })
      );
    }

    logger.info("Room event notifications dispatched", {
      roomId,
      type,
      targets: targetUserIds.length,
      tokens: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  }
);
