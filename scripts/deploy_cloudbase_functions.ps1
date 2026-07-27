param(
  [string]$ConfigPath = ".cloudbase.local.json",
  [string]$AIProviderMode = "cloudbase_ai",
  [string]$AIProviderName = "",
  [string]$AIProviderGroup = "",
  [string]$AIProviderTimeoutMs = "60000",
  [string]$AIProviderBaseUrl = "",
  [string]$AIProviderApiKey = "",
  [string]$AIProviderModel = "hunyuan-2.0-instruct-20251111",
  [switch]$ClearAIProviderApiKey,
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

function Resolve-ProviderName([string]$Mode, [string]$ExplicitName) {
  if (-not [string]::IsNullOrWhiteSpace($ExplicitName)) {
    return $ExplicitName
  }

  switch ($Mode) {
    "cloudbase_ai" { return "cloudbase_ai" }
    "deterministic" { return "deterministic" }
    default { return "" }
  }
}

function Resolve-DesiredEnvValue(
  [hashtable]$CurrentEnv,
  [string]$RemoteKey,
  [string]$DefaultValue,
  [bool]$WasSpecified,
  [string]$SpecifiedValue
) {
  if ($WasSpecified) {
    return [string]$SpecifiedValue
  }
  if ($CurrentEnv.ContainsKey($RemoteKey)) {
    return [string]$CurrentEnv[$RemoteKey]
  }
  return $DefaultValue
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

    $desiredProviderMode = Resolve-DesiredEnvValue `
      -CurrentEnv $currentEnv `
      -RemoteKey "AI_PROVIDER_MODE" `
      -DefaultValue "cloudbase_ai" `
      -WasSpecified $PSBoundParameters.ContainsKey("AIProviderMode") `
      -SpecifiedValue $AIProviderMode
    $providerModeWasSpecified = $PSBoundParameters.ContainsKey("AIProviderMode")
    $providerModeWasUnsupported = $desiredProviderMode -notin @("cloudbase_ai", "deterministic")
    if ($providerModeWasSpecified -and $providerModeWasUnsupported) {
      throw "Unsupported AI provider mode '$desiredProviderMode'. Only cloudbase_ai and deterministic are supported."
    }
    if ($providerModeWasUnsupported) {
      Write-Warning "Replacing stale unsupported AI_PROVIDER_MODE='$desiredProviderMode' with cloudbase_ai."
      $desiredProviderMode = "cloudbase_ai"
    }
    $desiredProviderName = if ($PSBoundParameters.ContainsKey("AIProviderName")) {
      [string]$AIProviderName
    }
    elseif (
      -not $providerModeWasSpecified -and
      -not $providerModeWasUnsupported -and
      $currentEnv.ContainsKey("AI_PROVIDER_NAME")
    ) {
      [string]$currentEnv["AI_PROVIDER_NAME"]
    }
    else {
      Resolve-ProviderName -Mode $desiredProviderMode -ExplicitName ""
    }
    $desiredProviderGroup = Resolve-DesiredEnvValue `
      -CurrentEnv $currentEnv `
      -RemoteKey "AI_PROVIDER_GROUP" `
      -DefaultValue "" `
      -WasSpecified $PSBoundParameters.ContainsKey("AIProviderGroup") `
      -SpecifiedValue $AIProviderGroup
    $desiredProviderTimeoutMs = Resolve-DesiredEnvValue `
      -CurrentEnv $currentEnv `
      -RemoteKey "AI_PROVIDER_TIMEOUT_MS" `
      -DefaultValue "60000" `
      -WasSpecified $PSBoundParameters.ContainsKey("AIProviderTimeoutMs") `
      -SpecifiedValue $AIProviderTimeoutMs
    $desiredProviderBaseUrl = Resolve-DesiredEnvValue `
      -CurrentEnv $currentEnv `
      -RemoteKey "AI_PROVIDER_BASE_URL" `
      -DefaultValue "" `
      -WasSpecified $PSBoundParameters.ContainsKey("AIProviderBaseUrl") `
      -SpecifiedValue $AIProviderBaseUrl
    $desiredProviderApiKey = if ($ClearAIProviderApiKey) {
      ""
    }
    else {
      Resolve-DesiredEnvValue `
        -CurrentEnv $currentEnv `
        -RemoteKey "AI_PROVIDER_API_KEY" `
        -DefaultValue "" `
        -WasSpecified $PSBoundParameters.ContainsKey("AIProviderApiKey") `
        -SpecifiedValue $AIProviderApiKey
    }
    $desiredProviderModel = Resolve-DesiredEnvValue `
      -CurrentEnv $currentEnv `
      -RemoteKey "AI_PROVIDER_MODEL" `
      -DefaultValue "hunyuan-2.0-instruct-20251111" `
      -WasSpecified $PSBoundParameters.ContainsKey("AIProviderModel") `
      -SpecifiedValue $AIProviderModel

    if ($providerModeWasUnsupported) {
      if (-not $PSBoundParameters.ContainsKey("AIProviderGroup")) { $desiredProviderGroup = "" }
      if (-not $PSBoundParameters.ContainsKey("AIProviderBaseUrl")) { $desiredProviderBaseUrl = "" }
      if (-not $PSBoundParameters.ContainsKey("AIProviderApiKey") -and -not $ClearAIProviderApiKey) { $desiredProviderApiKey = "" }
      if (-not $PSBoundParameters.ContainsKey("AIProviderModel")) { $desiredProviderModel = "hunyuan-2.0-instruct-20251111" }
    }

    $nextEnv["CLOUDBASE_ENV_ID"] = $envId
    $nextEnv["AI_PROVIDER_MODE"] = $desiredProviderMode
    $nextEnv["AI_PROVIDER_NAME"] = $desiredProviderName
    $nextEnv["AI_PROVIDER_GROUP"] = $desiredProviderGroup
    $nextEnv["AI_PROVIDER_TIMEOUT_MS"] = $desiredProviderTimeoutMs
    $nextEnv["AI_PROVIDER_BASE_URL"] = $desiredProviderBaseUrl
    $nextEnv["AI_PROVIDER_API_KEY"] = $desiredProviderApiKey
    $nextEnv["AI_PROVIDER_MODEL"] = $desiredProviderModel

    $envLiteral = Format-EnvLiteral $nextEnv
    Invoke-McporterWithRetry "cloudbase.manageFunctions(action: 'updateFunctionConfig', functionName: '$name', envVariables: { $envLiteral })"

    $verifiedEnv = Get-FunctionEnvVariables $name
    $verifiedMode = [string](Get-MapValue $verifiedEnv "AI_PROVIDER_MODE")
    $verifiedName = [string](Get-MapValue $verifiedEnv "AI_PROVIDER_NAME")
    $verifiedGroup = [string](Get-MapValue $verifiedEnv "AI_PROVIDER_GROUP")
    $verifiedModel = [string](Get-MapValue $verifiedEnv "AI_PROVIDER_MODEL")
    $verifiedBaseUrl = [string](Get-MapValue $verifiedEnv "AI_PROVIDER_BASE_URL")
    $verifiedTimeout = [string](Get-MapValue $verifiedEnv "AI_PROVIDER_TIMEOUT_MS")
    $verifiedApiKeyState = if ([string]::IsNullOrWhiteSpace([string](Get-MapValue $verifiedEnv "AI_PROVIDER_API_KEY"))) {
      "empty"
    }
    else {
      "set"
    }
    $expectedApiKeyState = if ([string]::IsNullOrWhiteSpace($desiredProviderApiKey)) {
      "empty"
    }
    else {
      "set"
    }
    if (
      $verifiedMode -ne $desiredProviderMode -or
      $verifiedName -ne $desiredProviderName -or
      $verifiedGroup -ne $desiredProviderGroup -or
      $verifiedModel -ne $desiredProviderModel -or
      $verifiedBaseUrl -ne $desiredProviderBaseUrl -or
      $verifiedTimeout -ne $desiredProviderTimeoutMs -or
      $verifiedApiKeyState -ne $expectedApiKeyState
    ) {
      throw "Function '$name' config verification failed. Expected mode=$desiredProviderMode name=$desiredProviderName group=$desiredProviderGroup model=$desiredProviderModel baseUrl=$desiredProviderBaseUrl timeout=$desiredProviderTimeoutMs apiKey=$expectedApiKeyState but got mode=$verifiedMode name=$verifiedName group=$verifiedGroup model=$verifiedModel baseUrl=$verifiedBaseUrl timeout=$verifiedTimeout apiKey=$verifiedApiKeyState"
    }
    Write-Host "[$name] AI_PROVIDER_MODE=$verifiedMode"
    Write-Host "[$name] AI_PROVIDER_NAME=$verifiedName"
    Write-Host "[$name] AI_PROVIDER_GROUP=$verifiedGroup"
    Write-Host "[$name] AI_PROVIDER_MODEL=$verifiedModel"
    Write-Host "[$name] AI_PROVIDER_BASE_URL=$verifiedBaseUrl"
    Write-Host "[$name] AI_PROVIDER_TIMEOUT_MS=$verifiedTimeout"
    Write-Host "[$name] AI_PROVIDER_API_KEY=$verifiedApiKeyState"
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
