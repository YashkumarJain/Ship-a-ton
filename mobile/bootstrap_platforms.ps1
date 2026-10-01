$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter is not installed or is not on PATH. Install Flutter first, then rerun this script."
}

$mobileDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tempDir = Join-Path $env:TEMP "wealthpilot_flutter_platforms"

if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
flutter create --platforms=android,ios --project-name shipaton_wealth_assistant --org com.wealthpilot $tempDir

Copy-Item (Join-Path $tempDir "android") $mobileDir -Recurse -Force
Copy-Item (Join-Path $tempDir "ios") $mobileDir -Recurse -Force
Remove-Item $tempDir -Recurse -Force

$manifest = Join-Path $mobileDir "android\app\src\main\AndroidManifest.xml"
$xml = Get-Content $manifest -Raw
$permissions = @"
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.INTERNET" />
"@
if ($xml -notmatch "android.permission.RECORD_AUDIO") {
  $xml = $xml -replace '<manifest xmlns:android="http://schemas.android.com/apk/res/android">', "<manifest xmlns:android=`"http://schemas.android.com/apk/res/android`">`r`n$permissions"
}
$xml = $xml -replace 'android:label="[^"]+"', 'android:label="WealthPilot"'
if ($xml -notmatch 'android.speech.RecognitionService') {
  $queries = @"
    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
    </queries>
"@
  $xml = $xml -replace '<application', "$queries`r`n    <application"
}
Set-Content $manifest $xml

$plist = Join-Path $mobileDir "ios\Runner\Info.plist"
$plistText = Get-Content $plist -Raw
$usage = @"
	<key>NSMicrophoneUsageDescription</key>
	<string>WealthPilot listens for “Hey Assistant” while the app is open.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>WealthPilot converts your spoken financial questions to text.</string>
"@
if ($plistText -notmatch "NSMicrophoneUsageDescription") {
  $plistText = $plistText -replace '</dict>', "$usage`r`n</dict>"
}
$plistReplacement = "<key>CFBundleDisplayName</key>`r`n`t<string>WealthPilot</string>"
$plistText = $plistText -replace '<key>CFBundleDisplayName</key>\s*<string>[^<]+</string>', $plistReplacement
Set-Content $plist $plistText

Write-Host "Android/iOS runners created with WealthPilot branding and microphone/speech permissions."
Write-Host "Next: cd mobile; flutter pub get; flutter run --dart-define=..."
