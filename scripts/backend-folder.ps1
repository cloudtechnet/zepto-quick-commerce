# ============================================
# Backend Folder Structure Creator
# Creates missing folders and files only
# ============================================

Write-Host "Creating backend project structure..." -ForegroundColor Cyan

# Root path (current directory)
$Root = Get-Location

# Folder list
$Folders = @(
    "config",
    "controllers",
    "middleware",
    "models",
    "routes",
    "utils"
)

# File list
$Files = @(
    "config\db.js",
    "config\jwt.js",

    "controllers\authController.js",
    "controllers\productController.js",
    "controllers\cartController.js",
    "controllers\orderController.js",
    "controllers\userController.js",

    "middleware\authMiddleware.js",
    "middleware\errorMiddleware.js",
    "middleware\validateMiddleware.js",

    "models\User.js",
    "models\Product.js",
    "models\Cart.js",
    "models\Order.js",

    "routes\authRoutes.js",
    "routes\productRoutes.js",
    "routes\cartRoutes.js",
    "routes\orderRoutes.js",
    "routes\userRoutes.js",

    "utils\response.js",
    "utils\logger.js",

    "app.js",
    "server.js",
    "package.json",
    ".env.example",
    "Dockerfile",
    ".gitignore"
)

# -----------------------------
# Create Folders
# -----------------------------
foreach ($folder in $Folders) {

    $folderPath = Join-Path $Root $folder

    if (-not (Test-Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath | Out-Null
        Write-Host "[CREATED] Folder : $folder" -ForegroundColor Green
    }
    else {
        Write-Host "[SKIPPED] Folder : $folder already exists" -ForegroundColor Yellow
    }
}

# -----------------------------
# Create Files
# -----------------------------
foreach ($file in $Files) {

    $filePath = Join-Path $Root $file

    if (-not (Test-Path $filePath)) {

        $parent = Split-Path $filePath -Parent

        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        New-Item -ItemType File -Path $filePath | Out-Null
        Write-Host "[CREATED] File   : $file" -ForegroundColor Green
    }
    else {
        Write-Host "[SKIPPED] File   : $file already exists" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Backend structure is up to date." -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan