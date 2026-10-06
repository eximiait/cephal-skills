# Prueba del wrapper de PowerShell. Solo corre en Windows; en otros sistemas se omite.
if ($env:OS -ne 'Windows_NT') {
  Write-Output 'test_wrapper.ps1: omitido (solo Windows)'
  exit 0
}
$ErrorActionPreference = 'Stop'
$wrapper = Join-Path $PSScriptRoot '..\scripts\cephal-version.ps1'
$fails = 0
function Assert-Eq($expected, $actual, $label) {
  if ($expected -ne $actual) {
    $script:fails++
    Write-Output "FAIL: $label`n  esperado: [$expected]`n  obtenido: [$actual]"
  }
}
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("cephal-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
Push-Location $tmp
try {
  git init -q -b develop
  git config user.name 'Dev Test'
  git config user.email 'dev@test'
  Set-Content pom.xml '<project><version>1.0.0</version></project>'
  git add -A
  git commit -q -m init

  $out = (& $wrapper context 2>&1 | Out-String)
  Assert-Eq $true $out.Contains('branch=develop') 'context: imprime la rama'
  Assert-Eq $true $out.Contains('version=1.0.0') 'context: imprime la versión'
  Assert-Eq 0 $LASTEXITCODE 'context: código de salida'

  & $wrapper nope 2>$null | Out-Null
  Assert-Eq 1 $LASTEXITCODE 'subcomando desconocido: código de salida'
}
finally {
  Pop-Location
  Remove-Item -Recurse -Force $tmp
}
if ($fails -gt 0) { exit 1 }
Write-Output 'test_wrapper.ps1: OK'
# Sin esto, el paso hereda el $LASTEXITCODE del último comando nativo (el subcomando inválido devuelve 1 a propósito).
exit 0
