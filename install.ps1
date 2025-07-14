# install.ps1
# 适用于 Windows PowerShell 的 Claude Code 安装脚本

# 设置如果遇到任何错误，脚本将立即停止执行
$ErrorActionPreference = "Stop"

# --- 函数定义 ---

# 定义安装 Node.js 的函数
function Install-NodeJs {
    Write-Host "🚀 开始在 Windows 上安装 Node.js..."

    # 为 nvm-windows 定义下载和安装路径
    $nvmVersion = "1.1.12" # 可以根据需要更新到 nvm-windows 的最新版本
    $nvmZipUrl = "https://github.com/coreybutler/nvm-windows/releases/download/$($nvmVersion)/nvm-setup.zip"
    $tempPath = "$env:TEMP\nvm-windows"
    $zipFile = "$tempPath\nvm-setup.zip"
    $installerFile = "$tempPath\nvm-setup.exe"

    # 创建临时目录
    if (-not (Test-Path -Path $tempPath)) {
        New-Item -ItemType Directory -Path $tempPath | Out-Null
    }

    # 1. 下载 nvm-windows
    Write-Host "📥 正在下载 nvm-windows..."
    try {
        Invoke-WebRequest -Uri $nvmZipUrl -OutFile $zipFile
    } catch {
        Write-Error "❌ 下载 nvm-windows 失败。请检查您的网络连接或访问此链接手动下载: $($nvmZipUrl)"
        exit 1
    }

    # 2. 解压安装程序
    Write-Host "📦 正在解压安装程序..."
    Expand-Archive -Path $zipFile -DestinationPath $tempPath -Force

    # 3. 静默安装 nvm-windows
    Write-Host "⚙️ 正在静默安装 nvm-windows... 这可能需要管理员权限。"
    # nvm-windows 安装程序需要管理员权限才能正确设置符号链接
    Start-Process -FilePath $installerFile -ArgumentList "/SILENT" -Verb RunAs -Wait

    Write-Host "✅ nvm-windows 安装完成。请注意：您可能需要重新启动终端才能使 'nvm' 命令生效。"

    # 4. 刷新环境变量以立即使用 nvm
    Write-Host "🔄 正在刷新环境变量..."
    $env:NVM_HOME = "$env:APPDATA\nvm"
    $env:NVM_SYMLINK = "$env:ProgramFiles\nodejs"
    $env:Path = "$env:NVM_HOME;$env:NVM_SYMLINK;$env:Path"
    
    # 5. 安装并使用 Node.js
    Write-Host "📦 正在下载并安装 Node.js v22..."
    try {
        nvm install 22
        nvm use 22
    } catch {
         Write-Error "❌ 安装 Node.js v22 失败。请尝试重新启动一个新的 PowerShell 终端并手动运行 'nvm install 22' 和 'nvm use 22'。"
         exit 1
    }

    Write-Host "✅ Node.js 安装完成!"
    Write-Host "   - Node.js 版本: $(node -v)"
    Write-Host "   - npm 版本: $(npm -v)"
}

# --- 脚本主流程 ---

# 1. 检查 Node.js 版本
$nodeInstalled = $false
if (Get-Command node -ErrorAction SilentlyContinue) {
    $currentVersion = (node -v).Replace("v", "")
    $majorVersion = ($currentVersion -split "\.")[0]

    if ([int]$majorVersion -ge 18) {
        Write-Host "✅ Node.js 已安装，版本为 v$($currentVersion)，符合要求。"
        $nodeInstalled = $true
    } else {
        Write-Host "⚠️  发现 Node.js v$($currentVersion)，但版本低于 v18。即将为您升级..."
        Install-NodeJs
        $nodeInstalled = $true
    }
} else {
    Write-Host "ℹ️ 未发现 Node.js，即将开始安装..."
    Install-NodeJs
    $nodeInstalled = $true
}

# 2. 检查并安装 Claude Code
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host "✅ Claude Code 已安装。"
} else {
    Write-Host "ℹ️ 未发现 Claude Code，即将开始安装..."
    npm install -g @anthropic-ai/claude-code
    Write-Host "✅ Claude Code 安装完成。"
}

# 3. 配置 Claude Code 以跳过引导
Write-Host "⚙️ 正在配置 Claude Code..."
$claudeConfigFile = Join-Path -Path $env:USERPROFILE -ChildPath ".claude.json"
$config = @{ hasCompletedOnboarding = $true }

if (Test-Path $claudeConfigFile) {
    $currentConfig = Get-Content $claudeConfigFile | ConvertFrom-Json
    # 将现有配置与新配置合并
    $currentConfig.PSObject.Properties | ForEach-Object {
        if ($_.Name -ne "hasCompletedOnboarding") {
            $config[$_.Name] = $_.Value
        }
    }
}
$config | ConvertTo-Json | Set-Content -Path $claudeConfigFile -Encoding UTF8

# 4. 提示用户输入 API 密钥
Write-Host ""
Write-Host "🔑 请输入您的 Moonshot API 密钥:" -ForegroundColor Yellow
Write-Host "   您可以从这里获取您的 API 密钥: https://platform.moonshot.cn/console/api-keys"
Write-Host "   注意：为了安全，您的输入将不会显示在屏幕上。请直接粘贴您的密钥后按 Enter。"
Write-Host ""
$apiKey = Read-Host -AsSecureString

if ($apiKey.Length -eq 0) {
    Write-Error "❌ API 密钥不能为空。请重新运行脚本。"
    exit 1
}

# 将 SecureString 转换为普通文本以便设置环境变量
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey)
$plainApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)


# 5. 设置永久环境变量
Write-Host "📝 正在为您设置永久的用户环境变量..."
$envTarget = [System.EnvironmentVariableTarget]::User

# 设置 ANTHROPIC_BASE_URL
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "https://api.moonshot.cn/anthropic/", $envTarget)

# 设置 ANTHROPIC_API_KEY
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $plainApiKey, $envTarget)

Write-Host "✅ 环境变量设置成功。"

# --- 完成 ---
Write-Host ""
Write-Host "🎉 安装已成功完成!" -ForegroundColor Green
Write-Host ""
Write-Host "🔄 请务必重新启动您的终端 (PowerShell, Command Prompt, VS Code Terminal 等) 以使所有更改完全生效。" -ForegroundColor Yellow
Write-Host ""
Write-Host "🚀 之后，您就可以通过输入以下命令开始使用 Claude Code 了:"
Write-Host "   claude" -ForegroundColor Cyan
