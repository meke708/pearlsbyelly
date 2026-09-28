require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 5000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/pearlsbyelly';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin';


app.use(cors());
app.use(express.json());

// --- MONGOOSE SCHEMAS & MODELS ---
const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  phone: { type: String, required: true },
  password: { type: String, required: true },
  address: { type: String, default: 'Opuwo, Namibia' },
  role: { type: String, default: 'customer' }, // 'customer' or 'admin'
  createdAt: { type: Date, default: Date.now }
});

const productSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  name: { type: String, required: true },
  category: { type: String, default: 'ACCESSORIES' },
  price: { type: Number, required: true },
  tag: { type: String, default: 'NEW' },
  rating: { type: Number, default: 5.0 },
  reviewCount: { type: Number, default: 1 },
  imageUrl: { type: String, default: '' },
  description: { type: String, default: '' },
  details: { type: [String], default: [] },
  createdAt: { type: Date, default: Date.now }
});

const orderSchema = new mongoose.Schema({
  orderCode: { type: String, required: true, unique: true },
  userId: { type: String, default: 'guest' },
  customerName: { type: String, required: true },
  customerEmail: { type: String, required: true },
  customerPhone: { type: String, required: true },
  items: { type: Array, required: true },
  customText: { type: String, default: '' },
  giftNote: { type: String, default: '' },
  courierMethod: { type: String, default: 'Nationwide Courier (Namibia)' },
  totalAmount: { type: Number, required: true },
  status: { type: String, default: 'Order Received & Confirmed' },
  dateCreated: { type: Date, default: Date.now }
});

const settingsSchema = new mongoose.Schema({
  key: { type: String, required: true, unique: true },
  value: { type: mongoose.Schema.Types.Mixed, required: true }
});

const User = mongoose.model('User', userSchema);
const Product = mongoose.model('Product', productSchema);
const Order = mongoose.model('Order', orderSchema);
const Settings = mongoose.model('Settings', settingsSchema);

// --- DYNAMIC SEEDING FROM SEEDDATA.JSON ---
const seedInitialData = async () => {
  try {
    const seedFilePath = path.join(__dirname, 'seedData.json');
    if (!fs.existsSync(seedFilePath)) return;

    const seedRaw = fs.readFileSync(seedFilePath, 'utf8');
    const seedData = JSON.parse(seedRaw);

    // Users Seed
    const userCount = await User.countDocuments();
    if (userCount === 0 && seedData.users && Array.isArray(seedData.users)) {
      console.log('🌱 Seeding user accounts to MongoDB...');
      await User.insertMany(seedData.users);
      console.log('✅ User accounts initialized!');
    }

    // Products Seed
    const productCount = await Product.countDocuments();
    if (productCount === 0 && seedData.products && Array.isArray(seedData.products)) {
      console.log('🌱 Seeding initial products to MongoDB...');
      await Product.insertMany(seedData.products);
      console.log('✅ Products collection initialized!');
    }

    // Orders Seed
    const orderCount = await Order.countDocuments();
    if (orderCount === 0 && seedData.orders && Array.isArray(seedData.orders)) {
      console.log('🌱 Seeding sample orders to MongoDB...');
      await Order.insertMany(seedData.orders);
      console.log('✅ Orders collection initialized!');
    }

    // Settings Seed
    const settingsCount = await Settings.countDocuments();
    if (settingsCount === 0 && seedData.settings) {
      console.log('🌱 Seeding initial store settings to MongoDB...');
      const settingsDocs = Object.keys(seedData.settings).map(k => ({ key: k, value: seedData.settings[k] }));
      await Settings.insertMany(settingsDocs);
      console.log('✅ Store settings initialized!');
    }
  } catch (err) {
    console.error('Error seeding data:', err.message);
  }
};

// --- CONNECT TO MONGO DB ---
mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log(`🍃 Connected to MongoDB at ${MONGODB_URI}`);
    seedInitialData();
  })
  .catch((err) => {
    console.warn(`⚠️ MongoDB connection error: ${err.message}. Operating in standalone mode.`);
  });

