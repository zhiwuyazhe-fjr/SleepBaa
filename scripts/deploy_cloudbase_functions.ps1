param(
  [string]$ConfigPath = ".cloudbase.local.json",
  [string]$AIProviderMode = "cloudbase_ai",
  [string]$AIProviderTimeoutMs = "60000",
  [string]$AIProviderBaseUrl = "",
  [string]$AIProviderApiKey = "",
  [string]$AIProviderModel = "hunyuan-2.0-instruct-20251111",
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

function Get-MapValue($Map, [string]$Key) {
  if ($null -eq $Map) {
    return $null
  }
  if ($Map -is [System.Collections.IDictionary]) {
    if ($Map.Contains($Key)) {
      return $Map[$Key]
    }
    return $null
  }
  $prop = $Map.PSObject.Properties[$Key]
  if ($null -ne $prop) {
    return $prop.Value
  }
  return $null
}

function Convert-ToHashtable($Value) {
  $result = @{}
  if ($null -eq $Value) {
    return $result
  }
  if (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string]) -and -not ($Value -is [System.Collections.IDictionary])) {
    return $result
  }
  if ($Value -is [System.Collections.IDictionary]) {
    foreach ($key in $Value.Keys) {
      $result[[string]$key] = [string]$Value[$key]
    }
    return $result
  }
  foreach ($prop in $Value.PSObject.Properties) {
    $result[[string]$prop.Name] = [string]$prop.Value
  }
  return $result
}

function Convert-EnvVariablesToHashtable($Value) {
  $result = @{}
  if ($null -eq $Value) {
    return $result
  }
  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    foreach ($item in $Value) {
      $key = [string](Get-MapValue $item "Key")
      if ([string]::IsNullOrWhiteSpace($key)) {
        continue
      }
      $result[$key] = [string](Get-MapValue $item "Value")
    }
  }
  return $result
}

function Get-FunctionEnvVariables([string]$FunctionName) {
  $detail = Invoke-Mcporter "cloudbase.queryFunctions(action: 'getFunctionDetail', functionName: '$FunctionName')"
  $candidates = @(
    (Get-MapValue $detail "EnvVariables"),
    (Get-MapValue (Get-MapValue $detail "data") "EnvVariables"),
    (Get-MapValue (Get-MapValue $detail "FunctionInfo") "EnvVariables"),
    (Get-MapValue (Get-MapValue (Get-MapValue $detail "data") "FunctionInfo") "EnvVariables"),
    (Get-MapValue (Get-MapValue (Get-MapValue $detail "data") "functionDetail") "EnvVariables"),
    (Get-MapValue (Get-MapValue (Get-MapValue (Get-MapValue $detail "data") "functionDetail") "Environment") "Variables"),
    (Get-MapValue (Get-MapValue (Get-MapValue $detail "data") "raw") "EnvVariables"),
    (Get-MapValue (Get-MapValue (Get-MapValue (Get-MapValue $detail "data") "raw") "Environment") "Variables")
  )
  foreach ($candidate in $candidates) {
    $map = Convert-EnvVariablesToHashtable $candidate
    if ($map.Count -gt 0) {
      return $map
    }
    $map = Convert-ToHashtable $candidate
    if ($map.Count -gt 0) {
      return $map
    }
  }
  return @{}
}

function Format-EnvLiteral($Map) {
  $parts = @()
  foreach ($entry in $Map.GetEnumerator() | Sort-Object Name) {
    $parts += "$($entry.Key): '$(Escape-Literal ([string]$entry.Value))'"
  }
  return $parts -join ", "
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

    $currentEnv = Get-FunctionEnvVariables $name
    $nextEnv = @{}
    foreach ($entry in $currentEnv.GetEnumerator()) {
      $nextEnv[[string]$entry.Key] = [string]$entry.Value
    }

    $nextEnv["CLOUDBASE_ENV_ID"] = $envId
    $nextEnv["AI_PROVIDER_MODE"] = $AIProviderMode
    $nextEnv["AI_PROVIDER_TIMEOUT_MS"] = $AIProviderTimeoutMs
    $nextEnv["AI_PROVIDER_BASE_URL"] = $AIProviderBaseUrl
    $nextEnv["AI_PROVIDER_API_KEY"] = $AIProviderApiKey
    $nextEnv["AI_PROVIDER_MODEL"] = $AIProviderModel

    $envLiteral = Format-EnvLiteral $nextEnv
    Invoke-McporterWithRetry "cloudbase.manageFunctions(action: 'updateFunctionConfig', functionName: '$name', envVariables: { $envLiteral })"

    $verifiedEnv = Get-FunctionEnvVariables $name
    $verifiedMode = [string](Get-MapValue $verifiedEnv "AI_PROVIDER_MODE")
    $verifiedModel = [string](Get-MapValue $verifiedEnv "AI_PROVIDER_MODEL")
    $verifiedBaseUrl = [string](Get-MapValue $verifiedEnv "AI_PROVIDER_BASE_URL")
    $verifiedTimeout = [string](Get-MapValue $verifiedEnv "AI_PROVIDER_TIMEOUT_MS")
    if (
      $verifiedMode -ne $AIProviderMode -or
      $verifiedModel -ne $AIProviderModel -or
      $verifiedBaseUrl -ne $AIProviderBaseUrl -or
      $verifiedTimeout -ne $AIProviderTimeoutMs
    ) {
      throw "Function '$name' config verification failed. Expected mode=$AIProviderMode model=$AIProviderModel baseUrl=$AIProviderBaseUrl timeout=$AIProviderTimeoutMs but got mode=$verifiedMode model=$verifiedModel baseUrl=$verifiedBaseUrl timeout=$verifiedTimeout"
    }
    Write-Host "[$name] AI_PROVIDER_MODE=$verifiedMode"
    Write-Host "[$name] AI_PROVIDER_MODEL=$verifiedModel"
    Write-Host "[$name] AI_PROVIDER_BASE_URL=$verifiedBaseUrl"
    Write-Host "[$name] AI_PROVIDER_TIMEOUT_MS=$verifiedTimeout"
  }

  try {
    Invoke-Mcporter "cloudbase.writeSecurityRule(resourceType: 'function', resourceId: 'app-api', aclTag: 'CUSTOM', rule: { '*': { invoke: 'auth != null' } })"
  }
  catch {
    $securityRuleMessage = $_.Exception.Message
    if ($securityRuleMessage -like "*Tool writeSecurityRule not found*" -or $securityRuleMessage -like "*Did you mean*") {
      Write-Warning "Skipping function security rule update because the current CloudBase MCP runtime does not expose writeSecurityRule."
    }
    else {
      throw
    }
  }

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
