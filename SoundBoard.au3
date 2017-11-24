;#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=System\Icon 32.ico
#AutoIt3Wrapper_Res_Comment=Initial Code by Jeff Savage (BetaLeaf), GUI by Joshua Songer (Xandy)
#AutoIt3Wrapper_Res_Description=A SoundBoard App.
#AutoIt3Wrapper_Res_Fileversion=2.0.0.0
#AutoIt3Wrapper_Res_LegalCopyright=Copyright © 2017 Jeff Savage (BetaLeaf) & Joshua Songer (Xandy)
#AutoIt3Wrapper_Res_requestedExecutionLevel=highestAvailable
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
FileInstall(".\System\key_names.txt", @ScriptDir & "\System\key_names.txt", 1)
FileInstall(".\System\Icon 32.ico", @ScriptDir & "\System\Icon 32.ico", 1)
FileInstall(".\System\Contributors.txt", @ScriptDir & "\System\Contributors.txt", 1)
; I like to close and restart a lot, this saves me steps
HotKeySet('^{PAUSE}', '_hotkey_exit')
#include "Misc.au3"
#include "Array.au3"
#include "File.au3"
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <TrayConstants.au3>
#include "Include\GUIScrollbars_Ex.au3"
_Singleton("SoundBoard")
; Dock all GUI Control, Don't move or resize if GUI Window Size Changes
Opt("GUIResizeMode", $GUI_DOCKALL)
Global $gPath_system = @ScriptDir & "\System\"
Global $gScript_name = StringTrimRight(@ScriptName, 4)

; IsPressed Hotkey System
Enum $eKey_code, $eKey_name, $eKey_send
Global $gKey_data_max = 3
Global $gaKey[1][$gKey_data_max] ; ReDimed in key_load() to (Lines in: Key_Names.txt / gKey_data_max)
Global $gHotkey_amount_max = 4
Global $gHotkey_amount = $gHotkey_amount_max

; IsPressed DLL
Global $ghDLL = DllOpen("user32.dll")
$gaKey = key_load()
Global $gForm1_w = 480
Global $ghForm1 = Null

; Enum gives index specification
Enum $eHotkey_sKey, _
		$eHotkey_sFile, _
		$eHotkey_nStart, _
		$eHotkey_nEnd, _
		$eHotkey_sPlayback_device, _ ;
		$eHotkey_ispressed, _
		$eHotkey_ctrl, _
		$eHotkey_alt, _
		$eHotkey_shift, _
		$eHotkey_win, _
		$eHotKey_modifier_label, _ ; GUI Controls only
		$eHotkey_browse, _
		$eHotkey_remove
Global $gHotkey_max = 128

; Hotkey Data
Global $gaHotKeyData[$gHotkey_max][$eHotKey_modifier_label]
$gaHotKeyData[0][0] = 1 ; start cursor at one
$gaHotKeyData[0][1] = 0 ; Ult IsPressed Hotkeys
Global $gHotkey_control_data_max = $eHotkey_remove + 1
Global $gUrl_send_key_list = "https://www.autoitscript.com/autoit3/docs/functions/Send.htm"
Global $gaDropfiles[1]
Global $dragdropinclude, _
		$dragdropincludefilesfolders = $FLTAR_FILES, _
		$dragdropfoldersdeep = 10, _
		$dragdropexclude, _
		$dragdropsystem, _
		$dragdrophidden, _
		$dragdropshowoptions

; To ack GUI Resize Event
Global $gGui_resize = 0
GUIRegisterMsg($WM_SIZE, "_WM_SIZE")

; GUI size width constraint
GUIRegisterMsg($WM_GETMINMAXINFO, 'WM_GETMINMAXINFO')

; Drop Files Register
GUIRegisterMsg($WM_DROPFILES, "WM_DROPFILES_FUNC")
LoadIni()
Tray()
Opt("WinTitleMatchMode", -2)

; VLC Directory path
If @OSArch = "x64" Then
	Global $VLC_Path = "C:\Program Files (x86)\VideoLAN\VLC\vlc.exe"
	Global $VLC_WorkingDir = "C:\Program Files (x86)\VideoLAN\VLC\"
Else
	Global $VLC_Path = "C:\Program Files\VideoLAN\VLC\vlc.exe"
	Global $VLC_WorkingDir = "C:\Program Files\VideoLAN\VLC\"
EndIf
If FileExists($VLC_Path) = False Then
	$VLC_Path = @ScriptDir & "\VLC\VLC.exe"
	$VLC_WorkingDir = @ScriptDir & "\VLC"
EndIf
main()
Func main()
	ConfigureGUI()
	Local $aModifier_code = [11, 12, 10, 0x5B, 0x5C]
	Local $iDo = 1
	While 1
		Sleep(100) ;idle to prevent unnecessary work. 10 is the minimal we can set this value to.
		For $i = 1 To $gaHotKeyData[0][1]
			$iDo = 1
			; Check if main key down
			If _IsPressed($gaHotKeyData[$i][$eHotkey_sKey], $ghDLL) Then
				; Check if modifiers are down
				$iii = 0 ; Could remove $iii and replace with: $aModifier_code[$ii - $eHotkey_ctrl] but is this faster or less work on processor?
				For $ii = $eHotkey_ctrl To $eHotkey_shift
					If $gaHotKeyData[$i][$ii] = $GUI_CHECKED Then
						If _IsPressed($aModifier_code[$iii], $ghDLL) = 0 Then $iDo = 0
					EndIf
					$iii += 1 ; Could be removed SEE REMARK above
				Next
				; Check if win modifiers need to be down
				If $gaHotKeyData[$i][$eHotKey_win] = $GUI_CHECKED Then
					; Handling win modifier special b/c two
					If _IsPressed($aModifier_code[3], $ghDLL) = 0 Or _IsPressed($aModifier_code[4], $ghDLL) = 0 Then $iDo = 0
				EndIf
				If $iDo = 1 Then
					; We get signal
					VLC_play($i)
					out("Played: " & $i)
				EndIf
			EndIf ; main key doen
		Next ; key set
	WEnd ; main loop to capture IsPressed
