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
app.use('/api/user', require('./routes/userRoutes'));
app.use('/api/wallet', require('./routes/walletRoutes'));
app.use('/api/services', require('./routes/serviceRoutes'));
app.use('/api/bank', require('./routes/bankRoutes'));
app.use('/api/kyc', require('./routes/kycRoutes'));
app.use('/api/notifications', require('./routes/notificationRoutes'));
app.use('/api/commission', require('./routes/commissionRoutes'));

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
app.use(errorHandler);

const PORT = process.env.PORT || 5000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running in ${process.env.NODE_ENV} mode on port ${PORT}`);
  
  // Print registered routes
  console.log('Registered Routes:');
  console.log('POST /api/auth/send-otp');
  console.log('GET /api/auth/send-otp');
  console.log('GET /api/health');
});
