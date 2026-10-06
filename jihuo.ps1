# ==========================================
# 1. 构建服务器地址列表 (支持动态+多个备用)
# ==========================================

$ServerList = @()

# A. 尝试获取动态主地址 (通过 irm ... | iex 调用时生效)
$CurrentScriptPath = $MyInvocation.MyCommand.Definition
if ($CurrentScriptPath -match "^https?://") {
    # 提取协议 + 主机 (例如: http://192.168.0.15)
    $BaseUrl = $CurrentScriptPath.Substring(0, $CurrentScriptPath.LastIndexOf("/"))
    $DynamicUrl = "$BaseUrl/MAS_AIO.cmd"
    
    # 将动态地址加入列表首位 (优先级最高)
    $ServerList += $DynamicUrl
    Write-Host "[*] 已识别主服务器地址: $DynamicUrl" -ForegroundColor Cyan
} else {
    Write-Host "[-] 检测到本地运行模式，将跳过动态地址，直接使用备用列表。" -ForegroundColor Yellow
}

# B. 【在这里修改】添加你的多个备用地址
# 如果上面的动态地址失败，或者你是本地运行，脚本会按顺序尝试下面的地址
$FallbackServers = @(

"https://gh-proxy.org/https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/refs/heads/master/MAS/All-In-One-Version-KL/MAS_AIO.cmd",
"https://gh-proxy.org/https://raw.githubusercontent.com/995cc25/Microsoft-Activation-Scripts/refs/heads/master/MAS_AIO.cmd",
    "https://github.com/995cc25/Microsoft-Activation-Scripts.git/MAS_AIO.cmd",   # 地址 1
    "https://地址2/MAS_AIO.cmd",
    "https://地址3/MAS_AIO.cmd",
    "https://地址4/MAS_AIO.cmd",
 "http://地址/MAS_AIO.cmd"        # 备用地址 此地方没有逗号看清楚还要看有没有加s



)

# 将备用地址合并到总列表 (自动去重，防止动态地址和备用1重复时尝试两次)
foreach ($srv in $FallbackServers) {
    if ($ServerList -notcontains $srv) {
        $ServerList += $srv
    }
}

Write-Host "[*] 共加载 $($ServerList.Count) 个候选服务器地址." -ForegroundColor Gray

# ==========================================
# 2. 设置临时文件
# ==========================================
$TempFile = Join-Path $env:TEMP "MAS_Launcher_$((Get-Date).ToString('yyyyMMddHHmmss')).cmd"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Microsoft Activation Scripts 启动器" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ==========================================
# 3. & 4. 循环尝试连接并下载 (核心修改：故障转移机制)
# ==========================================
$DownloadSuccess = $false
$LastErrorMessage = ""

foreach ($Url in $ServerList) {
    try {
        Write-Host "[*] 正在尝试连接: $Url ..." -ForegroundColor Yellow
        
        # 快速检查连接 (Head 请求)，超时设为 3 秒以加快切换速度
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 3
        
        if ($response.StatusCode -eq 200) {
            Write-Host "[+] 连接成功，正在下载..." -ForegroundColor Green
            
            # 执行实际下载
            Invoke-WebRequest -Uri $Url -OutFile $TempFile -UseBasicParsing
            
            if (Test-Path $TempFile) {
                Write-Host "[+] 下载完成: $TempFile" -ForegroundColor Green
                $DownloadSuccess = $true
                break # 下载成功，跳出循环，不再尝试后续地址
            } else {
                throw "文件写入失败"
            }
        }
    } catch {
        $LastErrorMessage = $_.Exception.Message
        Write-Host "[-] 失败: $Url" -ForegroundColor Red
        # Write-Host "    错误详情: $LastErrorMessage" -ForegroundColor Gray # 可选：显示详细错误
        Write-Host "    正在尝试下一个地址..." -ForegroundColor Gray
        continue # 继续循环，尝试下一个 URL
    }
}

# 如果所有地址都失败，则退出
if (-not $DownloadSuccess) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "[-] 错误: 所有服务器地址均连接失败。" -ForegroundColor Red
    Write-Host "    请检查网络或更新脚本中的备用地址列表。" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Red
    pause
    exit 1
}

# ==========================================
# 5. 检查管理员权限并提升
# ==========================================
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[!] 当前非管理员权限，正在请求提升..." -ForegroundColor Magenta
    Write-Host "    如果弹出 UAC 窗口，请点击【是】" -ForegroundColor Gray
    

    
    Write-Host "[*] 已启动新窗口，当前窗口将在 3 秒后关闭..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit 0
} else {
    # 已经是管理员，直接运行
    Write-Host "[*] 当前已是管理员权限，正在启动 MAS..." -ForegroundColor Green
    
    # 启动 CMD 执行下载的脚本，并等待其结束
    Start-Process cmd.exe -ArgumentList "/c", "`"$TempFile`"" -Wait
    
    Write-Host "[*] MAS 执行完毕." -ForegroundColor Green
    
    # 可选：清理临时文件
    # Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
    exit
}