EndFunc   ;==>main
Func Tray()
	Opt("TrayAutoPause", 0)
	Opt("TrayMenuMode", 2)
	Opt("TrayOnEventMode", 1)
	TrayItemSetOnEvent(TrayCreateItem("Configure"), "ConfigureGUI")
EndFunc   ;==>Tray
Func ConfigureGUI()
	Local $aHotkey_data_backup = $gaHotKeyData
	; Setup GUI
	Local $step_y = 65
	Local $button_w = 60, $button_h = 32, $menubar_h = 0
	Local $Form1_h = $button_h * 4 + $menubar_h, $tiny_margin_more = 5, $tiny_margin_more_h = 44

	; Create GUI
	$ghForm1 = GUICreate($gScript_name & ": Hotkeys", $gForm1_w, $Form1_h, -1, -1, BitOR($GUI_SS_DEFAULT_GUI, $WS_SIZEBOX))
	;$menu_file = GUICtrlCreateMenu("&File")
	GUISetIcon($gPath_system & "Icon 32.ico")
	Local $Ok = GUICtrlCreateButton("Ok", $gForm1_w - $button_w - $tiny_margin_more * 2, 0, $button_w, $button_h)
	Local $Cancel = GUICtrlCreateButton("Cancel", $gForm1_w - $button_w - $tiny_margin_more * 2, 32, $button_w, $button_h)
	Local $Add = GUICtrlCreateButton("Add", $gForm1_w - $button_w - $tiny_margin_more * 2, 64, $button_w, $button_h)
	Local $url_send_names_button = GUICtrlCreateButton("Key Names", $gForm1_w - $button_w - $tiny_margin_more * 2, 96, $button_w, $button_h)
	GUICtrlSetTip($url_send_names_button, 'Launches ' & $gUrl_send_key_list & ' in a browser.')

	; Temp Buttons
