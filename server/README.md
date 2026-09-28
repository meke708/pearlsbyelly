# Pearls By Elly — MongoDB API Server 🍃💎

Node.js Express REST API backed by **MongoDB** (via Mongoose) powering the Pearls By Elly storefront and Executive Admin Console.

## Features & Endpoints
- **MongoDB Connection**: Connects to local MongoDB (`mongodb://127.0.0.1:27017/pearlsbyelly`) or cloud MongoDB Atlas via `MONGODB_URI` environment variable.
- **Auto-Seeding**: Seeds initial flyer catalog items and sample orders into MongoDB collections automatically on first startup.
- **Products API**:
  - `GET /api/products` — Fetch all products sorted by newest.
  - `POST /api/products` — Create new catalog accessory in MongoDB.
  - `PUT /api/products/:id` — Update existing product.
  - `DELETE /api/products/:id` — Delete product.
- **Orders API**:
  - `GET /api/orders` — List customer orders.
  - `POST /api/orders` — Register new WhatsApp order in MongoDB.
  - `PUT /api/orders/:code/status` — Update order fulfillment step.
  - `GET /api/orders/track?code=...` — Real-time order tracking search.
- **Stats API**:
  - `GET /api/stats` — Executive dashboard revenue, order count, catalog count, and pending fulfillments.

## How to Run

1. Open a terminal in `server/`:
   ```bash
   cd server
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

## Environment Variables (.env)
Create a `.env` file inside `server/` with the following variables:
```env
PORT=5000
MONGODB_URI=mongodb+srv://<username>:<password>@cluster0.mongodb.net/pearlsbyelly?retryWrites=true&w=majority
ADMIN_PASSWORD=admin
```

## How to Deploy on Render

1. **Push your code to GitHub** (the `.env` file is safely ignored by `.gitignore`).
2. Log in to [Render.com](https://render.com) and create a **New Web Service**.
3. Connect your GitHub repository.
4. Set the following parameters:
   - **Root Directory**: `server`
   - **Build Command**: `npm install`
   - **Start Command**: `node server.js`
5. Under **Environment Variables**, add:
   - `MONGODB_URI`: `mongodb+srv://<username>:<password>@cluster0.mongodb.net/pearlsbyelly?retryWrites=true&w=majority`
   - `ADMIN_PASSWORD`: `admin` (or your preferred admin password)
6. Click **Deploy Web Service**. Render will automatically detect the port and deploy your server.
