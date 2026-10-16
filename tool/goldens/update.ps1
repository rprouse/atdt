# Regenerates golden images on Linux, matching CI, from a Windows machine.
#
#   pwsh tool/goldens/update.ps1            # update all goldens
#   pwsh tool/goldens/update.ps1 -Check     # compare only, like CI
#
# The repo is copied into the container (minus build outputs) so the
# container's `flutter pub get` never touches the host's .dart_tool.
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
$image = 'atdt-goldens:3.47.7'

docker build -t $image "$PSScriptRoot"
if ($LASTEXITCODE) { exit $LASTEXITCODE }

$update = if ($Check) { '' } else { '--update-goldens' }
$script = @"
set -e
mkdir /work
tar -C /repo --exclude=./.dart_tool --exclude=./build --exclude=./android --exclude=./ios -cf - . | tar -C /work -xf -
cd /work
flutter pub get >/dev/null
flutter test $update test/reader/reader_golden_test.dart
cp test/reader/goldens/*.png /out/
"@ -replace "`r", ''

New-Item -ItemType Directory -Force "$repo/test/reader/goldens" | Out-Null
docker run --rm `
  -v "${repo}:/repo:ro" `
  -v "${repo}/test/reader/goldens:/out" `
  $image bash -c $script
exit $LASTEXITCODE