// --- USER AUTHENTICATION & ACCOUNT ENDPOINTS ---
app.post('/api/users/register', async (req, res) => {
  try {
    const { name, email, phone, password, address } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required' });
    }
    const existing = await User.findOne({ email: email.trim().toLowerCase() });
    if (existing) {
      return res.status(400).json({ error: 'An account with this email already exists' });
    }
    const newUser = new User({
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone ? phone.trim() : 'N/A',
      password: password.trim(),
      address: address ? address.trim() : 'Opuwo, Namibia',
      role: 'customer'
    });
    await newUser.save();
    res.status(201).json({
      success: true,
      user: {
        id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        phone: newUser.phone,
        address: newUser.address,
        role: newUser.role
      }
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/users/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }
    const user = await User.findOne({ email: email.trim().toLowerCase(), password: password.trim() });
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        address: user.address,
        role: user.role
      }
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Admin list all customer accounts
app.get('/api/users', async (req, res) => {
  try {
    const users = await User.find({ role: 'customer' }).select('-password').sort({ createdAt: -1 });
    res.json(users);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get orders by user account email
app.get('/api/orders/user/:email', async (req, res) => {
  try {
    const { email } = req.params;
    const userOrders = await Order.find({ customerEmail: email.trim().toLowerCase() }).sort({ dateCreated: -1 });
    res.json(userOrders);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// --- ADMIN AUTHENTICATION ---
app.post('/api/admin/login', (req, res) => {
  const { password } = req.body;
  if (password === ADMIN_PASSWORD) {
    return res.json({ success: true, token: 'pbe-admin-token-authenticated', message: 'Admin authentication successful' });
  }
  return res.status(401).json({ success: false, message: 'Invalid Admin Password' });
});

// --- STORE SETTINGS API ---
app.get('/api/settings', async (req, res) => {
  try {
    const settingsList = await Settings.find();
    const settingsObj = {};
    settingsList.forEach(s => settingsObj[s.key] = s.value);
    res.json(settingsObj);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/api/settings', async (req, res) => {
  try {
    const updates = req.body;
    for (const key of Object.keys(updates)) {
      await Settings.findOneAndUpdate({ key }, { value: updates[key] }, { upsert: true });
    }
    res.json({ success: true, message: 'Settings updated successfully' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// --- DASHBOARD STATS ---
app.get('/api/stats', async (req, res) => {
  try {
    const orders = await Order.find();
    const activeProducts = await Product.countDocuments();
    const totalUsers = await User.countDocuments({ role: 'customer' });
    const totalRevenue = orders.reduce((sum, o) => sum + (o.totalAmount || 0), 0);
    const totalOrders = orders.length;
    const pendingOrders = orders.filter(o => o.status !== 'Delivered').length;

    res.json({
      totalRevenue,
      totalOrders,
      activeProducts,
      totalUsers,
      pendingOrders
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// --- PRODUCTS REST API ---
app.get('/api/products', async (req, res) => {
  try {
    const products = await Product.find().sort({ createdAt: -1 });
    res.json(products);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/products', async (req, res) => {
  try {
    const { name, category, price, imageUrl, description, details, tag } = req.body;
    if (!name || price === undefined) {
      return res.status(400).json({ error: 'Name and price are required' });
    }
    const newProduct = new Product({
      id: (await Product.countDocuments() + 1).toString() + '_' + Date.now(),
      name,
      category: category || 'ACCESSORIES',
      price: parseFloat(price),
      imageUrl: imageUrl || '',
      description: description || '',
      details: Array.isArray(details) ? details : [],
      tag: tag || 'NEW',
      rating: 5.0,
      reviewCount: 1
    });
    await newProduct.save();
    res.status(201).json(newProduct);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/api/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await Product.findOneAndUpdate({ id }, req.body, { new: true });
    if (!updated) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json(updated);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/api/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await Product.findOneAndDelete({ id });
    res.json({ success: true, message: 'Product deleted from MongoDB' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// --- ORDERS REST API ---
app.get('/api/orders', async (req, res) => {
  try {
    const orders = await Order.find().sort({ dateCreated: -1 });
    res.json(orders);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/orders/track', async (req, res) => {
  try {
    const { code } = req.query;
    if (!code) return res.status(400).json({ error: 'Order code, email or phone required' });
    const searchStr = code.trim();
    const found = await Order.find({
      $or: [
        { orderCode: { $regex: searchStr, $options: 'i' } },
        { customerPhone: { $regex: searchStr, $options: 'i' } },
        { customerEmail: { $regex: searchStr, $options: 'i' } }
      ]
    });
    res.json(found);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/orders', async (req, res) => {
  try {
    const { userId, customerName, customerEmail, customerPhone, items, customText, courierMethod, totalAmount, giftNote } = req.body;
    const orderCode = 'PBE-' + Math.floor(1000 + Math.random() * 9000);
    const newOrder = new Order({
      orderCode,
      userId: userId || 'guest',
      customerName: customerName || 'Valued Customer',
      customerEmail: customerEmail ? customerEmail.trim().toLowerCase() : 'guest@pearlsbyelly.com',
      customerPhone: customerPhone || 'N/A',
      items: items || [],
      customText: customText || '',
      giftNote: giftNote || '',
      courierMethod: courierMethod || 'Nationwide Courier (Namibia)',
      totalAmount: parseFloat(totalAmount) || 0.0,
      status: 'Order Received & Confirmed'
    });
    await newOrder.save();
    res.status(201).json(newOrder);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put('/api/orders/:code/status', async (req, res) => {
  try {
    const { code } = req.params;
    const { status } = req.body;
    const order = await Order.findOneAndUpdate({ orderCode: code }, { status }, { new: true });
    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }
    res.json(order);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Root Healthcheck
app.get('/', (req, res) => {
  res.send('Pearls By Elly User & Orders API is running smoothly! 🍃💎');
});

app.listen(PORT, () => {
  console.log(`Pearls By Elly API listening at http://localhost:${PORT}`);
});
