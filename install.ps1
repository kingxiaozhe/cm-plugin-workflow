# cm-plugin 工作流一键安装（Windows PowerShell 版·浏览器扩展开发版）
# 用法: 在解压后的 cm-plugin-workflow 目录里执行  powershell -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = "Stop"

$Src  = $PSScriptRoot
$Dest = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE ".claude" }
$Version = if (Test-Path "$Src\VERSION") { (Get-Content "$Src\VERSION" -Raw).Trim() } else { "未知" }

Write-Host "cm-plugin 工作流安装  v$Version"
Write-Host "  来源: $Src"
Write-Host "  目标: $Dest`n"

# 核心三件套（纯 Markdown,Windows 原生可用）
foreach ($part in "commands", "skills", "agents") {
    $s = Join-Path $Src $part
    if (-not (Test-Path $s)) { Write-Host "跳过 $part（源目录不存在）"; continue }
    $d = Join-Path $Dest $part
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Copy-Item "$s\*" $d -Recurse -Force
    $n = (Get-ChildItem $s -Recurse -File).Count
    Write-Host "√ $part 已安装（$n 个文件）"
}

# 模板层
$tpl = Join-Path $Dest "templates"
New-Item -ItemType Directory -Force -Path $tpl | Out-Null
if (Test-Path "$Src\templates\rules") {
    New-Item -ItemType Directory -Force -Path "$tpl\cm-plugin-rules" | Out-Null
    Copy-Item "$Src\templates\rules\*" "$tpl\cm-plugin-rules" -Recurse -Force
    Write-Host "√ rules 模板已安装"
}
if (Test-Path "$Src\templates\arch-reference.md") {
    Copy-Item "$Src\templates\arch-reference.md" "$tpl\cm-plugin-arch-reference.md" -Force
    Write-Host "√ 架构基准参考表已安装"
}
foreach ($pair in @(@("dashboard", "cm-plugin-dashboard"), @("pixel", "cm-plugin-pixel"))) {
    $s = Join-Path $Src "templates\$($pair[0])"
    if (Test-Path $s) {
        New-Item -ItemType Directory -Force -Path "$tpl\$($pair[1])" | Out-Null
        Copy-Item "$s\*" "$tpl\$($pair[1])" -Recurse -Force
        Remove-Item "$tpl\$($pair[1])\dev" -Recurse -Force -ErrorAction SilentlyContinue  # 构建工具不装进用户机器
        Write-Host "√ $($pair[1]) 已安装"
    }
}
if (Test-Path "$Src\templates\statusline\cm-plugin-statusline.sh") {
    Copy-Item "$Src\templates\statusline\cm-plugin-statusline.sh" "$tpl\cm-plugin-statusline.sh" -Force
    Write-Host "√ 状态条脚本已安装"
}
Set-Content -Path "$tpl\cm-plugin-VERSION" -Value $Version

Write-Host "`n完成（已安装版本: v$Version）。建议在 Claude Code 中运行 /cm-plugin:check 校验。"
Write-Host @"

Windows 注意事项:
  · 核心工作流(commands/skills/agents)是纯 Markdown,Windows 原生可用,无额外依赖
  · 状态条 / 终端像素版 / 看板与像素 serve.sh 是 bash+python3 脚本:
      - 推荐在 WSL 或 Git Bash 中使用(Claude Code 终端选 Git Bash 即可)
      - 浏览器像素版页面本身(cm-pixel.html)双击即可打开看 ?demo,只有实时跟踪需要 serve.sh
"@
