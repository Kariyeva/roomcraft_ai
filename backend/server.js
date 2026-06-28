const express = require("express");
const cors = require("cors");
const multer = require("multer");
const dotenv = require("dotenv");
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
const Replicate = require("replicate");

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

if (!serviceAccountPath) {
  throw new Error("FIREBASE_SERVICE_ACCOUNT_PATH is missing in .env");
}

const serviceAccount = require(path.resolve(__dirname, serviceAccountPath));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const replicate = new Replicate({
  auth: process.env.REPLICATE_API_TOKEN,
});

app.use(cors());
app.use(express.json());
app.use("/generated", express.static(path.join(__dirname, "generated")));

const upload = multer({
  dest: "uploads/",
});

const generatedDir = path.join(__dirname, "generated");

if (!fs.existsSync(generatedDir)) {
  fs.mkdirSync(generatedDir);
}

function fileToDataUri(filePath, mimeType) {
  const buffer = fs.readFileSync(filePath);
  const base64 = buffer.toString("base64");
  return `data:${mimeType || "image/png"};base64,${base64}`;
}

async function outputToBuffer(output) {
  if (output && typeof output.arrayBuffer === "function") {
    const arrayBuffer = await output.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  if (output && typeof output.url === "function") {
    const imageResponse = await fetch(output.url());
    const arrayBuffer = await imageResponse.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  if (Array.isArray(output) && output.length > 0) {
    const first = output[0];

    if (first && typeof first.arrayBuffer === "function") {
      const arrayBuffer = await first.arrayBuffer();
      return Buffer.from(arrayBuffer);
    }

    if (first && typeof first.url === "function") {
      const imageResponse = await fetch(first.url());
      const arrayBuffer = await imageResponse.arrayBuffer();
      return Buffer.from(arrayBuffer);
    }

    if (typeof first === "string") {
      const imageResponse = await fetch(first);
      const arrayBuffer = await imageResponse.arrayBuffer();
      return Buffer.from(arrayBuffer);
    }
  }

  if (typeof output === "string") {
    const imageResponse = await fetch(output);
    const arrayBuffer = await imageResponse.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  if (output?.url && typeof output.url === "string") {
    const imageResponse = await fetch(output.url);
    const arrayBuffer = await imageResponse.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  if (output?.image) {
    const imageResponse = await fetch(output.image);
    const arrayBuffer = await imageResponse.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  throw new Error("Unsupported Replicate output format");
}

app.get("/", (req, res) => {
  res.json({ message: "RoomCraft AI backend running with Replicate" });
});

function buildStrictPrompt(userPrompt, style) {
  const cleanPrompt = userPrompt.trim();

  const fallbackPrompt =
    "Make conservative interior edits while preserving the original room exactly.";

  const styleInstruction =
    style && style.trim() && style !== "interior design"
      ? `Apply ONLY the visual aesthetic of "${style}" to the requested object(s) only.`
      : "";

  return `
IMAGE EDITING TASK.

This is NOT a redesign.
This is NOT a redecoration.
This is NOT a room transformation.
This is NOT a creative reinterpretation.

You MUST preserve the uploaded room photo exactly.

USER REQUEST:
${cleanPrompt || fallbackPrompt}

STYLE:
${styleInstruction}

CRITICAL RULES:

1. ONLY modify the exact object(s) explicitly requested by the user.

2. EVERYTHING ELSE MUST REMAIN IDENTICAL:
- same walls
- same wall color
- same floor
- same carpet
- same lighting
- same shadows
- same brightness
- same exposure
- same curtains
- same window
- same decorations
- same shelves
- same table
- same plants
- same room layout
- same composition
- same camera angle
- same perspective
- same proportions
- same architecture

3. DO NOT beautify the room.
4. DO NOT improve the room unless explicitly requested.
5. DO NOT redesign the room.
6. DO NOT add extra furniture unless explicitly requested.
7. DO NOT remove objects unless explicitly requested.
8. DO NOT change room mood.
9. DO NOT change colors of unrelated objects.
10. Preserve photorealism.
11. Apply the SMALLEST precise edit necessary.

INTERPRETATION EXAMPLES:

If user says:
"make sofa red"
→ ONLY change sofa color to red

If user says:
"make sofa smaller"
→ ONLY reduce sofa size

If user says:
"replace sofa"
→ ONLY replace sofa

If user says:
"add plant"
→ ONLY add plant

If user says:
"change wall color"
→ ONLY change wall color

STRICTLY FOLLOW USER REQUEST ONLY.

FINAL COMMAND:
Generate a photorealistic edited version of the EXACT uploaded room photo with ONLY the requested modifications.
`;
}

app.post("/generate-room", upload.single("image"), async (req, res) => {
  console.log("Запрос пришел");
  console.log("body:", req.body);

  try {
    const imageFile = req.file;
    const prompt = req.body.prompt || "";
    const style = req.body.style || "";
    const userId = req.body.userId;

    if (!userId) {
      return res.status(401).json({
        error: "User not authenticated",
      });
    }

    if (!imageFile) {
      return res.status(400).json({
        error: "Image is required",
      });
    }

    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();

    let currentCount = 0;

    if (!userDoc.exists) {
      await userRef.set({
        aiGenerations: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      currentCount = userDoc.data().aiGenerations || 0;
    }

    const inputImage = fileToDataUri(imageFile.path, imageFile.mimetype);
    const finalPrompt = buildStrictPrompt(prompt, style);

    console.log("Sending request to FLUX Kontext Pro...");

    const output = await replicate.run("black-forest-labs/flux-kontext-pro", {
      input: {
        prompt: finalPrompt,
        input_image: inputImage,
        output_format: "png",
        aspect_ratio: "match_input_image",
        prompt_strength: 0.35,
        guidance_scale: 12,
      },
    });

    const outputBuffer = await outputToBuffer(output);

    const fileName = `room_${Date.now()}.png`;
    const outputPath = path.join(generatedDir, fileName);

    fs.writeFileSync(outputPath, outputBuffer);

    fs.unlinkSync(imageFile.path);

    await userRef.update({
      aiGenerations: currentCount + 1,
    });

    res.json({
      imageUrl: `http://${req.get("host")}/generated/${fileName}`,
      fileName,
    });
  } catch (error) {
    console.error("AI generation error:", error);

    if (req.file?.path && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }

    res.status(500).json({
      error: "Generation failed",
      details: error.message,
    });
  }
});

app.post("/remove-background", upload.single("image"), async (req, res) => {
  try {
    const imageFile = req.file;

    if (!imageFile) {
      return res.status(400).json({
        error: "Image is required",
      });
    }

    const inputImage = fileToDataUri(imageFile.path, imageFile.mimetype);

    console.log("Sending request to background remover WITH VERSION...");

    const output = await replicate.run(
      "851-labs/background-remover:a029dff38972b5fda4ec5d75d7d1cd25aeff621d2cf4946a41055d7db66b80bc",
      {
        input: {
          image: inputImage,
        },
      }
    );

    const outputBuffer = await outputToBuffer(output);

    const fileName = `item_${Date.now()}.png`;
    const outputPath = path.join(generatedDir, fileName);

    fs.writeFileSync(outputPath, outputBuffer);

    fs.unlinkSync(imageFile.path);

    res.json({
      imageUrl: `http://${req.get("host")}/generated/${fileName}`,
      imageBase64: outputBuffer.toString("base64"),
      fileName,
    });
  } catch (error) {
    console.error("Background removal error:", error);

    if (req.file?.path && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }

    res.status(500).json({
      error: "Background removal failed",
      details: error.message,
    });
  }
});

app.listen(port, () => {
  console.log(`RoomCraft AI backend running on port ${port}`);
});