;~ 	$up_button = GUICtrlCreateButton("/\", $gForm1_w - $button_w - $tiny_margin_more*8, 50, 20, 20)
;~ 	$tiny_margin_more_h_input = GUICtrlCreateInput($tiny_margin_more_h, $gForm1_w - $button_w - $tiny_margin_more*8, 70, 20, 20, $ES_READONLY)
;~ 	$down_button = GUICtrlCreateButton("\/", $gForm1_w - $button_w - $tiny_margin_more*8, 91, 20, 20)
;~ 	GUICtrlSetTip($up_button, "Click to Resize Inner GUI")
;~ 	GUICtrlSetTip($tiny_margin_more_h_input, "Inner GUI height")
;~ 	GUICtrlSetTip($down_button, "Click to Resize Inner GUI")
	GUISetState() ; Show Form1

	; Make sub scrollable GUI
	Local $aGui_scroll_rect = [0, 0, $gForm1_w - $button_w - $tiny_margin_more * 3, $Form1_h - $tiny_margin_more_h - $menubar_h]
	$hGui_scroll = GUICreate("", $aGui_scroll_rect[2], $aGui_scroll_rect[3], $aGui_scroll_rect[0], $aGui_scroll_rect[1], $WS_POPUP, BitOR($WS_EX_MDICHILD, $WS_EX_ACCEPTFILES), $ghForm1)
	GUISetBkColor(0xC0C0C0)
	; Intialise for Scrolling
	_GUIScrollbars_Generate($hGui_scroll, 0, $gHotkey_max * $step_y)
	GUISetState() ; Show hGui_scroll

	;https://www.autoitscript.com/forum/topic/124406-drag-and-drop-with-uac/?do=findComment&comment=864050
	_ChangeWindowMessageFilterEx($hGui_scroll, 0x233, 1) ; $WM_DROPFILES
	_ChangeWindowMessageFilterEx($hGui_scroll, $WM_COPYDATA, 1) ; redundant?
	_ChangeWindowMessageFilterEx($hGui_scroll, 0x0049, 1) ; $WM_COPYGLOBALDATA

	; aHotkey_control
	Local $aHotKey_control[$gHotkey_max][$gHotkey_control_data_max]
	Local $aMod_symbol = ['^', '!', '+', '#']
	; Display Hotkey Array on GUI
	Local $count = $gaHotKeyData[0][0] ; It's a weird fix but it saves me changing more function parameters
	$gaHotKeyData[0][0] = 1
	For $i = 1 To $count

		; Unset all hotkeys
		HotKeySet($gaHotKeyData[$i][$eHotkey_sKey])

		; Make hotkey controls for old hotkeys
		AddButton($hGui_scroll, $aHotKey_control)

		; Set the Data
		For $ii = $eHotkey_sFile To $eHotkey_sPlayback_device
			GUICtrlSetData($aHotKey_control[$i][$ii], $gaHotKeyData[$i][$ii])
		Next

		; Start
		;GUICtrlSetData($aHotKey_control[$i][$eHotkey_nStart], $gaHotKeyData[$i][$eHotkey_nStart])
		; End
		;GUICtrlSetData($aHotKey_control[$i][$eHotkey_nEnd], $gaHotKeyData[$i][$eHotkey_nEnd])

		; File
		;GUICtrlSetData($aHotKey_control[$i][$eHotkey_sFile], $gaHotKeyData[$i][$eHotkey_sFile])

		; Set Checkboxs
		For $ii = $eHotkey_ispressed To $eHotKey_win
			If $gaHotKeyData[$i][$ii] = $GUI_CHECKED Then
				GUICtrlSetState($aHotKey_control[$i][$ii], $GUI_CHECKED)
			EndIf
		Next

		; Set ToolTip to Path
		GUICtrlSetTip($aHotKey_control[$i][$eHotkey_sFile], "File Launched:" & @CRLF & $gaHotKeyData[$i][$eHotkey_sFile])
		If $gaHotKeyData[$i][$eHotkey_ispressed] = $GUI_CHECKED Then
			For $ii = 1 To $gaKey[0][0]
				If $gaKey[$ii][$eKey_code] = $gaHotKeyData[$i][$eHotkey_sKey] Then

					; IsPressed Code Converted into Send Hotkey
					GUICtrlSetData($aHotKey_control[$i][$eHotkey_sKey], $gaKey[$ii][$eKey_send])
					ExitLoop
				EndIf
			Next
		Else
			; Hotkey Modifiers
			For $ii = 0 To UBound($aMod_symbol) - 1
				If StringInStr($gaHotKeyData[$i][$eHotkey_sKey], $aMod_symbol[$ii]) > 0 Then
					;beep()
					GUICtrlSetState($aHotKey_control[$i][$eHotkey_ctrl + $ii], $GUI_CHECKED)
					$gaHotKeyData[$i][$eHotkey_sKey] = StringReplace($gaHotKeyData[$i][$eHotkey_sKey], $aMod_symbol[$ii], '')
				EndIf
			Next
			; Hotkey
			GUICtrlSetData($aHotKey_control[$i][$eHotkey_sKey], $gaHotKeyData[$i][$eHotkey_sKey])
		EndIf
	Next
	Local $confirm = 0
	While 1
		$aMsg = GUIGetMsg($GUI_EVENT_ARRAY)
		Switch $aMsg[1]
			Case $ghForm1
				Switch $aMsg[0]
					Case $GUI_EVENT_CLOSE, $Cancel
						ExitLoop
					Case $Ok
						$confirm = 1
						ExitLoop
					Case $Add
						AddButton($hGui_scroll, $aHotKey_control)
						WinActivate($hGui_scroll)
					Case $url_send_names_button
						ShellExecute($gUrl_send_key_list)
						; Temp Code Block to Test Inner GUI Size
;~ 					Case $up_button, $down_button
;~ 						If $aMsg[0] = $up_button Then
;~ 							$tiny_margin_more_h += 1
;~ 						Else
;~ 							$tiny_margin_more_h -= 1
;~ 						EndIf
;~ 						$gGui_resize = 1
;~ 						GUICtrlSetData($tiny_margin_more_h_input, $tiny_margin_more_h)
				EndSwitch
			Case $hGui_scroll
				For $i = 1 To $gaHotKeyData[0][0]
					Switch $aMsg[0]
						Case $aHotKey_control[$i][$eHotkey_browse]
							$sFileOpenDialog = FileOpenDialog("Select File Playable by VLC", @WorkingDir & "\", "All (*.*)", $FD_FILEMUSTEXIST)
							If @error = 0 Then
								; Set File Path Field
								GUICtrlSetData($aHotKey_control[$i][$eHotkey_sFile], $sFileOpenDialog)
								; Set ToolTip to Path
								GUICtrlSetTip($aHotKey_control[$i][$eHotkey_sFile], "File Launched:" & @CRLF & $sFileOpenDialog)
							EndIf
						Case $aHotKey_control[$i][$eHotkey_remove]
							$gaHotKeyData[0][0] -= 1
							For $ii = $i To $gaHotKeyData[0][0]
								For $iii = $i To $eHotKey_win
									GUICtrlSetData($aHotKey_control[$ii][$iii], GUICtrlRead($aHotKey_control[$ii + 1][$iii]))
								Next
							Next
							For $ii = 0 To $gHotkey_control_data_max - 1
								GUICtrlDelete($aHotKey_control[$gaHotKeyData[0][0]][$ii])
							Next
							out("Remove: " & $i)
							out("Ubound: " & UBound($gaHotKeyData))
							For $ii = 0 To $eHotKey_modifier_label - 1
								$gaHotKeyData[$i][$ii] = ''
							Next
							;$gaHotKeyData[0][0] -= 1
					EndSwitch ; aMsg[0]
				Next ; i gaHotKeyData[0][0]
				If $aMsg[0] = $GUI_EVENT_DROPPED Then
					; Drag / Drop Event
					$dropped_max = UBound($gaDropfiles) - 1
					For $i = 1 To $gaHotKeyData[0][0] - 1 ; locate the id row of drop
						If $aHotKey_control[$i][$eHotkey_sFile] = @GUI_DropId Then ;test for dropped on me flag
							$hotkey_dropped = $i ;the input field to modify 0-$hotkeysonpage-1
							ExitLoop ;found, lets gtfooh
						EndIf
					Next
					$dropped_count = 0
					If $dropped_max > 0 Or StringInStr(FileGetAttrib($gaDropfiles[0]), "D") > 0 Then
						If $dragdropshowoptions = 1 Then ;do we show drag and drop settings
							;$parentxy= WinGetPos($hgui)
							; Dialog to change drag and drop settings
							;showsettings($parentxy[0]+10, $parentxy[1]+100, 610, 430, "settings", 1)
						EndIf
					EndIf
					WinActivate($hGui_scroll)
					For $i = 0 To $dropped_max ;all the files dropped
						;If $cell+$temp < $gaHotKeyData[0][0] Then;test hotkey range
						If StringInStr(FileGetAttrib($gaDropfiles[$i]), "D") > 0 Then ;when directory folder search with melba's function
							; Is Directory
							;If $dragdropincludefilesfolders= 0 or $dragdropincludefilesfolders= 2 Then;include folder names?
							;insertfunction($kid+$temp, 0, $gaDropfiles[$i])
							; Clear File field
							;	GUICtrlSetData($aHotKey_control[$cell][$eHotkey_sFile], $gaDropfiles[$i])
							;If $cell+$temp < $hotkeysonpage Then GUICtrlSetData($inputfunction[$cell+$temp], $function[$kid+$temp][0])
							;	$temp= $temp+1
							;EndIf; end if include folder names
							;             _RecFileListToArray(InitialPath,    Include_List,  Ret, Rec, Srt, fullpath=2, Exclude_List = "", $sExclude_List_Folder = "")
							; _RecFileListToArray written by melba32

							; Directory inserts files within
							$droparray = _FileListToArrayRec($gaDropfiles[$i], '*.*', $dragdropincludefilesfolders, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
							For $ii = 1 To $droparray[0] ; loop through melba's return array of path strings
								;If $cell+$temp < $gaHotKeyData[0][0] Then
								$fileattrib = FileGetAttrib($droparray[$ii])
								$no = 0
								If StringInStr($fileattrib, "S") Then $no = 1
								If StringInStr($fileattrib, "H") Then $no = 1
								If $no = 0 Then
									;insertfunction($kid+$temp, 0, $droparray[$ii])
									GUICtrlSetData($aHotKey_control[$hotkey_dropped + $dropped_count][$eHotkey_sFile], $droparray[$ii])
									;If $cell+$temp < $gaHotKeyData[0][0] Then GUICtrlSetData($aHotKey_control[$cell+$temp][$eHotkey_sFile], $droparray[$i])
									If $hotkey_dropped + $dropped_count > $gaHotKeyData[0][0] - 1 Then AddButton($hGui_scroll, $aHotKey_control)
									GUICtrlSetData($aHotKey_control[$hotkey_dropped + $dropped_count][$eHotkey_sFile], $droparray[$ii])
									$dropped_count += 1
								EndIf
								;Else
								;	ExitLoop
								;EndIf
							Next
							;if not directory
						Else ;if $dragdropincludefilesfolders= 0 or $dragdropincludefilesfolders= 2 then;include file names
							; Single Files
							$fileattrib = FileGetAttrib($gaDropfiles[$i])
							$no = 0
							If $dragdropsystem = 0 And StringInStr($fileattrib, "S") Then $no = 1
							If $dragdrophidden = 0 And StringInStr($fileattrib, "H") Then $no = 1
							If $no = 0 Then
								; Clear File field
								;GUICtrlSetData($aHotKey_control[$cell+$temp][$eHotkey_sFile], $gaDropfiles[$i])
								;if $cell+$temp < $hotkeysonpage then guictrlsetdata($inputfunction[$cell+$temp], $function[$kid+$temp][0])
								If $hotkey_dropped + $dropped_count > $gaHotKeyData[0][0] - 1 Then
									out("ADD")
									AddButton($hGui_scroll, $aHotKey_control)
								EndIf
								out("$hotkey_dropped+$dropped_count: " & $hotkey_dropped + $dropped_count)
								out("$gaDropfiles[$i]: " & $gaDropfiles[$i])
								out("Ret: " & GUICtrlSetData($aHotKey_control[$hotkey_dropped + $dropped_count][$eHotkey_sFile], $gaDropfiles[$i]))

								; Set ToolTip to Path
								GUICtrlSetTip($aHotKey_control[$hotkey_dropped + $dropped_count][$eHotkey_sFile], "File Launched:" & @CRLF & $gaDropfiles[$i])
								$dropped_count += 1
							EndIf
						EndIf ;end test if directory folder
						;EndIf;end test hotkey range
					Next ;next for $i= 0 to ubound($gaDropfiles)
				EndIf
		EndSwitch ; aMsg[1]
		If $gGui_resize = 1 Then
			$gGui_resize = 0
			$aGui_rect = WinGetPos($ghForm1)

			; Resize the inner sub scrollable window
			WinMove($hGui_scroll, "", Default, Default, $aGui_scroll_rect[2], $aGui_rect[3] - $tiny_margin_more_h - $menubar_h)
		EndIf ;gGui_resize = 1
	WEnd ; GUI main loop
	If $confirm = 1 Then

		; Set all hotkeys
		ConsoleWrite("$gaHotKeyData[0][0]: " & $gaHotKeyData[0][0])
		;ReDim $gaHotKeyData[ $gaHotKeyData[0][0] ][$eHotKey_modifier_label]
		$gaHotKeyData[0][0] -= 1
		; Read hotkey controls
		For $i = 1 To $gaHotKeyData[0][0]
			If GUICtrlRead($aHotKey_control[$i][$eHotkey_ispressed]) = $GUI_CHECKED Then
				$gaHotKeyData[$i][$eHotkey_sKey] = GUICtrlRead($aHotKey_control[$i][$eHotkey_sKey])
				For $ii = 1 To $gaKey[0][0]
					If $gaKey[$ii][$eKey_send] = $gaHotKeyData[$i][$eHotkey_sKey] Then
						$gaHotKeyData[$i][$eHotkey_sKey] = $gaKey[$ii][$eKey_code]
						ExitLoop
					EndIf
				Next
			Else
				; Key String, Clear
				$gaHotKeyData[$i][$eHotkey_sKey] = ''
				; Check the modifier checkboxs
				For $ii = 0 To UBound($aMod_symbol) - 1
					If GUICtrlRead($aHotKey_control[$i][$eHotkey_ctrl + $ii]) = $GUI_CHECKED Then
						; Insert modifier symbols
						$gaHotKeyData[$i][$eHotkey_sKey] &= $aMod_symbol[$ii]
					EndIf
				Next
				; Append the key itself
				$gaHotKeyData[$i][$eHotkey_sKey] &= GUICtrlRead($aHotKey_control[$i][$eHotkey_sKey])
			EndIf
			For $ii = $eHotkey_sFile To $eHotKey_win
				; Start
				;$gaHotKeyData[$i][$eHotkey_nStart] = GUICtrlRead($aHotKey_control[$i][$eHotkey_nStart])
				; End
				;$gaHotKeyData[$i][$eHotkey_nEnd] = GUICtrlRead($aHotKey_control[$i][$eHotkey_nEnd])
				; File
				;$gaHotKeyData[$i][$eHotkey_sFile] = GUICtrlRead($aHotKey_control[$i][$eHotkey_sFile])
				$gaHotKeyData[$i][$ii] = GUICtrlRead($aHotKey_control[$i][$ii])
			Next

			;hotkey_activate()
		Next
		hotkey_sort($gaHotKeyData)
		hotkey_save($gaHotKeyData)
		hotkey_activate()
	Else
		$gaHotKeyData[0][0] = $count
	EndIf
	GUIDelete($ghForm1)
EndFunc   ;==>ConfigureGUI
Func OkButton()
	MsgBox(0, @ScriptName, "Not Programmed!")
EndFunc   ;==>OkButton
Func CancelButton()
	;GUISetState(@SW_HIDE)
EndFunc   ;==>CancelButton
Func AddButton($hGui_scroll, ByRef $aHotKey_control)

	;GUISwitch($hGui_scroll)
	Local $step_y = 65

	; If scrolled, place control accuratly and we don't care about x so it is 0
	$aControl_pos = _GUIScrollbars_Locate_Ctrl($hGui_scroll, 0, ($gaHotKeyData[0][0] - 1) * $step_y)
	; File
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotkey_sFile] = GUICtrlCreateInput("", 64, $aControl_pos[1] + 0, 225, 21)
	GUICtrlSetState($aHotKey_control[$gaHotKeyData[0][0]][$eHotkey_sFile], $GUI_DROPACCEPTED)
	; Browse
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotKey_browse] = GUICtrlCreateButton("...", 296, $aControl_pos[1] + -1, 25, 20)
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotKey_nStart] = GUICtrlCreateInput("Start Time", 0, $aControl_pos[1] + 0, 57, 21)
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotKey_nEnd] = GUICtrlCreateInput("End Time", 0, $aControl_pos[1] + 26, 57, 21)
	; Label CTRL ALT SHIT WIN ULT
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotKey_modifier_label] = GUICtrlCreateLabel("CTRL  ALT   SHIFT   WIN    Key                    ULT", _
			64, $aControl_pos[1] + 21, 250, 15)
	; Modifiers CTRL ALT SHIT WIN ULT
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotKey_ctrl] = GUICtrlCreateCheckbox("", 64, $aControl_pos[1] + 33, 31, 17) ;	CTRL
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotKey_alt] = GUICtrlCreateCheckbox("", 98, $aControl_pos[1] + 33, 27, 17) ;	ALT
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotKey_shift] = GUICtrlCreateCheckbox("", 128, $aControl_pos[1] + 33, 39, 17) ;SHIFT
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotKey_win] = GUICtrlCreateCheckbox("", 168, $aControl_pos[1] + 33, 36, 17) ; 	WIN
	; Key
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotkey_sKey] = GUICtrlCreateInput("", 200, $aControl_pos[1] + 36, 70, 17)
	; Remove
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotkey_remove] = GUICtrlCreateButton("Remove", 320, $aControl_pos[1] + 30, 49, 20)
	; Ult
	$aHotKey_control[$gaHotKeyData[0][0]][$eHotkey_ispressed] = GUICtrlCreateCheckbox("", 280, $aControl_pos[1] + 32, 35, 20)
	; Set Tips
	GUICtrlSetTip($aHotKey_control[$gaHotKeyData[0][0]][$eHotKey_nStart], "Start Time in Seconds. Decimals accepted.")
	GUICtrlSetTip($aHotKey_control[$gaHotKeyData[0][0]][$eHotKey_nEnd], "End Time in Seconds. Decimals accepted.")
	GUICtrlSetTip($aHotKey_control[$gaHotKeyData[0][0]][$eHotkey_sKey], "Keypress." & @CRLF & "Press the Key Names button to the right for a list of keypress names and values.")
	GUICtrlSetTip($aHotKey_control[$gaHotKeyData[0][0]][$eHotkey_ispressed], "Some applications use all of the hotkeys." & @CRLF & _
			"Checking the Ult box will use a differant method of detecting keys down.")
	$gaHotKeyData[0][0] += 1
