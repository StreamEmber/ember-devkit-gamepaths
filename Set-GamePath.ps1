#Requires -Version 5.1
<#
.SYNOPSIS
    Oyun klasörünü bulur ve Windows kullanıcı ortam değişkenine yazar (GTAV_GAME_PATH / RDR2_GAME_PATH).

.DESCRIPTION
    StreamEmber projelerinin build.ps1 dosyaları bu değişkenleri okuyup derlenen modu doğrudan oyun klasörüne kopyalar.
    Çalışınca önce otomatik tespit mi, elle giriş mi istediğini sorar:
      Otomatik: Steam (kütüphaneler + appmanifest), Epic Games (launcher manifestleri), Rockstar Games Launcher
                (kayıt defteri), Windows'ta yüklü programlar ve yaygın klasörler taranır. Bulunan klasör için onay istenir.
      Elle:     klasör yolunu yazarsın; içinde oyunun exe'si (GTA5.exe / RDR2.exe) olmalıdır.
    Değer kullanıcı ortam değişkenine yazılır (yönetici izni gerekmez). Yeni açılan terminal, Visual Studio ve
    Rider pencerelerinde geçerli olur.

.EXAMPLE
    .\Set-GamePath.ps1 -Game GTAV
.EXAMPLE
    .\Set-GamePath.ps1 -Game RDR2 -ListOnly    # yalnız bulunan klasörleri listeler, hiçbir şeyi değiştirmez
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('GTAV', 'RDR2')]
    [string]$Game,
    # Bulunan klasörleri yazdır ve çık (soru sormaz, değişken yazmaz)
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$Games = @{
    GTAV = @{
        Name = 'Grand Theft Auto V (Legacy)'; Env = 'GTAV_GAME_PATH'; Exe = 'GTA5.exe'; SteamId = '271590'
        Folders = @('Grand Theft Auto V', 'GTAV', 'GTA V', 'GTA5'); Rockstar = 'Grand Theft Auto V'; Uninstall = 'Grand Theft Auto V*'
    }
    RDR2 = @{
        Name = 'Red Dead Redemption 2'; Env = 'RDR2_GAME_PATH'; Exe = 'RDR2.exe'; SteamId = '1174180'
        Folders = @('Red Dead Redemption 2', 'RDR2'); Rockstar = 'Red Dead Redemption 2'; Uninstall = 'Red Dead Redemption 2*'
    }
}
$Info = $Games[$Game]

# --- Yardımcılar ----------------------------------------------------------------------------------------------------
function Test-GameDir([string]$Path) {
    if (-not $Path) { return $false }
    try { return Test-Path -LiteralPath (Join-Path $Path $Info.Exe) -PathType Leaf } catch { return $false }
}

