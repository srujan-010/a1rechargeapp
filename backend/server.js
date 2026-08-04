const express = require('express');
const path = require('path');
const dotenv = require('dotenv');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const connectDB = require('./config/db');
const { errorHandler } = require('./middleware/errorHandler');

const { initFirebaseAdmin, getApp } = require('./config/firebase');

// Load env vars
dotenv.config();

// Init Firebase Admin SDK
initFirebaseAdmin();
const firebaseApp = getApp();
if (firebaseApp) {
  const projectId = firebaseApp.options.projectId || 
    (firebaseApp.options.credential && firebaseApp.options.credential.projectId) || 
    'unknown';
  console.log(`Project ID: ${projectId}`);
  console.log('Notification service ready');
}

// Connect to database
connectDB();

// --- STARTUP PROTECTION ---
const fs = require('fs');
const serviceControllerCode = fs.readFileSync(path.join(__dirname, 'controllers/serviceController.js'), 'utf-8');
if (
  serviceControllerCode.includes('setTimeout') || 
  serviceControllerCode.includes('OP${Math.random') || 
  serviceControllerCode.includes('TXN${Math.random')
) {
  console.error('CRITICAL STARTUP ERROR: Mock recharge code detected in serviceController.js. Startup aborted.');
  process.exit(1);
}
// --- END STARTUP PROTECTION ---

const app = express();

const allowedOrigins = [
  'https://a1recharge.com',
  'https://staging.a1recharge.com',
];

app.use((req, res, next) => {
  const origin = req.headers.origin;
  const isAllowed = !origin ||
    process.env.NODE_ENV !== 'production' ||
    allowedOrigins.includes(origin) ||
    /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);

  if (isAllowed && origin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Credentials', 'true');
  } else if (!origin) {
    res.setHeader('Access-Control-Allow-Origin', '*');
  }

  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH');
  const reqHeaders = req.headers['access-control-request-headers'];
  res.setHeader('Access-Control-Allow-Headers', reqHeaders || '*');

  if (req.method === 'OPTIONS') {
    return res.sendStatus(204);
  }
  next();
});
app.use(express.json());
// app.use(helmet());
app.use(morgan('dev'));

// Response Time & Performance Auditing Middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (duration > 200) {
      console.log(`[PERF WARNING] ${req.method} ${req.originalUrl} took ${duration}ms`);
    }
  });
  next();
});

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/user', require('./routes/userRoutes'));
app.use('/api/wallet', require('./routes/walletRoutes'));
app.use('/api/wallet-mpin', require('./routes/walletMpinRoutes'));
app.use('/api/services', require('./routes/serviceRoutes'));
app.use('/api/provider/a1topup', require('./routes/recharge.routes'));
app.use('/api/bank', require('./routes/bankRoutes'));
app.use('/api/kyc', require('./routes/kycRoutes'));
app.use('/api/notifications', require('./routes/notificationRoutes'));
app.use('/api/master', require('./routes/masterData.routes'));
app.use('/api/commission', require('./routes/commissionRoutes'));
app.use('/api/dth', require('./routes/dth.routes'));
app.use('/api/plans', require('./routes/planapi.routes'));
app.use('/api/electricity', require('./routes/electricity.routes'));
app.use('/api/gas', require('./routes/gas'));
app.use('/api/fastag', require('./routes/fastag'));

// Serve uploaded KYC documents statically (protected by token in production
// via a signed-URL proxy; acceptable for local dev).
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Health endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', server: 'running' });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ message: 'A1 Recharge API is running' });
});

// Error handling middleware (must be after routes)
// Catch 404 and forward to error handler (return JSON for APIs)
app.use((req, res, next) => {
  res.status(404).json({ success: false, message: `Endpoint not found: ${req.method} ${req.originalUrl}` });
});

app.use(errorHandler);

// Start the background workers
const pendingRechargeWorker = require('./workers/pendingRecharge.worker');
pendingRechargeWorker.start(2 * 60 * 1000); // Check every 2 minutes

const dthStatusWorker = require('./workers/dthStatus.worker');
dthStatusWorker.start(30 * 1000); // Check every 30 seconds

const PORT = process.env.PORT || 5000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running in ${process.env.NODE_ENV} mode on port ${PORT}`);
  
  // Print registered routes
  console.log('Registered Routes:');
  console.log('POST /api/auth/send-otp');
  console.log('GET /api/auth/send-otp');
  console.log('GET /api/health');
});
