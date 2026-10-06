# Ejecuta cephal-version con el bash de Git for Windows. Uso: cephal-version.ps1 [args...]
$ErrorActionPreference = 'Stop'

function Find-GitBash {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git) {
    $root = (& git --exec-path)
    for ($i = 0; $i -lt 3; $i++) { $root = Split-Path -Parent $root }
    foreach ($rel in 'bin\bash.exe', 'usr\bin\bash.exe') {
      $candidate = Join-Path $root $rel
      if (Test-Path $candidate) { return $candidate }
    }
  }
  # bash.exe de System32 es el lanzador de WSL, no el de Git.
  $bash = Get-Command bash -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch '\\Windows\\System32\\' } | Select-Object -First 1
  if ($bash) { return $bash.Source }
  return $null
}

$bash = Find-GitBash
if (-not $bash) {
  [Console]::Error.WriteLine('ERR: no se encontró bash de Git for Windows')
  exit 1
}
& $bash (Join-Path $PSScriptRoot 'cephal-version') @args
exit $LASTEXITCODE
