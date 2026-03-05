const functions = require("firebase-functions");
const cloudinary = require("cloudinary").v2;

// Ye function secure tarike se image delete karega
exports.deleteCloudinaryImage = functions.runWith({
  secrets: ["CLOUDINARY_API_KEY", "CLOUDINARY_API_SECRET"]
}).https.onRequest(async (req, res) => {
  // Sirf POST request allow karen
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }

  const { publicId } = req.body;

  if (!publicId) {
    return res.status(400).send("No publicId provided");
  }

  // Cloudinary configure karen (Secrets server se automatic mil jayenge)
  cloudinary.config({
    cloud_name: "dgrfxp8mr",
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
    secure: true,
  });

  try {
    const result = await cloudinary.uploader.destroy(publicId);
    console.log("Deleted image:", publicId, result);
    return res.status(200).json(result);
  } catch (error) {
    console.error("Cloudinary Delete Error:", error);
    return res.status(500).json({ error: error.message });
  }
});
