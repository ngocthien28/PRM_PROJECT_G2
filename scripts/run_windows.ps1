[CmdletBinding()]
param(
    [switch]$Emulator,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction Stop
$runArguments = @('run', '-d', 'windows', '--no-devtools')
if ($Emulator) {
    $runArguments += '--dart-define=USE_FIREBASE_EMULATOR=true'
}
$runArguments += $FlutterArguments

Push-Location -LiteralPath $projectRoot
try {
    $hideServiceUrl = $false
    # Filter stdout only. Flutter/build errors on stderr remain visible.
    & $flutterCommand.Source @runArguments | ForEach-Object {
        $line = [string]$_
        if ($hideServiceUrl) {
            $hideServiceUrl = $false
            if ($line.Trim() -match '^https?://127\.0\.0\.1:\d+/') {
                return
            }
        }
        if ($line -match '^A Dart VM Service on .+ is available at:') {
            $hideServiceUrl = $line -notmatch 'https?://'
            return
        }
        if ($line -match '^(?:Before: |After: |Transaction (?:set|update|delete)\S)') {
            return
        }
        Write-Output $line
    }
    $runExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $runExitCode
