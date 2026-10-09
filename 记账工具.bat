@echo off
setlocal
chcp 65001 >nul
title 好好记账开发工具
set "JIZHANG_TOOL_FILE=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$source = Get-Content -LiteralPath $env:JIZHANG_TOOL_FILE -Raw -Encoding UTF8; & ([scriptblock]::Create(($source -split '(?m)^# POWERSHELL_START\r?$', 2)[1]))"
if errorlevel 1 (
  echo 工具启动失败，请查看上方错误。
  pause
  exit /b 1
)
exit /b 0
# POWERSHELL_START
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding
$project = Split-Path -Parent $env:JIZHANG_TOOL_FILE
$workspace = Split-Path -Parent $project
$dist = Join-Path $project 'dist'
$toolDir = Join-Path $dist 'windows-tool'
$script:deviceId = $null

function Find-Tool($Candidates, $Command) {
    foreach ($path in $Candidates) {
        if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) { return $path }
    }
    $found = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.Source }
}

function Read-Choice($Title, $Items) {
    Write-Host "`n$Title" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Items.Count; $i++) { Write-Host ('{0}. {1}' -f ($i + 1), $Items[$i]) }
    Write-Host '0. 返回或退出'
    while ($true) {
        $answer = Read-Host '请输入编号'
        if ($answer -match '^\d{1,3}$') {
            $number = [int]$answer
            if ($number -eq 0) { return $null }
            if ($number -le $Items.Count) { return ($number - 1) }
        }
        Write-Host '编号无效，请重新输入。' -ForegroundColor Yellow
    }
}

function Require-Tool($Path, $Name) {
    if (-not $Path) { throw "未找到 $Name，请检查项目旁的 tools 目录或系统环境变量。" }
}

function New-Log {
    $folder = Join-Path $toolDir 'logs'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $script:log = Join-Path $folder ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.log')
    Write-Host "操作日志：$script:log"
}

function Invoke-Logged($Program, $Arguments) {
    $writer = [IO.StreamWriter]::new($script:log, $true, [Text.UTF8Encoding]::new($false))
    $lines = [Collections.Generic.List[string]]::new()
    $previous = $ErrorActionPreference
    try {
        $writer.WriteLine(('> {0} {1}' -f $Program, ($Arguments -join ' ')))
        $writer.AutoFlush = $true
        $ErrorActionPreference = 'Continue' # Windows PowerShell 把原生工具标准错误包装成错误对象。
        $global:LASTEXITCODE = $null
        & $Program @Arguments 2>&1 | ForEach-Object {
            $line = if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_.ToString() }
            Write-Host $line
            $writer.WriteLine($line)
            $lines.Add($line)
        }
        $code = if ($null -eq $global:LASTEXITCODE) { -1 } else { $global:LASTEXITCODE }
        $script:lastOutput = $lines -join "`n"
        $writer.WriteLine("退出码：$code")
        return $code
    } finally {
        $ErrorActionPreference = $previous
        $writer.Dispose()
    }
}

function Select-Device([switch]$Change) {
    Require-Tool $adb '安卓调试工具（ADB）'
    $devices = @(& $adb devices -l | ForEach-Object {
        if ($_ -match '^(\S+)\s+(device|offline|unauthorized)\b(.*)$') {
            $serial, $state, $details = $Matches[1], $Matches[2], $Matches[3]
            if ($state -ne 'device') {
                $reason = if ($state -eq 'unauthorized') { '未授权，请在手机上允许 USB 调试' } else { '设备离线，请重新连接' }
                Write-Host "${serial}：$reason" -ForegroundColor Yellow
            } else {
                $model = if ($details -match 'model:(\S+)') { $Matches[1].Replace('_', ' ') } else { '未知型号' }
                $kind = if ($serial -like 'emulator-*') { '模拟器' } else { '设备' }
                [pscustomobject]@{ Serial = $serial; Label = "$kind $model（$serial）" }
            }
        }
    })
    if (-not $devices.Count) { $script:deviceId = $null; throw '没有可用设备。请连接手机、开启 USB 调试，并在手机上确认授权。' }
    if (-not $Change -and $script:deviceId -in $devices.Serial) { return $script:deviceId }
    $index = if ($devices.Count -eq 1) { 0 } else { Read-Choice '选择目标设备' @($devices.Label) }
    if ($null -eq $index) { return $null }
    $script:deviceId = $devices[$index].Serial
    Write-Host ('当前设备：' + $devices[$index].Label) -ForegroundColor Green
    return $script:deviceId
}

