# 合成《第六国兴衰录》全本
# 用法： pwsh -File tools/build-book.ps1
# 输出： build/第六国兴衰录-全本.md （按《总目录》次第拼接，卷九留白页）

$ErrorActionPreference='Stop'
$root = Split-Path -Parent $PSScriptRoot
$enc  = New-Object System.Text.UTF8Encoding($false)
$outDir = Join-Path $root 'build'

$order = @(
  @{f='novel/00-卷首/01-再版说明.md'; h='副扉'},
  @{f='novel/00-卷首/02-严正声明.md'; h='副扉'},
  @{f='novel/00-卷首/03-总目录.md';   h='副扉'},
  @{f='novel/01-编年史/卷一-四十六年.md'; h='卷'},
  @{f='novel/01-编年史/卷二-空力十八年.md'; h='卷'},
  @{f='novel/01-编年史/卷三-慷慨十三年.md'; h='卷'},
  @{f='novel/01-编年史/卷四-后纪.md'; h='卷'},
  @{f='novel/01-编年史/卷四附-分裂纪年.md'; h='附录'},
  @{f='novel/01-编年史/卷五-文献辑存.md'; h='卷'},
  @{f='novel/04-卷末/卷六-人物表.md'; h='卷'},
  @{f='novel/04-卷末/卷七-年表.md'; h='卷'},
  @{f='novel/04-卷末/卷八-索引.md'; h='卷'},
  @{f='novel/00-卷首/04-卷九存目.md'; h='卷'},
  @{f='novel/04-卷末/卷十-校勘记.md'; h='卷'}
)

$sb = New-Object System.Text.StringBuilder
function Add($s){ [void]$sb.Append($s) }

Add "《第六国兴衰录》`n`n"
Add "新民社出版局　编`n`n"
Add "修订版　全十卷`n`n"
Add "光荣纪元三十八年三月`n`n"
Add "---`n`n"

$missing=@(); $stats=@()
foreach($e in $order){
  $path = Join-Path $root $e.f
  if(-not (Test-Path $path)){ $missing += $e.f; continue }
  $t = [System.IO.File]::ReadAllText($path)
  $t = $t.TrimEnd() + "`n"
  $han = ([regex]::Matches($t,'[\u4e00-\u9fff]')).Count
  $stats += [pscustomobject]@{ file=$e.f; han=$han }
  Add $t
  Add "`n---`n`n"
}

Add "（全书终）`n"

if($missing.Count -gt 0){ Write-Output "缺文件："; $missing | ForEach-Object { "  - $_" }; exit 1 }

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir '第六国兴衰录-全本.md'
[System.IO.File]::WriteAllText($outFile, $sb.ToString(), $enc)

$total = ($stats | Measure-Object -Property han -Sum).Sum
Write-Output "已合成：build/第六国兴衰录-全本.md"
Write-Output ("共 {0} 个部分，{1} 汉字" -f $stats.Count, $total)
$stats | ForEach-Object { "  {0,6}  {1}" -f $_.han, $_.file }