EndFunc   ;==>AddButton
Func LoadIni()
	$sIniName = @ScriptDir & "\SoundBoard.ini"
	; Read ini section names
	Global $aSectionList = IniReadSectionNames($sIniName)
	If @error Then
		IniWriteSection($sIniName, "Sound1", 'Hotkey="^{numpad9}"' & @CRLF & 'File="' & @UserProfileDir & '\Music\SampleTrack.mp3"' & @CRLF & 'StartTime="00"' & @CRLF & 'EndTime="999999"' & @CRLF & 'PlaybackDevice="Microsoft Soundmapper"' & @CRLF & 'IsPressed="0"' & @CRLF & 'CTRL="1"' & @CRLF & 'ALT="4"' & @CRLF & 'SHIFT="4"' & @CRLF & 'WIN="4"')
		;MsgBox(16, "SoundBoard", "SoundBoard.ini is missing. It has been created for you.")
		;ShellExecute($sIniName, "", "", "edit")
		For $timer = 1 To 20
			If FileExists(@ScriptDir & "\SoundBoard.ini") = True Then ExitLoop
			Sleep(10)
		Next
		;MsgBox(64, "SoundBoard", "Notes:" & @CRLF & "StartTime and EndTime are in seconds and can be left empty. PlaybackDevice can be empty if not using Loopback feature. All entries in each section must exist and remain in the same order.")
		;InputBox("SoundBoard", "Section names ([Sound1]) must be unique. Available Hotkeys can be found at the following url:", $gUrl_send_key_list)
		$aSectionList = IniReadSectionNames($sIniName)
	EndIf
	; Create data array to hold ini data for each HotKey
	;ReDim $gaHotKeyData[UBound($aSectionList) + 1][$eHotKey_modifier_label]
	;_ArrayDisplay($gaHotKeyData, "", Default, 8)
	ConsoleWrite("$aSectionList[0]: " & $aSectionList[0] & @CRLF)
	$gaHotKeyData[0][0] = $aSectionList[0]
	; For each section
	For $i = 1 To $aSectionList[0]
		; Read ini section
		$aSection = IniReadSection($sIniName, $aSectionList[$i])
		; Fill HotKey data array                                                                ; example content
		$gaHotKeyData[$i][$eHotkey_sKey] = IniRead($sIniName, $aSectionList[$i], "HotKey", "Error") ; !{numpad8}
		$gaHotKeyData[$i][$eHotkey_sFile] = IniRead($sIniName, $aSectionList[$i], "File", "Error") ; C:\Users\BetaL\Music\SampleTrack1.mp3
		$gaHotKeyData[$i][$eHotKey_nStart] = IniRead($sIniName, $aSectionList[$i], "StartTime", "") ; 12
		$gaHotKeyData[$i][$eHotKey_nEnd] = IniRead($sIniName, $aSectionList[$i], "EndTime", "") ; 34
		$gaHotKeyData[$i][$eHotkey_sPlayback_device] = IniRead($sIniName, $aSectionList[$i], "PlayBackDevice", "Microsoft Soundmapper") ; Microsoft Soundmapper
		$gaHotKeyData[$i][$eHotkey_ispressed] = IniRead($sIniName, $aSectionList[$i], "IsPressed", "Error") ; IsPressed Checkbox

		; Set HotKey to common function
		HotKeySet($gaHotKeyData[$i][$eHotkey_sKey], "_HotKeyFunc")
	Next
	HotKeySet("!^{esc}", CloseVLC)
