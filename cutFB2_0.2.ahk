; AutoHotkey Version: 1.0.47.06
; Language:           English, Russian
; Platform:           Windows
; Author:             Sven Karsten <sven_karsten@mail.ru>
;
; Script Function:	  Cutting FB2-files to parts

#NoEnv 
SendMode Input 
SetWorkingDir %A_ScriptDir% 

IfExist, input.fb2
	{
	FileRead, Inhalt, input.fb2
	OutNameNoExt = input
	SelectedFile = input.fb2
	}
else
	{
		FileSelectFile, SelectedFile, , , Open a file, eBooks (*.fb2)
		if SelectedFile =
			ExitApp
		else
			{
			SplitPath, SelectedFile, , OutDir, OutExtension, OutNameNoExt
			FileReadLine, Lang, %SelectedFile%, 1
			FileRead, Inhalt, %SelectedFile%
			
			SetWorkingDir %OutDir%
			}
	}
FileInstall, header.tmp, header.tmp
FileInstall, footer.tmp, footer.tmp

FileRead, Header, header.tmp
StringReplace, Header, Header, `r, , All
FileRead, Footer, footer.tmp

If Lang not contains utf-8,UTF-8
	StringReplace, Header, Header, <?xml version="1.0" encoding="UTF-8"?>, %Lang%

Title = cutFB2 v.0.2
Mess = Cut file`, please wait...
SetTimer, RefreshTrayTip, 500

; FileDelete, *_part_*.fb2
; FileDelete, *.tmp	

; Get book info
StringReplace, Inhalt, Inhalt, `r, , All
FoundPos := RegExMatch(Inhalt, "U)<title-info>(.*)</title-info>", InhaltA)
FoundPos := RegExMatch(InhaltA, "U)<book-title>(.*)</book-title>", BookTitle)
FoundPos := RegExMatch(InhaltA, "U)<author>(.*)</author>", BookAuthor)

; Find first lewel sections
	StringGetPos, BodyPosition, Inhalt, </body>
	Loop
		{
			Index = %A_Index%
			StringGetPos, Position, Inhalt, section, L%Index%
			If ErrorLevel = 1
				Break
			If Position > %BodyPosition%
				Break
			StringMid, Tag, Inhalt, %Position%, 8 
			If Tag = <section
				{
					Level++
					SecPos%Index% := Position
					SecTyp%Index% = open
					SecLevel%Index% = %Level%
					If SecLevel%Index% = 1
						Count++
				}
			Else If Tag = `/section
				{
					Position--
					SecPos%Index% := Position - 1
					SecTyp%Index% = close
					SecLevel%Index% = %Level%
					Level--
				}
				
			SecPosIndex := SecPos%Index%
			SecTypIndex := SecTyp%Index%
			SecLevelIndex := SecLevel%Index%
		}

	Index--
	Loop, %Index%
		{
			If SecLevel%A_Index% = 1
				{
					SecPosIndex := SecPos%A_Index%
					If SecTyp%A_Index% = close
						Inhalt := RegExReplace(Inhalt, "</section>", "          ", OutputVarCount, 1, SecPosIndex)
					If SecTyp%A_Index% = open
						Inhalt := RegExReplace(Inhalt, "<section>", "<CutHere>", OutputVarCount, 1, SecPosIndex)
					
				}
		}
			; Finde delimiter
		Loop, 255
			{
				Delimiter := Chr(A_Index)
				If Inhalt not contains %Delimiter%
					Break
				Delimiter := ~			
			}
	StringReplace, Inhalt, Inhalt, <CutHere>, %Delimiter%, All
	StringReplace, Inhalt, Inhalt, </body>, %Delimiter%, All
	StringSplit, Content, Inhalt, %Delimiter%
	Loop, %Content0%
		{
			ToSave := Content%A_Index%
			If ToSave contains <FictionBook
				FileAppend, %ToSave%, description.tmp
			else If ToSave contains <body name="notes"
				FileAppend, %ToSave%, notes.tmp
			else If ToSave contains </FictionBook>
				FileAppend, %ToSave%, binaries.tmp
			else If ToSave contains <p>
				{
					Counter++
					NewHeader = %Header%
					NewBookTitle = %BookTitle%
					StringReplace, NewBookTitle, NewBookTitle, </book-title>, _%Counter%</book-title>
					NewHeader := RegExReplace(NewHeader, "U)<book-title>(.*)</book-title>", NewBookTitle, OutputVarCount, 1, 1)
					NewHeader := RegExReplace(NewHeader, "U)<author>(.*)</author>", BookAuthor, OutputVarCount, 1, 1)
					FileAppend, %NewHeader%, %OutNameNoExt%_%Counter%.fb2
					FileAppend, %ToSave%, %OutNameNoExt%_%Counter%.fb2
					FileAppend, %Footer%, %OutNameNoExt%_%Counter%.fb2
				}
		}
	FileRead, Description, description.tmp
	FileRead, Notes, notes.tmp
	StringReplace, Notes, Notes, `r, , All
	FileRead, Binaries, binaries.tmp
	StringReplace, Binaries, Binaries, `r, , All
	FileDelete, *.tmp
	Loop, %Counter%
		{
			FileRead, Inhalt, %OutNameNoExt%_%A_Index%.fb2
			StringReplace, Inhalt, Inhalt, `r, , All
			Gosub, ImplementNotes
			Gosub, ImplementBinaries
			FileDelete, %OutNameNoExt%_%A_Index%.fb2
			FileAppend, %Inhalt%, %OutNameNoExt%_%A_Index%.fb2
		}
	ExitApp
	
RefreshTrayTip:
	Seconds++
	TrayTip, %Title%, %Mess% %Seconds%, , 17
	return
	
ImplementNotes:
IfNotInString, Inhalt, <body name="notes">	
	{
	Mess = Correct footnotes`, please wait...
	If Inhalt contains <a xmlns,<a l:href
		{
; Footnotes correction
		StringReplace, Inhalt, Inhalt, <a l:href, <a xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href, All
		FoundPos = 0
		newNoteBody =
		Loop
			{
				StringReplace, Inhalt, Inhalt, `r, , All
				StartPos := FoundPos + 1
				FoundPos := RegExMatch(Inhalt, "U)href([^/]*)</a>", Output, StartPos)
				If FoundPos = 0
					Break
				; Get link
				OutString = %Output%
				StringReplace, OutString, OutString, %A_Space%type="note", ,
				FoundPos2 := RegExMatch(OutString, "U)href=(.*)>", Link, 1)
				StringReplace, Link, Link, href=`"#, ,
				StringReplace, Link, Link, >, ,
				; Get footnote
				PosID := InStr(Notes, Link, false, 1)
				; PosID++
				; PosID := InStr(Notes, Link, false, PosID)
				FoundPos3 := RegExMatch(Notes, "U)</title>(.*)</section>", NoteText, PosID)
				StringReplace, NoteText, NoteText, </title>, ,
				StringReplace, NoteText, NoteText, </section>, ,	
				; Create new footnote
				newFootnote = <section id="%Link%>`n   <title>`n    <p>%A_Index%</p>`n   </title>`n   %NoteText%`n  </section>`n
				newNoteBody = %newNoteBody%	%newFootnote%
			}
		newNoteBody = <body name="notes">`n  <title>`n   <p>Notes</p>`n  </title>`n%newNoteBody%`n </body>
		StringReplace, Inhalt, Inhalt, </body>, </body>`n%newNoteBody%

		}
	}
	Gosub Renumber
	Return 
	
