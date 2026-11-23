$ErrorActionPreference = 'Stop'

# Build the exOS-packaged REMMS set in the Mutineer-eX repository. The Python
# builder also compiles the BBS because all live modules must remain matched
# to REMMS session contract 9 and its $3CFF resident ceiling.
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$builder = Join-Path $repoRoot 'tools\build.py'

Push-Location $repoRoot
try {
    python $builder --no-disk
    if ($LASTEXITCODE -ne 0) {
        throw "Mutineer-eX/REMMS build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Write-Host 'Built REMMS.COM, RVRFULL.SYS, RVRTWOW.SYS, NHAND.SYS and TDAPE.COM'
