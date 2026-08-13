const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");

// Import Database Connection
const db = require("./config/db");

const app = express();

// Middleware
app.use(cors());
app.use(helmet());
app.use(morgan("dev"));
app.use(express.json());

// Default Route
app.get("/", (req, res) => {
    res.json({
        message: "Zepto Quick Commerce API Running"
    });
});

// Health Check Route
app.get("/health", async (req, res) => {
    try {
        const [rows] = await db.query("SELECT NOW() AS currentTime");

        res.status(200).json({
            status: "SUCCESS",
            message: "Database Connected Successfully",
            database: "Connected",
            serverTime: rows[0].currentTime
        });
    } catch (error) {
        res.status(500).json({
            status: "FAILED",
            message: "Database Connection Failed",
            error: error.message
        });
    }
});

// Health Check Products API
app.get("/products", async (req, res) => {

    const [rows] = await db.query(

        "SELECT * FROM products"

    );

    res.json(rows);

});
module.exports = app;