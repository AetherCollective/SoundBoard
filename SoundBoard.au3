#RequireAdmin;needed to work in some games. 

#include "Misc.au3"
#include "Array.au3"

Opt("WinTitleMatchMode", -2)

If @OSArch = "x64" Then
    Global $VLC_Path = "C:\Program Files (x86)\VideoLAN\VLC\vlc.exe"
    Global $VLC_WorkingDir = "C:\Program Files (x86)\VideoLAN\VLC\"
Else
    Global $VLC_Path = "C:\Program Files\VideoLAN\VLC\vlc.exe"
    Global $VLC_WorkingDir = "C:\Program Files\VideoLAN\VLC\"
EndIf

$sIniName = @ScriptDir & "\SoundBoard.ini"

; Read ini section names
Global $aSectionList = IniReadSectionNames($sIniname)

If @error Then
    IniWriteSection($sIniname, "Sound1", 'Hotkey="+{numpad9}"' & @CRLF &  'File="' & @UserProfileDir & '\Music\SampleTrack.mp3"' & @CRLF & 'StartTime="12"' & @CRLF & 'EndTime="34"' & @CRLF & 'PlaybackDevice="Microsoft Soundmapper"')
    MsgBox(16, "SoundBoard", "SoundBoard.ini is missing. It has been created for you.")
    ShellExecute($sIniname, "", "", "edit")
    InputBox("SoundBoard", "Notes:" & @CRLF & "StartTime and EndTime are in seconds. Available Hotkeys can be found at the following url:", "https://www.autoitscript.com/autoit3/docs/functions/Send.htm")
    Exit
EndIf

; Create data array to hold ini data for each HotKey
Global $aHotKeyData[UBound($aSectionList)][5]
;_ArrayDisplay($aHotKeyData, "", Default, 8)

; For each section
For $i = 1 To $aSectionList[0]

    ; Read ini section
    $aSection = IniReadSection($sIniname, $aSectionList[$i])

    ; Fill HotKey data array                                                                ; example content
    $aHotKeyData[$i][0] = IniRead($sIniName, $aSectionList[$i], "HotKey", "Error")          ; !{numpad8}
    $aHotKeyData[$i][1] = IniRead($sIniName, $aSectionList[$i], "File", "Error")            ; C:\Users\BetaL\Music\SampleTrack1.mp3
    $aHotKeyData[$i][2] = IniRead($sIniName, $aSectionList[$i], "StartTime", "Error")       ; 12
    $aHotKeyData[$i][3] = IniRead($sIniName, $aSectionList[$i], "EndTime", "Error")         ; 34
    $aHotKeyData[$i][4] = IniRead($sIniName, $aSectionList[$i], "PlayBackDevice", "Error")  ; Microsoft Soundmapper

    ; Set HotKey to common function
    HotKeySet($aHotKeyData[$i][0], "_HotKeyFunc")

Next

;_ArrayDisplay($aHotKeyData, "", Default, 8)

While 1
    Sleep(10);idle to prevent unnecessary work. 10 is the minimal we can set this value to.
WEnd

Func _HotKeyFunc()

    ;Get HotKey pressed
    $sHotKeyPressed = @HotKeyPressed

    ;ConsoleWrite($sHotKeyPressed & @CRLF)

    ; Find HotKey pressed in the data array
    $iIndex = _ArraySearch($aHotKeyData, $sHotKeyPressed)
    ; Check found
    If $iIndex <> -1 Then
        ; Create parameter using the data in the array
        $sParam = '--qt-start-minimized --play-and-exit --start-time="' & $aHotKeyData[$iIndex][2] & '" --stop-time="' & $aHotKeyData[$iIndex][3] & '" --aout=waveout --waveout-audio-device="' & _
        $aHotKeyData[$iIndex][4] & '" "file:///' & StringReplace(StringReplace($aHotKeyData[$iIndex][1],"\", "/"), " ", "%20") & '"'
        ; Simulate passing commandline to VLC
        ConsoleWrite("ShellExecuteWait:" & @CRLF & $VLC_Path & @CRLF & $sParam & @CRLF & $VLC_WorkingDir & @CRLF & @CRLF)
		ShellExecuteWait($VLC_Path,$sParam,$VLC_WorkingDir)
        Beep(500, 200)
    Else
        ConsoleWrite("Not a valid HotKey" & @CRLF)
    EndIf

EndFunc