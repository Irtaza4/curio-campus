const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.helloWorld = functions.https.onRequest((request, response) => {
    response.send("Hello from Firebase!");
});

exports.onEmergencyRequestCreated = functions.firestore
    .document("emergencyRequests/{requestId}")
    .onCreate(async (snap, context) => {
        const requestData = snap.data();
        const requestId = context.params.requestId;

        console.log(`New emergency request created: ${requestId}`);

        const requiredSkills = requestData.requiredSkills || [];

        if (requiredSkills.length === 0) {
            console.log("No required skills specified");
            return null;
        }

        try {
            const promises = requiredSkills.map(async (skill) => {
                const formattedSkill = skill.toLowerCase()
                    .replace(/\s+/g, "_");
                const topic = `skill_${formattedSkill}`;

                console.log(`Sending notification to topic: ${topic}`);

                const message = {
                    notification: {
                        title: `Emergency Request: ${requestData.title}`,
                        body: `${requestData.requesterName} needs help with ${skill}`,
                    },
                    data: {
                        type: "emergency",
                        requestId: requestId,
                        requesterId: requestData.requesterId,
                        requesterName: requestData.requesterName,
                        skill: skill,
                        channel_id: "emergency_channel",
                        isOwnRequest: "false",
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                    topic: topic,
                };

                return admin.messaging().send(message);
            });

            const responses = await Promise.all(promises);
            console.log(`Successfully sent ${responses.length} emergency notifications`);

            return null;
        } catch (error) {
            console.error("Error sending emergency notifications:", error);
            return null;
        }
    });