EndFunc   ;==>LoadIni
Func _HotKeyFunc()
	;Get HotKey pressed
	$sHotKeyPressed = @HotKeyPressed
	out("key: " & @HotKeyPressed)
;~ 	For $i = 1 To $gaHotKeyData[0][0]; needs ahotkey[0][0] count
;~ 		HotKeySet($gaHotKeyData[$i][$eHotkey_sKey])
;~ 	Next
	;ConsoleWrite($sHotKeyPressed & @CRLF)
	; Find HotKey pressed in the data array
	$iIndex = _ArraySearch($gaHotKeyData, $sHotKeyPressed, 1)
	; Check found
	If $iIndex <> -1 Then
;~ 		out("key: " & $gaHotKeyData[$iIndex][$eHotkey_sKey])
;~ 		; Create parameter using the data in the array
;~ 		$sParam = '--qt-start-minimized --play-and-exit --start-time="' & $gaHotKeyData[$iIndex][$eHotkey_nStart] & '" --stop-time="' & $gaHotKeyData[$iIndex][$eHotkey_nEnd] & '" --aout=waveout --waveout-audio-device="' & 		$gaHotKeyData[$iIndex][$eHotkey_sPlayback_device] & '" "file:///' & StringReplace(StringReplace($gaHotKeyData[$iIndex][$eHotkey_sFile], "\", "/"), " ", "%20") & '"'
;~ 		; Simulate passing commandline to VLC
;~ 		ConsoleWrite("ShellExecuteWait:" & @CRLF & $VLC_Path & @CRLF & $sParam & @CRLF & $VLC_WorkingDir & @CRLF & @CRLF)
;~ 		Global $PID = ShellExecute($VLC_Path, $sParam, $VLC_WorkingDir)
;~ 		ProcessWaitClose("VLC.exe")
;~ 		;Beep(500, 200)
		VLC_play($iIndex)
	Else
		ConsoleWrite("Not a valid HotKey" & @CRLF)
	EndIf
;~ 	For $i = 1 To $gaHotKeyData[0][0]
;~ 		HotKeySet($gaHotKeyData[$i][$eHotkey_sKey], "_HotKeyFunc")
;~ 	Next
EndFunc   ;==>_HotKeyFunc
Func VLC_play($iIndex)
	out("key: " & $gaHotKeyData[$iIndex][$eHotkey_sKey])
	; Create parameter using the data in the array
	$sParam = '--qt-start-minimized --play-and-exit --start-time="' & $gaHotKeyData[$iIndex][$eHotKey_nStart] & '" --stop-time="' & $gaHotKeyData[$iIndex][$eHotKey_nEnd] & '" --aout=waveout --waveout-audio-device="' & $gaHotKeyData[$iIndex][$eHotkey_sPlayback_device] & '" "file:///' & StringReplace(StringReplace($gaHotKeyData[$iIndex][$eHotkey_sFile], "\", "/"), " ", "%20") & '"'
	; Simulate passing commandline to VLC
	ConsoleWrite("ShellExecuteWait:" & @CRLF & $VLC_Path & @CRLF & $sParam & @CRLF & $VLC_WorkingDir & @CRLF & @CRLF)
	Global $PID = ShellExecute($VLC_Path, $sParam, $VLC_WorkingDir)

	; Hotkeys bypass this but IsPressed won't work until called process closes so I remarked fuck it
	;ProcessWaitClose("VLC.exe")

	;Beep(500, 200)
EndFunc   ;==>VLC_play
Func CloseVLC()
	If ProcessClose($PID) <> 1 Then MsgBox(16, "SoundBoard", "Cannot close VLC. Error: " & @error & "-" & @extended&@CRLF&"This can be caused if you played 2 sounds at the same time.")
EndFunc   ;==>CloseVLC
Func _hotkey_exit()
	ConsoleWrite(@CRLF & 'hotkey_exit()')
	Exit
EndFunc   ;==>_hotkey_exit
Func keyreleased($_key1, $_key2 = "", $_key3 = "", $_key4 = "")
	While _IsPressed($_key1) Or _IsPressed($_key2)
		Sleep(20)
	WEnd
	While _IsPressed($_key3) Or _IsPressed($_key4)
		Sleep(20)
	WEnd
EndFunc   ;==>keyreleased
Func _WM_SIZE($hWnd, $iMsg, $wParam, $lParam)
	$gGui_resize = 1
EndFunc   ;==>_WM_SIZE
Func WM_DROPFILES_FUNC($hWnd, $msgID, $wParam, $lParam)
	Local $nSize, $pFileName
	Local $nAmt = DllCall("shell32.dll", "int", "DragQueryFile", "hwnd", $wParam, "int", 0xFFFFFFFF, "ptr", 0, "int", 255)
	If IsArray($nAmt) Then
		ReDim $gaDropfiles[$nAmt[0]]
		For $i = 0 To $nAmt[0] - 1
			$nSize = DllCall("shell32.dll", "int", "DragQueryFile", "hwnd", $wParam, "int", $i, "ptr", 0, "int", 0)
			$nSize = $nSize[0] + 1
			$pFileName = DllStructCreate("char[" & $nSize & "]")
			DllCall("shell32.dll", "int", "DragQueryFile", "hwnd", $wParam, "int", $i, "ptr", DllStructGetPtr($pFileName), "int", $nSize)
			$gaDropfiles[$i] = DllStructGetData($pFileName, 1)
			$pFileName = 0
		Next
	EndIf ; isarray(nAmt)
	;_ArrayDisplay($gaDropfiles)
EndFunc   ;==>WM_DROPFILES_FUNC

; Constrains the GUI to min width
Func WM_GETMINMAXINFO($hWnd, $msgID, $wParam, $lParam)
;~ 	$tagMINMAXINFO = "struct;long;long;endstruct;" & _
;~                             "struct;long MaxSizeX;long MaxSizeY;endstruct;" & _
;~                             "struct;long MaxPositionX;long MaxPositionY;endstruct;" & _
;~                             "struct;long MinTrackSizeX;long MinTrackSizeY;endstruct;" & _
;~                             "struct;long MaxTrackSizeX;long MaxTrackSizeY;endstruct;"
	;#forceref $MsgID, $wParam
	If $hWnd = $ghForm1 Then ; the main GUI-limited
		Local $minmaxinfo = DllStructCreate("int;int;int;int;int;int;int;int;int;int", $lParam)
		DllStructSetData($minmaxinfo, 7, $gForm1_w) ; min width
		DllStructSetData($minmaxinfo, 9, $gForm1_w) ; max width
	EndIf
	Return 0
EndFunc   ;==>WM_GETMINMAXINFO
Func out($output = "", $timeout = 0) ;debug tool
	ConsoleWrite(@CRLF & $output) ;to console new line, value of $output
	;MsgBox(0, @ScriptName, $output, $timeout)
EndFunc   ;==>out
Func _ChangeWindowMessageFilterEx($hWnd, $iMsg, $iAction)
	Local $aCall = DllCall("user32.dll", "bool", "ChangeWindowMessageFilterEx", _
			"hwnd", $hWnd, _
			"dword", $iMsg, _
			"dword", $iAction, _
			"ptr", 0)
	If @error Or Not $aCall[0] Then Return SetError(1, 0, 0)
	Return 1
EndFunc   ;==>_ChangeWindowMessageFilterEx

; Loads: key name, send name, code pair list for keys
Func key_load($file_path = $gPath_system & "key_names.txt")
	Local $file = FileOpen($file_path)
	If $file > -1 Then
		$key_max = _FileCountLines($file_path) / $gKey_data_max
		ReDim $gaKey[$key_max + 1][$gKey_data_max]
		$gaKey[0][0] = $key_max
		For $i = 1 To $gaKey[0][0]
			$gaKey[$i][$eKey_code] = FileReadLine($file)
			$gaKey[$i][$eKey_name] = FileReadLine($file)
			$gaKey[$i][$eKey_send] = FileReadLine($file)
		Next
		FileClose($file)
		Return $gaKey
	Else
		MsgBox(0, $gScript_name & " Error", "Could not load Keyboard Setup file:" & @CRLF & _
				$file_path) ;, 0, $ghGui)
	EndIf
EndFunc   ;==>key_load

; Writes aHotKey_data to disk
Func hotkey_save($aHotKey_data = $gaHotKeyData)
	$sIniName = @ScriptDir & "\SoundBoard.ini"
	; Remove the file
	FileDelete($sIniName)
	; Write the new file
	For $i = 1 To $aHotKey_data[0][0]
		$x = IniWriteSection($sIniName, _
				"Sound" & $i, _
				'Hotkey="' & $aHotKey_data[$i][$eHotkey_sKey] & '"' & @CRLF & _
				'File="' & $aHotKey_data[$i][$eHotkey_sFile] & '"' & @CRLF & _
				'StartTime="' & $aHotKey_data[$i][$eHotKey_nStart] & '"' & @CRLF & _
				'EndTime="' & $aHotKey_data[$i][$eHotKey_nEnd] & '"' & @CRLF & _
				'PlaybackDevice="' & $aHotKey_data[$i][$eHotkey_sPlayback_device] & '"' & @CRLF & _
				'IsPressed="' & $aHotKey_data[$i][$eHotkey_ispressed] & '"' & @CRLF & _
				'Ctrl="' & $aHotKey_data[$i][$eHotKey_ctrl] & '"' & @CRLF & _
				'Alt="' & $aHotKey_data[$i][$eHotKey_alt] & '"' & @CRLF & _
				'Shift="' & $aHotKey_data[$i][$eHotKey_shift] & '"' & @CRLF & _
				'Win="' & $aHotKey_data[$i][$eHotKey_win] & '"')
	Next
EndFunc   ;==>hotkey_save

; Sorts aHotkey_data so that IsPressed hotkeys are first in list
Func hotkey_sort(ByRef $aHotKey_data)
	Local $aHotkey_data_temp = $aHotKey_data
	Local $mark_index[UBound($aHotKey_data)]

	; Unset Ult Hotkeys
	$aHotkey_data_temp[0][1] = 0

	; Search for Ult Hotkeys
	For $i = 1 To $aHotKey_data[0][0]
		If $aHotKey_data[$i][$eHotkey_ispressed] = $GUI_CHECKED Then
			; Count the Ult Hotkey
			$aHotkey_data_temp[0][1] += 1
			; Sort it to the beginning of array using the count above
			For $ii = 0 To $gKey_data_max - 1
				$aHotkey_data_temp[$aHotkey_data_temp[0][1]][$ii] = $aHotKey_data[$i][$ii]
			Next
		Else
			; Count the regular hotkey
			$mark_index[0] += 1
			; Mark the index to be used later
			$mark_index[$mark_index[0]] = $i
		EndIf
	Next

	; Add the regular hotkeys to the end of array
	For $i = 1 To $mark_index[0]
		For $ii = 0 To $gKey_data_max - 1
			$aHotkey_data_temp[$aHotkey_data_temp[0][1] + $i][$ii] = $aHotKey_data[$mark_index[$i]][$ii]
		Next
	Next
	; Copy temp to parameter
	$aHotKey_data = $aHotkey_data_temp
EndFunc   ;==>hotkey_sort
Func hotkey_activate()

	; Start passed the Ult (IsPressed) Hotkeys
	For $i = $gaHotKeyData[0][1] + 1 To $gaHotKeyData[0][0]

		;out("hotkey_activate: " & $i)
		HotKeySet($gaHotKeyData[$i][$eHotkey_sKey], "_HotKeyFunc")
	Next
EndFunc   ;==>hotkey_activate
