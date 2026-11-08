# ==============================================================================
# BƯỚC 1: CHẠY TRÊN MÁY HIỆN TẠI ĐỂ XUẤT DỮ LIỆU DATABASE CHUẨN UTF-8
# ==============================================================================
$ErrorActionPreference = "Stop"
$BackupFile = Join-Path $PSScriptRoot "edumaster_db_backup.sql"

Write-Host "1. Đang xuất toàn bộ dữ liệu PostgreSQL từ container edumaster_db..." -ForegroundColor Cyan
docker exec edumaster_db pg_dump -U postgres -d edumaster --clean --if-exists -f /tmp/edumaster_db_backup.sql
docker cp edumaster_db:/tmp/edumaster_db_backup.sql "$BackupFile"
docker exec edumaster_db rm -f /tmp/edumaster_db_backup.sql

if (Test-Path $BackupFile) {
    $SizeMB = [math]::Round((Get-Item $BackupFile).Length / 1MB, 2)
    Write-Host "✅ Đã xuất thành công file dữ liệu chuẩn UTF-8: $BackupFile ($SizeMB MB)" -ForegroundColor Green
    Write-Host ""
    Write-Host "👉 BƯỚC TIẾP THEO:" -ForegroundColor Yellow
    Write-Host "   Copy toàn bộ thư mục '$PSScriptRoot' sang máy tính mới."
    Write-Host "   (Mẹo: Có thể bỏ qua các thư mục 'node_modules' và '.git' để copy qua USB/LAN cực nhanh)."
} else {
    Write-Host "❌ Lỗi: Không tạo được file backup!" -ForegroundColor Red
}
