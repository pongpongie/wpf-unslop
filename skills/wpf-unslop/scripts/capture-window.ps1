<#
.SYNOPSIS
  실행 중인 앱의 창을 포커스를 건드리지 않고 PNG로 캡처한다.

.DESCRIPTION
  PrintWindow + PW_RENDERFULLCONTENT로 창 내용을 그려 받는다.
  창을 앞으로 가져오거나 활성화하지 않고, 마우스·키보드 입력도 보내지 않는다.
  다른 창에 가려진 창도 캡처된다. 최소화된 창은 WPF가 그리지 않으므로 건너뛴다.

  wpf-unslop의 일부. wpf-unslop은 unslop(Damir Sokolovsky, CC BY 4.0)의 비공식 WPF 변형이다.
  이 스크립트는 wpf-unslop에서 새로 작성했으며 MIT 라이선스를 따른다 (같은 폴더의 LICENSE).
  Copyright (c) 2026 Sihyun Lee

.PARAMETER ProcessName
  프로세스 이름(확장자 제외). 예: Catcretary

.PARAMETER ProcessId
  프로세스 ID. ProcessName 대신 쓴다.

.PARAMETER Title
  창 제목에 포함된 문자열로 거른다. 생략하면 그 프로세스의 보이는 최상위 창을 모두 캡처한다.

.PARAMETER OutDir
  PNG를 저장할 폴더. 없으면 만든다.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File capture-window.ps1 -ProcessName Catcretary -OutDir .\unslop-captures\before
#>
[CmdletBinding()]
param(
    [string]$ProcessName,
    [int]$ProcessId = 0,
    [string]$Title,
    [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'

if (-not $ProcessName -and $ProcessId -eq 0) {
    throw 'ProcessName 또는 ProcessId 중 하나를 지정해야 합니다.'
}

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class UnslopCapture
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, int attr, out RECT rect, int size);

    public static void MakeDpiAware()
    {
        // 화면 배율이 100%가 아닐 때 실제 픽셀 크기로 캡처하기 위해 필요하다.
        try { if (SetProcessDpiAwarenessContext(new IntPtr(-4))) return; } catch { }
        try { SetProcessDPIAware(); } catch { }
    }

    public static List<IntPtr> TopWindows(uint pid)
    {
        var list = new List<IntPtr>();
        EnumWindows(delegate (IntPtr h, IntPtr l)
        {
            uint p;
            GetWindowThreadProcessId(h, out p);
            // 보이는 최상위 창은 소유 창(대화상자, 팝업 창)까지 모두 포함한다.
            if (p == pid && IsWindowVisible(h)) list.Add(h);
            return true;
        }, IntPtr.Zero);
        return list;
    }

    public static string TitleOf(IntPtr h)
    {
        var sb = new StringBuilder(512);
        GetWindowText(h, sb, sb.Capacity);
        return sb.ToString();
    }

    public static RECT BoundsOf(IntPtr h)
    {
        RECT r;
        // DWMWA_EXTENDED_FRAME_BOUNDS(9): 그림자 여백을 뺀 실제 창 영역
        if (DwmGetWindowAttribute(h, 9, out r, Marshal.SizeOf(typeof(RECT))) != 0) GetWindowRect(h, out r);
        return r;
    }
}
'@

[UnslopCapture]::MakeDpiAware()

if ($ProcessId -ne 0) {
    $procs = @(Get-Process -Id $ProcessId)
} else {
    $procs = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
}
if ($procs.Count -eq 0) {
    Write-Output "NOT_RUNNING: 실행 중인 프로세스가 없습니다. 앱을 새로 실행하려면 먼저 사용자 허락을 받아야 합니다."
    exit 2
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$saved = 0

foreach ($proc in $procs) {
    foreach ($h in [UnslopCapture]::TopWindows([uint32]$proc.Id)) {
        $t = [UnslopCapture]::TitleOf($h)
        if ($Title -and ($t -notlike "*$Title*")) { continue }
        if ([UnslopCapture]::IsIconic($h)) {
            Write-Output "SKIP_MINIMIZED: 0x$($h.ToString('X')) '$t' (최소화된 창은 그려지지 않습니다)"
            continue
        }

        # PrintWindow는 GetWindowRect 기준으로 그리므로 비트맵도 그 크기로 만든다.
        $wr = New-Object UnslopCapture+RECT
        [void][UnslopCapture]::GetWindowRect($h, [ref]$wr)
        $w = $wr.Right - $wr.Left; $hgt = $wr.Bottom - $wr.Top
        if ($w -le 1 -or $hgt -le 1) { continue }

        $bmp = New-Object System.Drawing.Bitmap $w, $hgt, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $hdc = $g.GetHdc()
        # PW_RENDERFULLCONTENT(2): DirectX/WPF 내용까지 그린다
        $ok = [UnslopCapture]::PrintWindow($h, $hdc, 2)
        $g.ReleaseHdc($hdc); $g.Dispose()
        if (-not $ok) { $bmp.Dispose(); Write-Output "FAIL: 0x$($h.ToString('X')) '$t'"; continue }

        # 그림자 여백을 잘라 실제 창 영역만 남긴다.
        $fb = [UnslopCapture]::BoundsOf($h)
        $cx = [Math]::Max(0, $fb.Left - $wr.Left); $cy = [Math]::Max(0, $fb.Top - $wr.Top)
        $cw = [Math]::Min($w - $cx, $fb.Right - $fb.Left); $ch = [Math]::Min($hgt - $cy, $fb.Bottom - $fb.Top)
        if ($cw -gt 1 -and $ch -gt 1 -and ($cw -ne $w -or $ch -ne $hgt)) {
            $crop = $bmp.Clone((New-Object System.Drawing.Rectangle $cx, $cy, $cw, $ch), $bmp.PixelFormat)
            $bmp.Dispose(); $bmp = $crop
        }

        $safe = ($t -replace '[\\/:*?"<>|]', '_')
        if ($safe.Length -gt 40) { $safe = $safe.Substring(0, 40) }
        if (-not $safe) { $safe = 'untitled' }
        $file = Join-Path $OutDir ("{0}_{1}_{2}.png" -f $proc.ProcessName, $h.ToString('X'), $safe)
        $size = "$($bmp.Width)x$($bmp.Height)"
        $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $saved++
        Write-Output "SAVED: $file ($size)"
    }
}

if ($saved -eq 0) { Write-Output 'NO_WINDOW: 조건에 맞는 보이는 창이 없습니다.'; exit 3 }
