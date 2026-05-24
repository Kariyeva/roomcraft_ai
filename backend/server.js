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

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

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

app.post("/generate-room", upload.single("image"), async (req, res) => {
  console.log("Запрос пришел");
  console.log("body:", req.body);
  console.log("file:", req.file ? req.file.path : "no file");

  try {
    const imageFile = req.file;
    const prompt = req.body.prompt || "";
    const style = req.body.style || "interior design";
    const userId = req.body.userId;

    if (!userId) {
      return res.status(401).json({ error: "User not authenticated" });
    }

    if (!imageFile) {
      return res.status(400).json({ error: "Image is required" });
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
      const userData = userDoc.data();
      currentCount = userData.aiGenerations || 0;
    }

    const inputImage = fileToDataUri(imageFile.path, imageFile.mimetype);

    const userPrompt = prompt.trim().isEmpty
      ? "Redesign the room with visible modern interior improvements"
      : prompt.trim();

    const finalPrompt = `
THIS IS AN IMAGE EDIT TASK, NOT A REDESIGN TASK.

Edit the uploaded room photo.

User request:
${prompt}

Style:
${style}

STRICT INSTRUCTIONS:
- Modify ONLY the exact objects mentioned in the user request.
- DO NOT redesign the whole room.
- DO NOT change walls.
- DO NOT change wall color.
- DO NOT change floor.
- DO NOT change rug.
- DO NOT change table.
- DO NOT change shelves.
- DO NOT change lighting.
- DO NOT change window.
- DO NOT change curtains.
- DO NOT change room size.
- DO NOT change camera angle.
- DO NOT change perspective.
- Keep the original photo composition exactly.
- Preserve realism.
- Only apply minimal targeted edits.

If the user asks to replace sofa, ONLY replace sofa.
If the user asks to add plant, ONLY add plant.
`;

    console.log("Отправляем запрос в Replicate FLUX Kontext Pro...");

    const output = await replicate.run("black-forest-labs/flux-kontext-pro", {
      input: {
        prompt: finalPrompt,
        input_image: inputImage,
        output_format: "png",
        aspect_ratio: "match_input_image",
      },
    });

    console.log("Replicate output received");

    const outputBuffer = await outputToBuffer(output);

    const fileName = `room_${Date.now()}.png`;
    const outputPath = path.join(generatedDir, fileName);

    fs.writeFileSync(outputPath, outputBuffer);

    fs.unlinkSync(imageFile.path);

    await userRef.update({
      aiGenerations: currentCount + 1,
    });

    res.json({
      imageUrl: `https://${req.get("host")}/generated/${fileName}`,
      fileName,
    });
  } catch (error) {
    console.error("AI generation error:", error);

    if (req.file && req.file.path && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }

    res.status(500).json({
      error: "Generation failed",
      details: error.message,
    });
  }
});

app.listen(port, () => {
  console.log(`RoomCraft AI backend running on http://localhost:${port}`);
});