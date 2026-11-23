<#
.SYNOPSIS
  WPF 프로젝트의 XAML, code-behind, .resx에서 AI 티 후보를 정적으로 찾는다.

.DESCRIPTION
  references/signs.md에서 [자동] 표시가 붙은 항목 일부를 찾는다.
  결과는 audit의 출발점일 뿐이다. 찾지 못하는 항목이 있고, 찾은 항목도 맥락을 보고 판단해야 한다.
  파일을 수정하지 않는다.

  wpf-unslop의 일부. wpf-unslop은 unslop(Damir Sokolovsky, CC BY 4.0)의 비공식 WPF 변형이다.
  이 스크립트는 wpf-unslop에서 새로 작성했으며 MIT 라이선스를 따른다 (같은 폴더의 LICENSE).
  Copyright (c) 2026 Sihyun Lee

.PARAMETER Path
  점검할 폴더 또는 파일. 기본값은 현재 폴더.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File audit-xaml.ps1 -Path .\src\MyApp
#>
[CmdletBinding()]
param(
    [string]$Path = '.'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Xml.Linq, PresentationCore, WindowsBase, System.Drawing

$root = (Resolve-Path $Path).Path
$excludeDir = '\\(bin|obj|\.git|\.vs|node_modules|packages)\\'

if (Test-Path $root -PathType Leaf) {
    $files = @(Get-Item $root)
    $base = Split-Path $root -Parent
} else {
    $files = @(Get-ChildItem -Path $root -Recurse -File -Include *.xaml, *.cs, *.resx |
        Where-Object { $_.FullName -notmatch $excludeDir -and $_.Name -notmatch '\.g(\.i)?\.cs$|\.Designer\.cs$' })
    $base = $root
}

$findings = New-Object System.Collections.Generic.List[object]
function Add-Finding([string]$cat, [string]$file, [int]$line, [string]$detail) {
    $rel = $file.Substring($base.Length).TrimStart('\')
    $findings.Add([pscustomobject]@{ Cat = $cat; File = $rel; Line = $line; Detail = $detail })
}

# 이모지와 장식 기호. Segoe 아이콘 글꼴의 사설 영역(E000-F8FF)은 제외된다.
$emojiRx = '[\uD83C-\uD83E][\uDC00-\uDFFF]|[\u2600-\u27BF\u2B50\u2B55\u2B06\u2B07\u2934\u2935\u203C\u2049]'
$textAttrs = @('Text', 'Content', 'Header', 'Title', 'ToolTip', 'Description', 'Watermark', 'PlaceholderText')
$brushAttrs = @('Background', 'Foreground', 'BorderBrush', 'Fill', 'Stroke', 'Color', 'CaretBrush', 'SelectionBrush', 'OpacityMask')
$spacingAttrs = @('Margin', 'Padding', 'Width', 'Height', 'MinWidth', 'MinHeight')
$shapeNames = @('Ellipse', 'Rectangle', 'Polygon', 'Polyline', 'Path', 'Line')
$heavyWeights = @('Bold', 'ExtraBold', 'UltraBold', 'Black', 'Heavy', 'ExtraBlack', 'UltraBlack')

function Get-ColorInfo([string]$value) {
    # 색 문자열을 해석해 채도와 밝기를 돌려준다. 해석할 수 없으면 $null.
    try {
        $c = [System.Windows.Media.ColorConverter]::ConvertFromString($value)
        if ($null -eq $c) { return $null }
        $d = [System.Drawing.Color]::FromArgb($c.A, $c.R, $c.G, $c.B)
        return [pscustomobject]@{ Sat = $d.GetSaturation(); Lum = $d.GetBrightness(); Hue = $d.GetHue(); A = $c.A }
    } catch { return $null }
}
function Test-Chromatic($info) {
    return ($null -ne $info -and $info.A -gt 40 -and $info.Sat -gt 0.25 -and $info.Lum -gt 0.12 -and $info.Lum -lt 0.92)
}
function Test-OffGrid([double]$v) {
    $a = [Math]::Abs($v)
    if ($a -le 1) { return $false }                 # 0, 1(hairline)
    if ($a -ne [Math]::Floor($a)) { return $true }   # 소수
    if ($a % 4 -eq 0) { return $false }
    if ($a % 2 -eq 0 -and $a -le 20) { return $false } # 작은 짝수는 미세 조정과 아이콘 크기로 허용
    return $true
}
function Test-Literal([string]$v) { return -not ($v.StartsWith('{')) }

foreach ($f in $files) {
    $ext = $f.Extension.ToLowerInvariant()

    if ($ext -eq '.cs') {
        $n = 0
        foreach ($line in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::UTF8)) {
            $n++
            $t = $line.Trim()
            if ($t.StartsWith('//')) { continue }
            if ($line -match $emojiRx) { Add-Finding 'EMOJI' $f.FullName $n $t }
            # code-behind에서 만든 UI: 여백, 글자 크기, 굵기
            foreach ($m in [regex]::Matches($line, 'new\s+Thickness\(([^)]*)\)')) {
                $args0 = $m.Groups[1].Value -split '\s*,\s*'
                if (@($args0 | Where-Object { $_ -notmatch '^-?\d+(\.\d+)?$' }).Count -gt 0) { continue }
                if (@($args0 | Where-Object { Test-OffGrid ([double]$_) }).Count -gt 0) { Add-Finding 'OFF_GRID_CS' $f.FullName $n $m.Value }
            }
            foreach ($m in [regex]::Matches($line, '\bFontSize\s*=\s*(\d+(\.\d+)?)\b')) {
                $v = [double]$m.Groups[1].Value
                if ($v -lt 12 -or $v -ne [Math]::Floor($v)) { Add-Finding 'SMALL_TEXT' $f.FullName $n "FontSize = $v" }
            }
            if ($line -cmatch 'FontWeights\.(Bold|ExtraBold|UltraBold|Black|Heavy|ExtraBlack|UltraBlack)\b') {
                Add-Finding 'HEAVY_WEIGHT' $f.FullName $n $t
            }
            if ($line -cmatch 'Color\.FromA?Rgb\s*\(|new\s+SolidColorBrush\s*\(\s*Color|Brushes\.(?!Transparent\b)\w+|ColorConverter\.ConvertFromString\s*\(\s*"#') {
                Add-Finding 'HARDCODED_COLOR_CS' $f.FullName $n $t
            }
        }
        continue
    }

    try {
        $doc = [System.Xml.Linq.XDocument]::Load($f.FullName, [System.Xml.Linq.LoadOptions]::SetLineInfo)
    } catch {
        Add-Finding 'PARSE_ERROR' $f.FullName 0 $_.Exception.Message
        continue
    }

    if ($ext -eq '.resx') {
        foreach ($v in $doc.Descendants('value')) {
            $s = $v.Value
            $ln = ([System.Xml.IXmlLineInfo]$v).LineNumber
            if ($s -match $emojiRx) { Add-Finding 'EMOJI' $f.FullName $ln $s }
            if ($s -match '!') { Add-Finding 'EXCLAMATION' $f.FullName $ln $s }
        }
        continue
    }

    # ----- XAML -----
    $rootName = $doc.Root.Name.LocalName
    if ($rootName -eq 'Window') {
        $ul = $doc.Root.Attribute('UseLayoutRounding')
        if ($null -eq $ul -or $ul.Value -ne 'True') {
            Add-Finding 'NO_LAYOUT_ROUNDING' $f.FullName (([System.Xml.IXmlLineInfo]$doc.Root).LineNumber) 'Window에 UseLayoutRounding="True"가 없음'
        }
    }

    foreach ($el in $doc.Descendants()) {
        $name = $el.Name.LocalName
        $ln = ([System.Xml.IXmlLineInfo]$el).LineNumber
        $hasKey = $null -ne ($el.Attributes() | Where-Object { $_.Name.LocalName -eq 'Key' })
        $attr = @{}
        foreach ($a in $el.Attributes()) { $attr[$a.Name.LocalName] = $a.Value }

        # Canvas 안의 도형은 일러스트로 보고 색·좌표·크기 점검에서 뺀다. Canvas마다 한 줄만 남긴다.
        if ($name -eq 'Canvas') {
            $shapes = @($el.Descendants() | Where-Object { $_.Name.LocalName -in $shapeNames })
            if ($shapes.Count -ge 3) { Add-Finding 'ILLUSTRATION' $f.FullName $ln "Canvas 안 도형 $($shapes.Count)개 (일러스트면 내용으로 보고 유지, 색만 세계와 맞는지 확인)" }
        }
        $inCanvas = $null -ne ($el.Ancestors() | Where-Object { $_.Name.LocalName -eq 'Canvas' } | Select-Object -First 1)
        if ($inCanvas -and $shapeNames -contains $name) { continue }

        # 그라데이션
        if ($name -eq 'LinearGradientBrush' -or $name -eq 'RadialGradientBrush') {
            $stops = @($el.Descendants() | Where-Object { $_.Name.LocalName -eq 'GradientStop' } |
                ForEach-Object { $_.Attribute('Color') } | Where-Object { $_ } | ForEach-Object { $_.Value })
            $chroma = @($stops | Where-Object { Test-Chromatic (Get-ColorInfo $_) })
            if ($chroma.Count -gt 0) {
                Add-Finding 'HUE_GRADIENT' $f.FullName $ln ("$name : " + ($stops -join ' → '))
            } elseif ($name -eq 'RadialGradientBrush') {
                Add-Finding 'RADIAL_WASH' $f.FullName $ln ("$name : " + ($stops -join ' → ') + ' (번진 색 덩어리인지 확인)')
            } else {
                Add-Finding 'NEUTRAL_GRADIENT' $f.FullName $ln ("$name : " + ($stops -join ' → ') + ' (무채색 톤 변화면 허용)')
            }
        }

        # 효과
        if ($name -eq 'DropShadowEffect') {
            $depth = $attr['ShadowDepth']; $col = $attr['Color']
            $isGlow = ($depth -eq '0') -or (Test-Chromatic (Get-ColorInfo $col))
            if ($isGlow) { Add-Finding 'GLOW' $f.FullName $ln "DropShadowEffect Color=$col ShadowDepth=$depth BlurRadius=$($attr['BlurRadius'])" }
            else { Add-Finding 'SHADOW' $f.FullName $ln "DropShadowEffect Color=$col ShadowDepth=$depth BlurRadius=$($attr['BlurRadius']) (어두운 테마면 표면 단계로 교체)" }
        }
        if ($name -eq 'BlurEffect') { Add-Finding 'BLUR' $f.FullName $ln "BlurEffect Radius=$($attr['Radius'])" }
        if ($name.EndsWith('.Effect')) {
            $owner = $el.Parent
            $texty = @($owner.Descendants() | Where-Object { $_.Name.LocalName -in @('TextBlock', 'TextBox', 'Label', 'ContentPresenter', 'Run') })
            if ($texty.Count -gt 0) { Add-Finding 'EFFECT_ON_TEXT' $f.FullName $ln "$($owner.Name.LocalName)에 Effect가 걸려 있고 안에 텍스트가 있음 (텍스트가 흐려짐)" }
        }

        # 움직임
        if ($name -in @('BackEase', 'ElasticEase', 'BounceEase')) { Add-Finding 'BOUNCY_EASE' $f.FullName $ln $name }
        if ($attr['RepeatBehavior'] -eq 'Forever') { Add-Finding 'INFINITE_ANIMATION' $f.FullName $ln "$name RepeatBehavior=Forever (실시간 상태 표시가 아니면 제거)" }
        $tp = $attr['Storyboard.TargetProperty']
        if ($tp -and $tp -match '(^|\W)(Width|Height|Margin|Canvas\.Left|Canvas\.Top|LayoutTransform)(\W|$)') {
            Add-Finding 'LAYOUT_ANIMATION' $f.FullName $ln "$name TargetProperty=$tp"
        }

        # 창
        if ($name -eq 'Window' -and $attr['AllowsTransparency'] -eq 'True') { Add-Finding 'ALLOWS_TRANSPARENCY' $f.FullName $ln '투명 창이 꼭 필요한지 확인 (WindowChrome 검토)' }

        # 글꼴
        if ($attr.ContainsKey('FontWeight') -and $heavyWeights -contains $attr['FontWeight']) {
            Add-Finding 'HEAVY_WEIGHT' $f.FullName $ln "$name FontWeight=$($attr['FontWeight'])"
        }
        if ($attr.ContainsKey('FontSize') -and $attr['FontSize'] -match '^\d+(\.\d+)?$') {
            $fs = [double]$attr['FontSize']
            if ($fs -lt 12 -or $fs -ne [Math]::Floor($fs)) { Add-Finding 'SMALL_TEXT' $f.FullName $ln "$name FontSize=$fs" }
        }
        if ($attr['FontStyle'] -in @('Italic', 'Oblique')) { Add-Finding 'ITALIC' $f.FullName $ln "$name FontStyle=$($attr['FontStyle'])" }

        # 직접 적은 색 (x:Key가 있는 토큰 정의는 제외)
        if (-not $hasKey) {
            foreach ($b in $brushAttrs) {
                if (-not $attr.ContainsKey($b)) { continue }
                $v = $attr[$b]
                if (-not (Test-Literal $v) -or $v -eq 'Transparent' -or $v -eq '{x:Null}') { continue }
                if ($name -eq 'GradientStop') { continue }
                if ($v -match '^#' -or $v -match '^[A-Za-z]+$') {
                    Add-Finding 'HARDCODED_COLOR' $f.FullName $ln "$name $b=$v"
                }
            }
        }

        # 여백과 크기
        foreach ($s in $spacingAttrs) {
            if (-not $attr.ContainsKey($s)) { continue }
            $v = $attr[$s]
            if (-not (Test-Literal $v)) { continue }
            $nums = @($v -split '[,\s]+' | Where-Object { $_ -match '^-?\d+(\.\d+)?$' } | ForEach-Object { [double]$_ })
            $bad = @($nums | Where-Object { Test-OffGrid $_ })
            if ($bad.Count -gt 0) { Add-Finding 'OFF_GRID' $f.FullName $ln "$name $s=`"$v`"" }
        }

        # 디자이너 드래그 흔적
        if ($attr['HorizontalAlignment'] -eq 'Left' -and $attr['VerticalAlignment'] -eq 'Top' -and $attr.ContainsKey('Margin') -and (Test-Literal $attr['Margin'])) {
            $m = @($attr['Margin'] -split '[,\s]+' | Where-Object { $_ -match '^-?\d+(\.\d+)?$' } | ForEach-Object { [double]$_ })
            if ($m.Count -ge 2 -and ($m[0] -ge 24 -or $m[1] -ge 24)) {
                Add-Finding 'ABSOLUTE_LAYOUT' $f.FullName $ln "$name Margin=`"$($attr['Margin'])`" (디자이너 드래그 배치)"
            }
        }
        if ($attr.ContainsKey('Canvas.Left') -or $attr.ContainsKey('Canvas.Top')) {
            Add-Finding 'CANVAS_POSITION' $f.FullName $ln "$name Canvas 좌표 배치 (일반 레이아웃이면 Grid로)"
        }

        # 문구
        $texts = New-Object System.Collections.Generic.List[string]
        foreach ($t in $textAttrs) { if ($attr.ContainsKey($t) -and (Test-Literal $attr[$t])) { $texts.Add($attr[$t]) } }
        foreach ($node in $el.Nodes()) { if ($node -is [System.Xml.Linq.XText]) { $s = $node.Value.Trim(); if ($s) { $texts.Add($s) } } }
        # 토큰 정의(Color, FontFamily, Geometry 등 키가 있는 요소)의 내용은 문구가 아니다
        if ($hasKey -and $name -notin @('String')) { $texts.Clear() }
        foreach ($s in $texts) {
            if ($s -match $emojiRx) { Add-Finding 'EMOJI' $f.FullName $ln "$name `"$s`"" }
            if ($s -match '!') { Add-Finding 'EXCLAMATION' $f.FullName $ln "$name `"$s`"" }
            if ($s -cmatch '^[A-Z][A-Z0-9 &/\-]{3,}$' -and $s -cmatch '[A-Z]{2,}.*[A-Z]{2,}|[A-Z]{5,}') {
                Add-Finding 'UPPERCASE_LABEL' $f.FullName $ln "$name `"$s`""
            }
            if ($s -cmatch '^([A-Z] ){2,}[A-Z]') { Add-Finding 'FAKE_TRACKING' $f.FullName $ln "$name `"$s`"" }
        }
    }
}

# ----- 출력 -----
$order = @('HUE_GRADIENT', 'GLOW', 'RADIAL_WASH', 'BLUR', 'EFFECT_ON_TEXT', 'EMOJI', 'HARDCODED_COLOR', 'HARDCODED_COLOR_CS',
    'HEAVY_WEIGHT', 'SMALL_TEXT', 'UPPERCASE_LABEL', 'FAKE_TRACKING', 'ITALIC', 'EXCLAMATION', 'OFF_GRID', 'OFF_GRID_CS', 'ABSOLUTE_LAYOUT', 'CANVAS_POSITION',
    'INFINITE_ANIMATION', 'BOUNCY_EASE', 'LAYOUT_ANIMATION', 'SHADOW', 'NEUTRAL_GRADIENT', 'ILLUSTRATION', 'ALLOWS_TRANSPARENCY',
    'NO_LAYOUT_ROUNDING', 'PARSE_ERROR')

Write-Output "wpf-unslop audit: $base"
Write-Output "파일 $($files.Count)개, 후보 $($findings.Count)건"
Write-Output ''
Write-Output '== 요약 =='
foreach ($c in $order) {
    $cnt = @($findings | Where-Object { $_.Cat -eq $c }).Count
    if ($cnt -gt 0) { Write-Output ('{0,-20} {1,4}' -f $c, $cnt) }
}
foreach ($c in $order) {
    $items = @($findings | Where-Object { $_.Cat -eq $c })
    if ($items.Count -eq 0) { continue }
    Write-Output ''
    Write-Output "== $c =="
    foreach ($i in $items) { Write-Output ("{0}:{1}  {2}" -f $i.File, $i.Line, $i.Detail) }
}
