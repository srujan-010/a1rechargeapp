const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Local disk storage for KYC document uploads.
// In production this should be replaced with signed uploads to object storage
// (S3 / GCS) — the route handlers only persist the resulting URL.
const UPLOAD_DIR = path.join(__dirname, '..', 'uploads', 'kyc');

if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const userId = req.user?._id?.toString() ?? 'anon';
    const ext = path.extname(file.originalname) || '.jpg';
    const unique = `${userId}_${Date.now()}${ext}`;
    cb(null, unique);
  },
});

const fileFilter = (req, file, cb) => {
  const allowed = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
  if (allowed.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Unsupported file type. Allowed: JPG, PNG, WEBP, PDF.'), false);
  }
};

const uploadKyc = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
});

module.exports = { uploadKyc, UPLOAD_DIR };
