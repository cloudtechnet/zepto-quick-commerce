require("dotenv").config();

const app = require("./app");
const db = require("./config/db");

const PORT = process.env.PORT || 5000;

async function startServer() {
    try {

        const connection = await db.getConnection();

        console.log("✅ MySQL Connected Successfully");

        connection.release();

        app.listen(PORT, () => {
            console.log(`Server Running on Port ${PORT}`);
        });

    } catch (error) {

        console.error("❌ Database Connection Failed");

        console.error(error.message);

    }
}

startServer();