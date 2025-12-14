# sync_data.ps1
# stellive_karaoke_app_data(데이터 repo) -> stella_karaoke(앱 프로젝트) assets/data 동기화 스크립트

$ErrorActionPreference = "Stop"

# ✅ 네 환경에 맞춘 기본값
$BaseDir  = "C:\Users\skrtj"
$DataRepo = Join-Path $BaseDir "stellive_karaoke_app_data"
$AppRepo  = Join-Path $BaseDir "stella_karaoke"

# 데이터 repo 원격 주소
$DataRepoUrl = "https://github.com/skrtjd/stellive_karaoke_app_data.git"

# 실제 복사 경로 (중요!)
$DATA = Join-Path $DataRepo "assets\data"
$APP  = Join-Path $AppRepo  "assets\data"

Write-Host "=== Stella Karaoke Data Sync ==="
Write-Host "DATA: $DATA"
Write-Host "APP : $APP"
Write-Host ""

# 1) 데이터 repo가 없으면 clone
if (!(Test-Path $DataRepo)) {
  Write-Host "[1/3] Data repo not found. Cloning..."
  git -C $BaseDir clone $DataRepoUrl
  if ($LASTEXITCODE -ne 0) { throw "git clone failed." }
} else {
  Write-Host "[1/3] Data repo exists. Pulling latest..."
  git -C $DataRepo pull
  if ($LASTEXITCODE -ne 0) { throw "git pull failed." }
}

# 2) 경로 체크
if (!(Test-Path $DATA)) {
  throw "DATA path not found: $DATA`n(데이터 repo 내부에 assets\data 폴더가 실제로 있는지 확인해줘)"
}
if (!(Test-Path $AppRepo)) {
  throw "App project not found: $AppRepo"
}

# 3) 앱 쪽 대상 폴더 생성 + robocopy 동기화
Write-Host ""
Write-Host "[2/3] Ensuring target directory exists..."
New-Item -ItemType Directory -Force -Path $APP | Out-Null

Write-Host "[3/3] Robocopy MIR sync..."
# /MIR : 완전 동기화(삭제 포함), /R:2 /W:1 : 재시도 줄여서 빨리 실패하도록
# /XD .git : 혹시 데이터 repo에 .git이 섞일 경우 방지(없어도 무해)
robocopy $DATA $APP /MIR /R:2 /W:1 /XD ".git"

# Robocopy 종료코드 규칙:
# 0~7 : 정상(복사없음/복사됨/추가파일 등)
# 8 이상 : 오류
$rc = $LASTEXITCODE
if ($rc -ge 8) {
  throw "Robocopy failed. ExitCode=$rc"
}

Write-Host ""
Write-Host "✅ Sync complete! (Robocopy ExitCode=$rc)"
Write-Host "Now you can run: flutter clean; flutter pub get; flutter build apk --release"