function Install-Apk($Apk) {
    $serial = Select-Device
    if (-not $serial) { return }
    if ($Apk.Name -match '(?:^|-)(arm64-v8a|armeabi-v7a|x86_64)(?:-|\.apk$)') {
        $abi = $Matches[1]
        $supported = (& $adb -s $serial shell getprop ro.product.cpu.abilist).Trim() -split ','
        if ($LASTEXITCODE -ne 0) { throw '无法读取设备架构，请检查设备连接。' }
        if ($abi -notin $supported) { throw "该安装包的架构与设备不匹配（$abi）。请选用匹配的拆分包或通用包。" }
    }
    Write-Host "正在覆盖安装并保留应用数据：$($Apk.FullName)" -ForegroundColor Cyan
    if ((Invoke-Logged $adb @('-s', $serial, 'install', '-r', $Apk.FullName)) -ne 0) {
        if ($script:lastOutput -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') { throw '安装包与已装应用的签名不一致。请使用相同签名的包；本工具不会自动卸载或清除账本。' }
        if ($script:lastOutput -match 'INSTALL_FAILED_VERSION_DOWNGRADE') { throw '系统拒绝安装版本号更低的包。请选用版本号合适的安装包。' }
        throw '安装失败，请查看上方设备返回的信息及日志。'
    }
    if ((Invoke-Logged $adb @('-s', $serial, 'shell', 'am', 'start', '-n', "$appId/.MainActivity")) -ne 0 -or $script:lastOutput -match '(?m)^Error') {
        throw '安装已完成，但启动应用失败，请在手机上手动打开并查看日志。'
    }
    Write-Host '安装完成，已启动好好记账。' -ForegroundColor Green
}

function Choose-Apk($Files) {
    if (-not $Files.Count) { throw '没有找到安装包，请先编译。' }
    $Files = @($Files | Sort-Object LastWriteTime -Descending)
    $labels = @($Files | ForEach-Object {
        '{0} | {1} | {2:N1} MB | {3}' -f $_.Name, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), ($_.Length / 1MB), $_.DirectoryName
    })
    $index = Read-Choice '选择要安装的版本（按时间从新到旧排列）' $labels
    if ($null -ne $index) { Install-Apk $Files[$index] }
}

function Build-Apk {
    Require-Tool $flutter 'Flutter 构建工具'
    Require-Tool $dart 'Dart 版本工具'
    $modeIndex = Read-Choice '选择编译版本' @('调试版', '性能分析版', '发布模式版')
    if ($null -eq $modeIndex) { return }
    $mode = @('debug', 'profile', 'release')[$modeIndex]
    $access = Read-Choice '选择功能权限' @('全部功能开放（测试用）', '正常会员限制')
    if ($null -eq $access) { return }
    $layout = Read-Choice '选择安装包类型' @('按架构拆分（包体更小）', '通用安装包（兼容更多设备）')
    if ($null -eq $layout) { return }
    $after = Read-Choice '编译完成后' @('只保存安装包', '安装到设备并启动')
    if ($null -eq $after) { return }
    $buildVersion = & $dart (Join-Path $project 'scripts\bump_build_version.dart')
    if ($LASTEXITCODE -ne 0 -or $buildVersion -notmatch '^(\d+\.\d+\.\d+)\+([1-9]\d{0,8})$') { throw '无法递增版本号，未开始编译。' }
    $buildName, $buildNumber = $Matches[1], $Matches[2]
    $script:version = $buildVersion
    $free = @('true', 'false')[$access]
    $accessTag = @('open', 'membership')[$access]
    Write-Host "本次版本：$buildVersion；功能权限：$(@('全部功能开放', '正常会员限制')[$access])"
    if ($mode -eq 'release') { Write-Host "发布模式签名：$signing" -ForegroundColor Yellow }
    $arguments = @('build', 'apk', "--$mode", "--dart-define=ALL_FEATURES_FREE_FOR_TESTING=$free", "--build-name=$buildName", "--build-number=$buildNumber")
    if ($layout -eq 0) { $arguments += '--split-per-abi' }
    Push-Location -LiteralPath $project
    try {
        if ((Invoke-Logged $flutter $arguments) -ne 0) { throw '编译失败，未归档或安装本次构建，请查看日志。' }
    } finally { Pop-Location }
    $output = Join-Path $project 'build\app\outputs\flutter-apk'
    $names = if ($layout -eq 0) { @('armeabi-v7a', 'arm64-v8a', 'x86_64') | ForEach-Object { "app-$_-$mode.apk" } } else { @("app-$mode.apk") }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $packages = @(foreach ($name in $names) {
        $source = Join-Path $output $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "编译返回成功但找不到预期安装包：$source" }
        $abiTag = if ($layout -eq 0) { $name.Substring(4).Replace("-$mode.apk", '') } else { 'universal' }
        $target = Join-Path $dist "jizhang_app-$buildVersion-$mode-$accessTag-$stamp-$abiTag.apk"
        Copy-Item -LiteralPath $source -Destination $target
        Write-Host "已归档：$target" -ForegroundColor Green
        Get-Item -LiteralPath $target
    })
    if ($after -eq 1) {
        if ($packages.Count -eq 1) { Install-Apk $packages[0] } else { Choose-Apk $packages }
    }
}

