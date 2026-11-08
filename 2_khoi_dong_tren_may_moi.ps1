# ==============================================================================
# BƯỚC 2: CHẠY TRÊN MÁY MỚI ĐỂ KHỞI TẠO DOCKER, NẠP DATABASE & TẠO SSL LAN MỚI
# ==============================================================================
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  KHỞI ĐỘNG HỆ THỐNG PTNL TRÊN MÁY TÍNH MỚI" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Đảm bảo các thư mục cần thiết tồn tại
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\uploads", "$PSScriptRoot\backups", "$PSScriptRoot\ssl", "$PSScriptRoot\apps\web\ssl" | Out-Null

# 2. Tự động lấy IP mạng LAN của máy mới và tạo chứng chỉ SSL HTTPS cho Camera 3x4
$LanIP = $null
try {
    $LanIP = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL|Docker' -and $_.IPAddress -notmatch '^169\.254' } | Select-Object -First 1).IPAddress
} catch {
    $ipMatch = (ipconfig | Select-String "IPv4.*:\s*(\d+\.\d+\.\d+\.\d+)" | Where-Object { $_.Matches[0].Groups[1].Value -notmatch '^127\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^169\.254' } | Select-Object -First 1)
    if ($ipMatch) { $LanIP = $ipMatch.Matches[0].Groups[1].Value }
}
if (-not $LanIP) { $LanIP = "192.168.1.75" }
Write-Host "1. Phát hiện địa chỉ IP LAN của máy mới: $LanIP" -ForegroundColor Yellow

Write-Host "   Đang tạo chứng chỉ SSL HTTPS cho IP $LanIP (phục vụ chụp ảnh Camera 3x4)..." -ForegroundColor Cyan
docker run --rm -v "$PSScriptRoot\ssl:/ssl" nginx:alpine sh -c "apk add --no-cache openssl >/dev/null 2>&1 && openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /ssl/privkey.pem -out /ssl/fullchain.pem -subj '/C=VN/ST=HaiPhong/L=HaiPhong/O=PTNL-MIC1/CN=$LanIP' -addext 'subjectAltName=DNS:localhost,DNS:ptnl.mic1.edu.vn,IP:$LanIP,IP:127.0.0.1' >/dev/null 2>&1"
Copy-Item -Recurse -Force "$PSScriptRoot\ssl\*" "$PSScriptRoot\apps\web\ssl\" -ErrorAction SilentlyContinue

# 3. Khởi động Database trước và đợi sẵn sàng
Write-Host "2. Đang khởi động PostgreSQL (edumaster_db)..." -ForegroundColor Cyan
docker compose up -d postgres
Start-Sleep -Seconds 8

# 4. Tìm file sao lưu dữ liệu (ưu tiên edumaster_db_backup.sql, nếu không có thì lấy bản mới nhất trong thư mục backups)
$BackupFile = Join-Path $PSScriptRoot "edumaster_db_backup.sql"
if (-not (Test-Path $BackupFile)) {
    $LatestAutoBackup = Get-ChildItem -Path "$PSScriptRoot\backups\*.sql" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($LatestAutoBackup) {
        $BackupFile = $LatestAutoBackup.FullName
    }
}

if (Test-Path $BackupFile) {
    Write-Host "3. Đang khôi phục dữ liệu từ file: $BackupFile ..." -ForegroundColor Cyan
    docker cp "$BackupFile" edumaster_db:/tmp/restore.sql
    docker exec edumaster_db psql -U postgres -d edumaster -f /tmp/restore.sql
    docker exec edumaster_db rm -f /tmp/restore.sql
    Write-Host "✅ Đã nạp xong toàn bộ dữ liệu học viên, lớp học, quyết định, điểm thi!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Không tìm thấy file sao lưu SQL, hệ thống sẽ khởi tạo cơ sở dữ liệu trống." -ForegroundColor Yellow
}

# 5. Đóng gói và khởi động toàn bộ 4 dịch vụ (postgres + strapi + web + backup)
Write-Host "4. Đang đóng gói và khởi động toàn bộ hệ thống (Database, Backend, Web, Auto-Backup)..." -ForegroundColor Cyan
docker compose up -d --build
docker exec edumaster_strapi apk add --no-cache postgresql-client >/dev/null 2>&1

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "🎉 HOÀN TẤT! Phần mềm PTNL đã chạy thành công trên máy mới:" -ForegroundColor Green
Write-Host "   - Mở trực tiếp trên máy này : https://localhost  (hoặc http://localhost)" -ForegroundColor White
Write-Host "   - Mở từ máy khác trong LAN : https://$LanIP     (hoặc http://$LanIP)" -ForegroundColor White
Write-Host "   - Thư mục ảnh học viên     : $PSScriptRoot\uploads" -ForegroundColor White
Write-Host "   - Thư mục tự động sao lưu  : $PSScriptRoot\backups" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
