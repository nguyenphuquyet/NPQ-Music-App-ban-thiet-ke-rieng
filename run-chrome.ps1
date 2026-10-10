$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter run -d chrome --web-hostname localhost --web-port 5000 --dart-define=API_BASE_URL=http://localhost:3000
