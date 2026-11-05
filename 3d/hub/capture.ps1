# Pictures of the Roblox window, for marks just drawn in it. Moves nothing, focuses nothing.
# Stays running (the hub starts it once, on the first mark, since starting PowerShell takes seconds):
# reads one output path per line on stdin, and answers each with one line of JSON. Ends with its stdin.
param(
  [string]$Out,
  [string[]]$Names = @("RobloxStudioBeta", "RobloxPlayerBeta")
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class Ds3dWindow {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[void][Ds3dWindow]::SetProcessDPIAware()

function Take-Picture([string]$path) {
  try {
    $window = $null
    foreach ($name in $Names) {
      foreach ($process in (Get-Process -Name $name -ErrorAction SilentlyContinue)) {
        if ($process.MainWindowHandle -ne [IntPtr]::Zero) { $window = $process; break }
      }
      if ($window) { break }
    }
    if (-not $window) { return @{ ok = $false; reason = "no-window" } }

    $handle = $window.MainWindowHandle
    if ([Ds3dWindow]::IsIconic($handle)) { return @{ ok = $false; reason = "minimized" } }
    $rect = New-Object Ds3dWindow+RECT
    [void][Ds3dWindow]::GetWindowRect($handle, [ref]$rect)
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) { return @{ ok = $false; reason = "no-size" } }

    $foreground = [Ds3dWindow]::GetForegroundWindow() -eq $handle
    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    if ($foreground) {
      # In front: exactly what the person sees.
      $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size $width, $height))
    } else {
      # Behind something: ask the window to draw itself, so nothing else on the screen is in the picture.
      $hdc = $graphics.GetHdc()
      [void][Ds3dWindow]::PrintWindow($handle, $hdc, 2)
      $graphics.ReleaseHdc($hdc)
    }
    $graphics.Dispose()

    # Scaled to what is worth reading, as JPEG.
    $scale = [Math]::Min(1.0, 1920.0 / $width)
    $outW = [int]($width * $scale)
    $outH = [int]($height * $scale)
    $scaled = New-Object System.Drawing.Bitmap $outW, $outH
    $g2 = [System.Drawing.Graphics]::FromImage($scaled)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($bitmap, 0, 0, $outW, $outH)
    $g2.Dispose()
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
    $parameters = New-Object System.Drawing.Imaging.EncoderParameters 1
    $parameters.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]90)
    $scaled.Save($path, $codec, $parameters)
    $scaled.Dispose()
    $bitmap.Dispose()
    return @{ ok = $true; width = $outW; height = $outH; foreground = $foreground; process = $window.ProcessName }
  } catch {
    return @{ ok = $false; reason = "error"; detail = "$_" }
  }
}

function Answer($object) {
  [Console]::Out.WriteLine(($object | ConvertTo-Json -Compress))
  [Console]::Out.Flush()
}

# One picture, when asked on the command line.
if ($Out) { Answer (Take-Picture $Out); exit 0 }

Answer @{ ready = $true }
while ($true) {
  $line = [Console]::In.ReadLine()
  if ($null -eq $line) { break }
  $path = $line.Trim()
  if ($path) { Answer (Take-Picture $path) }
}