Renumber:
; Renumber footnotes
	FoundPos = 0
	id = %A_Now%
		Loop
			{
				Index = %A_Index%
				StartPos := FoundPos + 1
				FoundPos := RegExMatch(Inhalt, "U)<a xmlns(.*)</a>", Output, StartPos)
				If FoundPos = 0
					Break
				; Get link
				OutString = %Output%
				StringReplace, OutString, OutString, %A_Space%type="note", ,
				FoundPos2 := RegExMatch(OutString, "U)href=(.*)>", Link, 1)
				StringReplace, Link, Link, href=`"#, ,
				StringReplace, Link, Link, >, ,

				; Replace old link adress with new one
				If Output contains %A_Space%type="note"
					Replacer = xlink:href="#id%id%_%Index%">[%Index%`]</a>
				Else
					Replacer = xlink:href="#id%id%_%Index%" type="note">[%Index%`]</a>
				Output1 := RegExReplace(Output, "xlink:href=(.*)</a>", Replacer, Count, 1, 1)
				StringReplace, Inhalt, Inhalt, %Output%, %Output1%
				
				; Search and replace second link adress in the footnote
				Replacer = id%id%_%Index%`"
				StringReplace, Inhalt, Inhalt, %Link%, %Replacer%
				
				; Get begin position of the footnote
				NewLink = id`=`"%Replacer%
				NewLinkPos := InStr(Inhalt, NewLink, false, 1)
			
				; Replace old footnote's number with new one
				FoundPos6 := RegExMatch(Inhalt, "U)<title>(.*)</title>", NoteTitleText, NewLinkPos)
				
				Replacer = <title>`n    <p>%Index%</p>`n   </title>
				Inhalt := RegExReplace(Inhalt, NoteTitleText, Replacer, Count, 1, NewLinkPos)
				
			}
	Return
	
ImplementBinaries:
	Mess = Correct pictures`, please wait...
	If Inhalt contains <image xmlns, <image l
		{
; Binaries correction
		FoundPos = 0
		newPicBody =
		Loop
			{
				StringReplace, Inhalt, Inhalt, `r, , All
				StartPos := FoundPos + 1
				FoundPos := RegExMatch(Inhalt, "U)href([^/]*)/>", Link, StartPos)
				If Link contains excerpt.jpg
					Continue 
				If FoundPos = 0
					Break
				; Get link
				StringReplace, Link, Link, href=`"#, ,
				StringReplace, Link, Link, />, ,
				; Get picture
				
				PosID := InStr(Binaries, Link, false, 1)
				/*
				PosID++
				NotLink = id`=`"anthology.jpg`"
				If Notes contains %NotLink%
					{
						PosID := InStr(Notes, NotLink, false, PosID)
						PosID++
					}
				PosID := InStr(Notes, Link, false, PosID)
				*/
				FoundPos3 := RegExMatch(Binaries, "U)content-type(.*)</binary>", PicText, PosID)
				If PicText contains anthology.jpg
				{
					PosID++
					FoundPos3 := RegExMatch(Binaries, "U)content-type(.*)</binary>", PicText, PosID)
				}
				; Create new binary
				newBinary = <binary id="%Link% %PicText% `n
				newPicBody = %newPicBody%%newBinary%
			}
		StringReplace, Inhalt, Inhalt, </FictionBook>, `n%newPicBody%</FictionBook>

		}
	Return 