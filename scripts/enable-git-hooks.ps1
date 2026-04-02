$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')

git config core.hooksPath .githooks
Write-Host 'Git hooks enabled: core.hooksPath=.githooks'
