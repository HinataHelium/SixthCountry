# 设定库自检脚本
# 用法： pwsh -File tools/check.ps1
# 检查：禁用写法、〔D-xx〕与 A-xx 引用是否落地、内部链接是否有效、编号是否唯一。

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root 'docs'
$enc  = [System.Text.Encoding]::UTF8

# 这些文件是"叙述性正典"，不得出现任何禁用写法
$narrative = @(
  '01-世界与地理.md','02-编年史.md','03-纪年与历法.md','04-政体与权力结构.md',
  '05-军事.md','06-绩效制度与法律.md','07-社会、日常与语言.md','08-受祭与意识形态.md',
  '09-经济、财阀与对外关系.md','10-人物志.md','12-文献库.md','13-话语样本与文体.md','14-叙事工程.md'
)
# 11 号是禁用写法的登记处，00 与 99 会引用旧写法作为史料，故不参与该项检查
$banned = @('康慨','康.慨','康凯','郑军','郑钧','第六帝国','玛体克','新民社会','广播电视总台','核战指挥所','南水北调')

$problems = New-Object System.Collections.Generic.List[string]

# 1. 禁用写法
foreach($name in $narrative){
  $p = Join-Path $docs $name
  if(-not (Test-Path $p)){ $problems.Add("缺文件：docs/$name"); continue }
  $lines = Get-Content -LiteralPath $p -Encoding UTF8
  for($i=0; $i -lt $lines.Count; $i++){
    if($lines[$i].Contains('<!--check:ok-->')){ continue }   # 改写清单/史料引用行可豁免
    foreach($b in $banned){
      if($lines[$i].Contains($b)){ $problems.Add("${name}:$($i+1) 禁用写法 [$b]：$($lines[$i].Trim())") }
    }
  }
}

# 2. 〔D-xx〕必须在 99 里有对应条目；〔A-xx〕必须在 decisions/ 里有文件
$all = Get-ChildItem -Recurse -File $root -Include *.md | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\sources\\' }
$dText = Get-Content -LiteralPath (Join-Path $docs '99-待决议题.md') -Raw -Encoding UTF8
$dIds  = [regex]::Matches($dText,'###\s+(D-\d{2})') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$aIds  = Get-ChildItem (Join-Path $root 'decisions') -Filter 'A-*.md' | ForEach-Object { ($_.Name -split '-')[0..1] -join '-' }

foreach($f in $all){
  $t = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
  foreach($m in [regex]::Matches($t,'〔(D-\d{2})〕')){
    if($dIds -notcontains $m.Groups[1].Value){ $problems.Add("$($f.Name) 引用了不存在的 $($m.Groups[1].Value)") }
  }
  foreach($m in [regex]::Matches($t,'\b(A-\d{2})\b')){
    $id = $m.Groups[1].Value
    if($aIds -notcontains $id){ $problems.Add("$($f.Name) 引用了不存在的裁定 $id") }
  }
}

# 3. 内部链接
foreach($f in $all){
  $t = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
  foreach($m in [regex]::Matches($t,'\]\(([^)#\s]+\.md)(?:#[^)]*)?\)')){
    $target = $m.Groups[1].Value
    if($target -match '^https?:'){ continue }
    $resolved = Join-Path $f.DirectoryName $target
    if(-not (Test-Path $resolved)){ $problems.Add("$($f.Name) 死链：$target") }
  }
}

# 4. 11 号专名表的编号唯一性
$t11 = Get-Content -LiteralPath (Join-Path $docs '11-专名表.md') -Encoding UTF8
$ids = @{}
for($i=0; $i -lt $t11.Count; $i++){
  $m = [regex]::Match($t11[$i],'^\|\s*([A-Z]-\d{2}a?)\s*\|')
  if($m.Success){
    $id = $m.Groups[1].Value
    if($ids.ContainsKey($id)){ $problems.Add("11-专名表 编号重复：$id（行 $($ids[$id]) 与 $($i+1)）") }
    else{ $ids[$id] = $i+1 }
  }
}

# 4.5 换行符统一 LF
Get-ChildItem -Recurse -File $root | Where-Object { $_.FullName -notmatch '\\\.git\\' } | ForEach-Object {
  $b=[System.IO.File]::ReadAllBytes($_.FullName)
  if($b -contains 13){ $problems.Add("$($_.Name) 含 CRLF，需转为 LF") }
}
# 5. 关键数字一致性（人工约定的硬数）
$hard = @{
  '02-编年史.md'   = @('四十六年');
  '03-纪年与历法.md' = @('四十六年','GE 二年','GE 十八年');
}
foreach($k in $hard.Keys){
  $t = Get-Content -LiteralPath (Join-Path $docs $k) -Raw -Encoding UTF8
  foreach($s in $hard[$k]){ if(-not $t.Contains($s)){ $problems.Add("$k 未出现硬约定：$s") } }
}

# 输出
if($problems.Count -eq 0){
  Write-Output "✅ 全部通过（$($all.Count) 份文件）"
  exit 0
}
Write-Output "❌ 发现 $($problems.Count) 个问题："
$problems | ForEach-Object { "  - $_" }
exit 1