function Get-FullPath([string]$Path) {
    if (-not $Path) { return $null }
    try { return (Resolve-Path -LiteralPath $Path.Trim().Trim('"')).ProviderPath.TrimEnd('\') } catch { return $null }
}

function Get-RegValue([string]$Key, [string]$Name) {
    try { return (Get-ItemProperty -LiteralPath $Key -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

function New-Candidate([string]$Source, [string]$Path) { [pscustomobject]@{ Source = $Source; Path = $Path } }

# --- Kaynaklar -------------------------------------------------------------------------------------------------------
function Find-Steam {
    $roots = @(
        (Get-RegValue 'HKCU:\Software\Valve\Steam' 'SteamPath'),
        (Get-RegValue 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' 'InstallPath'),
        (Get-RegValue 'HKLM:\SOFTWARE\Valve\Steam' 'InstallPath')
    ) | Where-Object { $_ }
    $libraries = New-Object System.Collections.Generic.List[string]
    foreach ($root in $roots) {
        $root = $root -replace '/', '\'
        $libraries.Add($root)
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $libraries.Add(($m.Groups[1].Value -replace '\\\\', '\'))
            }
        }
    }
    foreach ($library in ($libraries | Select-Object -Unique)) {
        $manifest = Join-Path $library "steamapps\appmanifest_$($Info.SteamId).acf"
        if (Test-Path -LiteralPath $manifest) {
            $m = [regex]::Match((Get-Content -LiteralPath $manifest -Raw), '"installdir"\s+"([^"]+)"')
            if ($m.Success) { New-Candidate 'Steam' (Join-Path $library "steamapps\common\$($m.Groups[1].Value)") }
        }
        foreach ($folder in $Info.Folders) { New-Candidate 'Steam' (Join-Path $library "steamapps\common\$folder") }
    }
}

function Find-Epic {
    $dir = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (-not (Test-Path -LiteralPath $dir)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $dir -Filter '*.item' -File -ErrorAction SilentlyContinue) {
        try { $item = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json } catch { continue }
        if ($item.InstallLocation) { New-Candidate 'Epic Games' $item.InstallLocation }
    }
}

function Find-Rockstar {
    foreach ($key in "HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\$($Info.Rockstar)", "HKLM:\SOFTWARE\Rockstar Games\$($Info.Rockstar)") {
        $path = Get-RegValue $key 'InstallFolder'
        if ($path) { New-Candidate 'Rockstar Games Launcher' $path }
    }
    $uninstallRoots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
                      'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($key in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue) {
            $p = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if ($p -and $p.DisplayName -like $Info.Uninstall -and $p.InstallLocation) { New-Candidate 'Windows yüklü programlar' $p.InstallLocation }
        }
    }
}

function Find-Common {
    $bases = 'Program Files\Rockstar Games', 'Program Files\Epic Games', 'Epic Games', 'EpicGames',
             'Program Files (x86)\Steam\steamapps\common', 'SteamLibrary\steamapps\common', 'Steam\steamapps\common', 'Games'
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -ne 'Fixed' -or -not $drive.IsReady) { continue }
        foreach ($base in $bases) {
            foreach ($folder in $Info.Folders) { New-Candidate 'Yaygın klasör' (Join-Path $drive.RootDirectory.FullName "$base\$folder") }
        }
    }
}

function Find-GameDirs {
    $seen = @{}
    foreach ($finder in 'Find-Steam', 'Find-Epic', 'Find-Rockstar', 'Find-Common') {
        $candidates = @()
        try { $candidates = @(& $finder) } catch { Write-Verbose "$finder : $($_.Exception.Message)" }
        foreach ($c in $candidates) {
            if (-not (Test-GameDir $c.Path)) { continue }
            $full = Get-FullPath $c.Path
            if (-not $full -or $seen.ContainsKey($full.ToLowerInvariant())) { continue }
            $seen[$full.ToLowerInvariant()] = $true
            New-Candidate $c.Source $full
        }
    }
}

# --- Sorular ---------------------------------------------------------------------------------------------------------
function Read-YesNo([string]$Question) {
    while ($true) {
        $a = ([string](Read-Host "$Question [E/H]")).Trim().ToLowerInvariant()
        if (@('e', 'evet', 'y', 'yes') -contains $a) { return $true }
        if (@('h', 'hayır', 'hayir', 'n', 'no') -contains $a) { return $false }
        Write-Host '  E (evet) ya da H (hayır) yazın.' -ForegroundColor Yellow
    }
}

function Read-ManualPath {
    while ($true) {
        $raw = [string](Read-Host "$($Info.Name) klasörünün yolunu yazın (içinde $($Info.Exe) olmalı; boş bırakırsanız iptal)")
        if (-not $raw.Trim()) { return $null }
        $full = Get-FullPath $raw
        if ($full -and (Test-GameDir $full)) { return $full }
        if ($full -and (Test-GameDir (Split-Path $full -Parent)) -and $full.EndsWith($Info.Exe, 'OrdinalIgnoreCase')) { return (Split-Path $full -Parent) }
        Write-Host "  Bu klasörde $($Info.Exe) bulunamadı: $raw" -ForegroundColor Yellow
    }
}

function Select-AutoPath {
    Write-Host 'Steam, Epic Games, Rockstar Games Launcher ve yaygın klasörler taranıyor...' -ForegroundColor Cyan
    $found = @(Find-GameDirs)
    if ($found.Count -eq 0) {
        Write-Host "  $($Info.Name) otomatik olarak bulunamadı." -ForegroundColor Yellow
        return $null
    }
    while ($true) {
        if ($found.Count -eq 1) {
            $pick = $found[0]
        } else {
            Write-Host "Birden fazla kurulum bulundu:"
            for ($i = 0; $i -lt $found.Count; $i++) { Write-Host ("  {0}) {1}  [{2}]" -f ($i + 1), $found[$i].Path, $found[$i].Source) }
            $answer = ([string](Read-Host "Numara seçin (elle girmek için M)")).Trim()
            if ($answer -match '^[mM]$') { return $null }
            $n = 0
            if (-not [int]::TryParse($answer, [ref]$n) -or $n -lt 1 -or $n -gt $found.Count) { Write-Host '  Geçersiz seçim.' -ForegroundColor Yellow; continue }
            $pick = $found[$n - 1]
        }
        Write-Host ''
        Write-Host "  Bulunan klasör: $($pick.Path)" -ForegroundColor Green
        Write-Host "  Kaynak:         $($pick.Source)"
        if (Read-YesNo 'Bu klasör doğru mu?') { return $pick.Path }
        if ($found.Count -eq 1) { return $null }
    }
}

# --- Ana akış --------------------------------------------------------------------------------------------------------
if ($ListOnly) {
    $found = @(Find-GameDirs)
    if ($found.Count -eq 0) { Write-Host "$($Info.Name): bulunamadı." }
    foreach ($f in $found) { Write-Host "$($f.Path)  [$($f.Source)]" }
    return
}

Write-Host ''
Write-Host "=== $($Info.Name) klasörü → $($Info.Env) ===" -ForegroundColor Cyan
$current = [Environment]::GetEnvironmentVariable($Info.Env, 'User')
if ($current) {
    $state = if (Test-GameDir $current) { 'geçerli' } else { "geçersiz: $($Info.Exe) yok" }
    Write-Host "Şu anki değer: $current ($state)"
    if ((Test-GameDir $current) -and -not (Read-YesNo 'Değiştirmek istiyor musunuz?')) { Write-Host 'Değişiklik yapılmadı.'; return }
}

$path = $null
while (-not $path) {
    $mode = ([string](Read-Host 'Otomatik tespit için A, konumu elle girmek için M yazın (çıkmak için Q)')).Trim().ToLowerInvariant()
    if ($mode -eq 'q') { Write-Host 'Değişiklik yapılmadı.'; return }
    if ($mode -eq 'a') {
        $path = Select-AutoPath
        if (-not $path) { Write-Host 'Klasörü elle girebilirsiniz.' }
    } elseif ($mode -eq 'm') {
        $path = Read-ManualPath
    } else {
        Write-Host '  A, M ya da Q yazın.' -ForegroundColor Yellow
    }
}

[Environment]::SetEnvironmentVariable($Info.Env, $path, 'User')
Set-Item -Path "env:$($Info.Env)" -Value $path
Write-Host ''
Write-Host "$($Info.Env) = $path" -ForegroundColor Green
Write-Host 'Kaydedildi (kullanıcı ortam değişkeni). Açık terminal, Visual Studio ve Rider pencerelerini kapatıp yeniden açın;'
Write-Host 'sonra projelerde .\build.ps1 derleyip doğrudan bu klasöre kurar.'
