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

  throw new Error("Unsupported Replicate output format");
}

app.get("/", (req, res) => {
  res.json({ message: "RoomCraft AI backend running with Replicate" });
});

function buildStrictPrompt(userPrompt, style) {
  const cleanPrompt = userPrompt.trim();

  const fallbackPrompt =
    "Improve the room interior conservatively while preserving the original layout and structure.";

  const styleInstruction =
    style && style.trim() && style !== "interior design"
      ? `Apply ONLY the visual aesthetic of "${style}" without changing room structure or unrelated objects.`
      : "";

  return `
You are a precision interior image editing AI.

THIS IS AN IMAGE EDIT TASK.
NOT a full redesign.
NOT a creative reinterpretation.

PRIMARY USER REQUEST:
${cleanPrompt || fallbackPrompt}

STYLE:
${styleInstruction}

STRICT RULES:
1. Edit ONLY what the user explicitly requested.
2. Preserve the original room layout exactly.
3. Preserve camera angle exactly.
4. Preserve perspective exactly.
5. Preserve room proportions exactly.
6. Preserve wall positions.
7. Preserve windows unless explicitly requested.
8. Preserve curtains unless explicitly requested.
9. Preserve flooring unless explicitly requested.
10. Preserve rugs unless explicitly requested.
11. Preserve tables unless explicitly requested.
12. Preserve shelves unless explicitly requested.
13. Preserve lighting unless explicitly requested.
14. Preserve ceiling unless explicitly requested.
15. Preserve architectural structure.
16. Do NOT add extra objects.
17. Do NOT remove unrelated objects.
18. Do NOT invent decorative changes.
19. Do NOT redesign the entire room.
20. Apply the SMALLEST precise edit necessary.

INTERPRETATION RULES:
- "make lighter" = lighting/color tone only
- "modern" = modern styling only
- "replace sofa" = replace sofa only
- "add plant" = add plant only
- "change wall color" = only wall color
- "new table" = replace only table

FINAL COMMAND:
Generate a photorealistic edited version of the exact uploaded room photo with only the requested modifications.
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

    const inputImage = fileToDataUri(
      imageFile.path,
      imageFile.mimetype
    );

    const finalPrompt = buildStrictPrompt(prompt, style);

    console.log("Sending request to FLUX Kontext Pro...");

    const output = await replicate.run(
      "black-forest-labs/flux-kontext-pro",
      {
        input: {
          prompt: finalPrompt,
          input_image: inputImage,
          output_format: "png",
          aspect_ratio: "match_input_image",
        },
      }
    );

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

    if (req.file?.path && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }

    res.status(500).json({
      error: "Generation failed",
      details: error.message,
    });
  }
});

app.listen(port, () => {
  console.log(`RoomCraft AI backend running on port ${port}`);
});