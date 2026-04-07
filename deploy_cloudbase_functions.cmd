@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\deploy_cloudbase_functions.ps1" %*