function Take-Screenshot {
    $serial = Select-Device
    if (-not $serial) { return }
    $folder = Join-Path $toolDir 'screenshots'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $name = '截图-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.png'
    $target = Join-Path $folder $name
    $remote = '/sdcard/jizhang-tool-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.png'
    try {
        if ((Invoke-Logged $adb @('-s', $serial, 'shell', 'screencap', '-p', $remote)) -ne 0) { throw '设备截图失败，请检查设备连接和当前页面。' }
        if ((Invoke-Logged $adb @('-s', $serial, 'pull', $remote, $target)) -ne 0) { throw '截图传输失败，请查看日志。' }
    } finally {
        $null = Invoke-Logged $adb @('-s', $serial, 'shell', 'rm', '-f', $remote)
    }
    $bytes = [IO.File]::ReadAllBytes($target)
    if ($bytes.Length -lt 8 -or [BitConverter]::ToString($bytes, 0, 8) -ne '89-50-4E-47-0D-0A-1A-0A') { throw '截图文件不完整，请重新截图。' }
    Write-Host "截图已保存：$target" -ForegroundColor Green
    Invoke-Item -LiteralPath $target
}

function Open-Folder($Path) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Invoke-Item -LiteralPath $Path
}

try {
    if (-not (Test-Path -LiteralPath (Join-Path $project 'pubspec.yaml'))) { throw '请把本脚本放在记账 APP 项目根目录（与 pubspec.yaml 同级）。' }
    $version = [regex]::Match((Get-Content -LiteralPath (Join-Path $project 'pubspec.yaml') -Raw), '(?m)^version:\s*([\w.+-]+)').Groups[1].Value
    $appId = [regex]::Match((Get-Content -LiteralPath (Join-Path $project 'android\app\build.gradle.kts') -Raw), 'applicationId\s*=\s*"([\w.]+)"').Groups[1].Value
    if (-not $version -or -not $appId) { throw '无法从项目配置中读取版本号或应用包名。' }
    $flutter = Find-Tool @($env:FLUTTER_BIN, (Join-Path $workspace 'tools\flutter_sdk\flutter\bin\flutter.bat')) 'flutter.bat'
    $dart = Find-Tool @($env:DART_BIN, (Join-Path $workspace 'tools\flutter_sdk\flutter\bin\cache\dart-sdk\bin\dart.exe'), $(if ($flutter) { Join-Path (Split-Path -Parent $flutter) 'dart.bat' })) 'dart'
    $adb = Find-Tool @($env:ADB_BIN, (Join-Path $workspace 'tools\android-sdk\platform-tools\adb.exe')) 'adb.exe'
    $jdkRoot = Join-Path $workspace 'tools\jdk21'
    if (Test-Path -LiteralPath $jdkRoot) {
        $java = Get-ChildItem -LiteralPath $jdkRoot -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe') } | Select-Object -First 1
        if ($java) { $env:JAVA_HOME = $java.FullName; $env:PATH = "$($java.FullName)\bin;$env:PATH" }
    }
    if ($flutter) { $env:PATH = (Split-Path -Parent $flutter) + ';' + $env:PATH }
    if ($adb) {
        $env:PATH = (Split-Path -Parent $adb) + ';' + $env:PATH
        $env:ANDROID_HOME = Split-Path -Parent (Split-Path -Parent $adb)
        $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
    }
    $signing = if (Test-Path -LiteralPath (Join-Path $project 'android\key.properties')) { '已提供正式签名配置，构建时校验' } else { '调试签名，仅供本地测试验收' }
    while ($true) {
        Write-Host "`n========== 好好记账开发工具 ==========" -ForegroundColor Cyan
        Write-Host "项目版本：$version；当前设备：$(if ($script:deviceId) { $script:deviceId } else { '尚未选择' })"
        $action = Read-Choice '主菜单' @('编译安装包', '选择已有版本安装并启动', '设备截图并打开', '选择或切换设备', '打开安装包目录', '打开截图目录', '检查环境', '打开日志目录')
        if ($null -eq $action) { break }
        try {
            New-Log
            switch ($action) {
                0 { Build-Apk }
                1 {
                    $folders = @($dist, (Join-Path $workspace 'dist'), (Join-Path $project 'build\app\outputs\flutter-apk'))
                    $files = @($folders | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object { Get-ChildItem -LiteralPath $_ -Filter '*.apk' -File } | Sort-Object LastWriteTime -Descending)
                    Choose-Apk $files
                }
                2 { Take-Screenshot }
                3 { $null = Select-Device -Change }
                4 { Open-Folder $dist }
                5 { Open-Folder (Join-Path $toolDir 'screenshots') }
                6 {
                    Write-Host "项目目录：$project`n应用包名：$appId`nFlutter：$flutter`n安卓调试工具：$adb`nJava：$env:JAVA_HOME`n发布模式签名：$signing"
                    Require-Tool $flutter 'Flutter 构建工具'
                    Require-Tool $adb '安卓调试工具（ADB）'
                    $null = Invoke-Logged $flutter @('--version')
                    $null = Invoke-Logged $adb @('devices', '-l')
                }
                7 { Open-Folder (Join-Path $toolDir 'logs') }
            }
        } catch {
            Write-Host ("操作失败：" + $_.Exception.Message) -ForegroundColor Red
            if ($script:log) { Add-Content -LiteralPath $script:log -Value $_.Exception.Message -Encoding UTF8; Write-Host "日志位置：$script:log" }
        }
    }
} catch {
    Write-Host ("工具启动失败：" + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
