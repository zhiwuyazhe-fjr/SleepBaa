param(
  [string]$ConfigPath = ".cloudbase.local.json",
  [string]$AIProviderMode = "deterministic",
  [string]$AIProviderTimeoutMs = "12000",
  [string]$AIProviderBaseUrl = "",
  [string]$AIProviderApiKey = "",
  [string]$AIProviderModel = "",
  [switch]$SkipGateway
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Read-Config([string]$RepoRoot, [string]$RelativePath) {
  $fullPath = Join-Path $RepoRoot $RelativePath
  if (-not (Test-Path $fullPath)) {
    throw "CloudBase config file not found: $fullPath"
  }
  return (Get-Content -Path $fullPath -Raw | ConvertFrom-Json)
}

function Escape-Literal([string]$Value) {
  return $Value.Replace("\", "\\").Replace("'", "\'")
}

function ConvertFrom-McporterPayload([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $null
  }

  $clean = [regex]::Replace($Text, "\x1B\[[0-9;]*[A-Za-z]", "")
  $start = $clean.IndexOf("{")
  $end = $clean.LastIndexOf("}")
  if ($start -lt 0 -or $end -lt $start) {
    throw "mcporter output did not contain a JSON object.`n$clean"
  }

  $json = $clean.Substring($start, $end - $start + 1)
  try {
    return $json | ConvertFrom-Json
  }
  catch {
    $withoutNextActions = [regex]::Replace(
      $json,
      ',\s*"nextActions"\s*:\s*\[[\s\S]*\]\s*}',
      '}'
    )
    return $withoutNextActions | ConvertFrom-Json
  }
}

function Invoke-Mcporter([string]$Expression) {
  $output = & npx.cmd mcporter call $Expression --output json 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ($output -join [Environment]::NewLine)
  }
  $joined = $output -join [Environment]::NewLine
  if ([string]::IsNullOrWhiteSpace($joined)) {
    return $null
  }
  $result = ConvertFrom-McporterPayload $joined
  if ($null -ne $result -and $result.PSObject.Properties["success"] -and -not $result.success) {
    throw ([string]$result.message)
  }
  return $result
}

function Invoke-McporterWithRetry(
  [string]$Expression,
  [int]$MaxAttempts = 6,
  [int]$DelaySeconds = 5
) {
  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    try {
      return Invoke-Mcporter $Expression
    }
    catch {
      $message = $_.Exception.Message
      $isRetryable = $message -like "*Updating*" -or $message -like "*Updating状态*"
      if (-not $isRetryable -or $attempt -eq $MaxAttempts) {
        throw
      }
      Start-Sleep -Seconds $DelaySeconds
    }
  }
}

$repoRoot = Get-RepoRoot
$config = Read-Config -RepoRoot $repoRoot -RelativePath $ConfigPath
$envId = [string]$config.CLOUDBASE_ENV_ID
if ([string]::IsNullOrWhiteSpace($envId)) {
  throw "Missing CLOUDBASE_ENV_ID in local config."
}

$functionRoot = ($repoRoot.Replace("\", "/") + "/functions")
$functions = @(
  @{ Name = "app-api"; Type = "HTTP"; Runtime = "Nodejs18.15"; Timeout = 60; ProtocolType = "HTTP" },
  @{ Name = "on-sleep-session-write"; Type = "Event"; Runtime = "Nodejs18.15"; Timeout = 60 },
  @{ Name = "on-dream-entry-write"; Type = "Event"; Runtime = "Nodejs18.15"; Timeout = 60 }
)

Push-Location $repoRoot
try {
  npm --prefix functions run prepare:deploy

  $functionList = Invoke-Mcporter "cloudbase.queryFunctions(action: 'listFunctions')"
  $existingFunctions = @{}
  if ($functionList.data.functions) {
    foreach ($item in $functionList.data.functions) {
      $existingFunctions[[string]$item.FunctionName] = $true
    }
  }

  foreach ($function in $functions) {
    $name = $function.Name
    if ($existingFunctions.ContainsKey($name)) {
      Invoke-Mcporter "cloudbase.manageFunctions(action: 'updateFunctionCode', functionName: '$name', functionRootPath: '$functionRoot')"
    }
    else {
      if ($function.Type -eq "HTTP") {
        Invoke-Mcporter "cloudbase.manageFunctions(action: 'createFunction', func: { name: '$name', type: 'HTTP', protocolType: 'HTTP', runtime: '$($function.Runtime)', timeout: $($function.Timeout) }, functionRootPath: '$functionRoot', force: true)"
      }
      else {
        Invoke-Mcporter "cloudbase.manageFunctions(action: 'createFunction', func: { name: '$name', type: 'Event', runtime: '$($function.Runtime)', timeout: $($function.Timeout) }, functionRootPath: '$functionRoot', force: true)"
      }
    }

    $envEntries = @(
      "CLOUDBASE_ENV_ID: '$(Escape-Literal $envId)'",
      "AI_PROVIDER_MODE: '$(Escape-Literal $AIProviderMode)'",
      "AI_PROVIDER_TIMEOUT_MS: '$(Escape-Literal $AIProviderTimeoutMs)'"
    )

    if (-not [string]::IsNullOrWhiteSpace($AIProviderBaseUrl)) {
      $envEntries += "AI_PROVIDER_BASE_URL: '$(Escape-Literal $AIProviderBaseUrl)'"
    }
    if (-not [string]::IsNullOrWhiteSpace($AIProviderApiKey)) {
      $envEntries += "AI_PROVIDER_API_KEY: '$(Escape-Literal $AIProviderApiKey)'"
    }
    if (-not [string]::IsNullOrWhiteSpace($AIProviderModel)) {
      $envEntries += "AI_PROVIDER_MODEL: '$(Escape-Literal $AIProviderModel)'"
    }

    $envLiteral = $envEntries -join ", "
    Invoke-McporterWithRetry "cloudbase.manageFunctions(action: 'updateFunctionConfig', functionName: '$name', envVariables: { $envLiteral })"
  }

  Invoke-Mcporter "cloudbase.writeSecurityRule(resourceType: 'function', resourceId: 'app-api', aclTag: 'CUSTOM', rule: { '*': { invoke: 'auth != null' } })"

  if (-not $SkipGateway) {
    $gateway = Invoke-Mcporter "cloudbase.queryGateway(action: 'getAccess', targetType: 'function', targetName: 'app-api')"
    $hasGateway = $false
    if ($gateway.data.total -gt 0) {
      $hasGateway = $true
    }
    if (-not $hasGateway) {
      Invoke-Mcporter "cloudbase.manageGateway(action: 'createAccess', targetType: 'function', targetName: 'app-api', path: '/app-api', type: 'HTTP', auth: true)"
    }
  }
}
finally {
  Pop-Location
}

Write-Host ""
Write-Host "CloudBase functions deployed."
Write-Host "app-api: https://$($envId).service.tcloudbase.com/app-api"
