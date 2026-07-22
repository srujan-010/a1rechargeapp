const express = require('express');
const path = require('path');
const dotenv = require('dotenv');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const connectDB = require('./config/db');
const { errorHandler } = require('./middleware/errorHandler');

const { initFirebaseAdmin } = require('./config/firebase');

// Load env vars
dotenv.config();

// Init Firebase Admin SDK
initFirebaseAdmin();

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

app.use(cors({
  origin: (origin, callback) => {
    // Allow any origin in dev or if explicitly allowed
    if (process.env.NODE_ENV !== 'production') return callback(null, true);
    if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
    
    // Allow flutter web local development even when backend is in production
    if (/^http:\/\/localhost:\d+$/.test(origin)) return callback(null, true);
    
    return callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-App-Platform', 'X-App-Version', 'Accept'],
}));
app.use(express.json());
// app.use(helmet());
app.use(morgan('dev'));

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/msg91', require('./routes/msg91Routes'));
app.use('/api/user', require('./routes/userRoutes'));
app.use('/api/wallet', require('./routes/walletRoutes'));
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
