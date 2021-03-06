$PBExportHeader$w_main.srw
forward
global type w_main from window
end type
type st_3 from statictext within w_main
end type
type cb_4 from commandbutton within w_main
end type
type sle_dir from singlelineedit within w_main
end type
type st_2 from statictext within w_main
end type
type cb_3 from commandbutton within w_main
end type
type cb_export from commandbutton within w_main
end type
type st_1 from statictext within w_main
end type
type dw_review from datawindow within w_main
end type
type dw_list from datawindow within w_main
end type
type sle_pbd from singlelineedit within w_main
end type
type cb_load from commandbutton within w_main
end type
type strc_nod_tree from structure within w_main
end type
end forward

type strc_nod_tree from structure
	unsignedlong		nod_addr
	unsignedlong		next_left
	unsignedlong		next_right
	boolean		flag
end type

global type w_main from window
integer width = 3017
integer height = 1876
boolean titlebar = true
string title = "Recovery Datawindow From PBD"
boolean controlmenu = true
boolean minbox = true
boolean maxbox = true
long backcolor = 67108864
string icon = "AppIcon!"
boolean center = true
st_3 st_3
cb_4 cb_4
sle_dir sle_dir
st_2 st_2
cb_3 cb_3
cb_export cb_export
st_1 st_1
dw_review dw_review
dw_list dw_list
sle_pbd sle_pbd
cb_load cb_load
end type
global w_main w_main

forward prototypes
public subroutine wf_getlistdw (string as_pbd)
public function blob wf_unicode_ansi (blob lb)
public function unsignedlong wf_get_hdr (integer ihandle)
end prototypes

public subroutine wf_getlistdw (string as_pbd);//get dwo name list
//get dwo list from ent band

//open file
Int iFileHandle
Blob bread
Boolean isUnicode = False
ULong ul_NOD_OFFSET //process current NOD
ULong ul_NEXT_NOD_OFFSET = 1024 //default first NOD 0x400H
ULong ul_LenOfObjName_OFFSET = 22 //dwo name's index of ENT*
ULong ul_LenOfENTBand = 3040
ULong ul_LenOfObjectInfo = 28 //<=9: 24     >=10:28
String ls_objname
ULong ul_fileLen
Long hdr_offset
ULong ul_LenOfObjName
ULong ul_obj_OFFSET
ULong ll_obj = 0 //init once
String ls_filetype

strc_nod_tree Nod_List[],NULL_ARR[] //array list

Int ifr //index file round-for
Int i //index Nod_List round-for

dw_list.reset()
//beginning file ,reset variable
ul_NEXT_NOD_OFFSET = 1024 //will be change,so init at beginning.
ul_LenOfObjName_OFFSET = 22 //will be change,so init at beginning.

//len file,before openfile function
ul_fileLen = FileLength(as_pbd)


//note:must be shared! FILE-LOCK-MODE,else,after restart() event,cannt open the file.important this.
iFileHandle = FileOpen(as_pbd,StreamMode!,Read!,Shared! )

If iFileHandle < 1 Then
	MessageBox("Open Error","Cannt open file: " + as_pbd)
	Return
End If

//get hdr offse
//find the hdr if dll
hdr_offset = 0

//dll or pbd file type 
ls_filetype = Lower(Right(as_pbd,4))

If ls_filetype = ".dll" Or ls_filetype = ".exe" Then
	//file seek to RTL FromEnd!
	FileSeek(iFileHandle, -512,FromEnd!)
	FileRead(iFileHandle,bread)
	
	hdr_offset = Long(BlobMid(bread,5,4))
End If

//1.ansi or unicode
FileSeek(iFileHandle,hdr_offset,FromBeginning!)
FileRead(iFileHandle,bread)

//the fifth char is "00" then it's unicode
If Integer(BlobMid(bread,5,2)) = 80 Then //0x0050H
	isUnicode = True
	ul_NEXT_NOD_OFFSET = 1536 //0x600H
	ul_LenOfObjName_OFFSET = 26
End If

//get next NOD address
ul_LenOfObjName = 0
ul_obj_OFFSET = 0

//find all NOD bands
Nod_List[UpperBound(Nod_List)+1].NOD_addr = hdr_offset + ul_NEXT_NOD_OFFSET //first add the "hdr_offset",others not,they are Absolute address
Nod_List[UpperBound(Nod_List)].flag = False //Two values(next-NODE) are not read


For i = 1 To UpperBound(Nod_List) //upper limit will change,not a fixed value
	If Not Nod_List[i].flag Then
		//find left-NOD tree
		ul_NOD_OFFSET = Nod_List[i].NOD_addr
		
		FileSeek(iFileHandle,ul_NOD_OFFSET,FromBeginning!)
		FileRead(iFileHandle,bread)
		ul_NEXT_NOD_OFFSET = Long(BlobMid(bread,5,4))
		
		If ul_NEXT_NOD_OFFSET > 0 And ul_NEXT_NOD_OFFSET < ul_fileLen - 512 Then
			Nod_List[UpperBound(Nod_List)+1].NOD_addr = ul_NEXT_NOD_OFFSET
			Nod_List[UpperBound(Nod_List)].flag = False //Two values(next-NODE) are not read
		End If
		
		//find right-NOD tree
		ul_NEXT_NOD_OFFSET = Long(BlobMid(bread,13,4))
		
		If ul_NEXT_NOD_OFFSET > 0 And ul_NEXT_NOD_OFFSET < ul_fileLen - 512  Then
			Nod_List[UpperBound(Nod_List)+1].NOD_addr = ul_NEXT_NOD_OFFSET
			Nod_List[UpperBound(Nod_List)].flag = False //Two values(next-NODE) are not read
		End If
		
		//set flag
		Nod_List[i].flag = True;
		//Two values(Current-NODE) are read
	End If
Next


For i = 1 To UpperBound(Nod_List)
	//address of NOD
	ul_NOD_OFFSET = Nod_List[i].NOD_addr
	
	//ENT list
	//not add hdr_offset,they are Absolute address
	FileSeek(iFileHandle,ul_NOD_OFFSET+32,FromBeginning!)
	FileRead(iFileHandle,bread)
	
	//round to get ent list	
	ul_obj_OFFSET = 0
	
	Do While(ul_obj_OFFSET < ul_LenOfENTBand -ul_LenOfObjectInfo)
		ul_LenOfObjName = 0
		ul_LenOfObjName = Integer(BlobMid(bread,ul_obj_OFFSET +	ul_LenOfObjName_OFFSET + 1,2))
		//break when ls_objname is null.
		If ul_LenOfObjName = 0 Then Exit
		
		If isUnicode Then
			ls_objname = String(BlobMid(bread,ul_obj_OFFSET + ul_LenOfObjName_OFFSET + 2 + 1,ul_LenOfObjName),EncodingUTF16LE!) //especial:encoding
		Else
			ls_objname = String(BlobMid(bread,ul_obj_OFFSET + ul_LenOfObjName_OFFSET + 2 + 1,ul_LenOfObjName),EncodingANSI!) //especial:encoding
		End If
		
		
		If Right(ls_objname,4) = ".dwo" Then
			ll_obj = dw_list.InsertRow(0)
			dw_list.SetItem(ll_obj, "dwname",Left(ls_objname,Len(ls_objname) -4) )
			dw_list.SetItem(ll_obj, "dwlib",as_pbd)
		End If
		
		ul_obj_OFFSET += ul_LenOfObjName_OFFSET + 2 + ul_LenOfObjName
	Loop
Next

FileClose(iFileHandle) //must!,else not be:setlibrarylist

//reset array
Nod_List = NULL_ARR


end subroutine

public function blob wf_unicode_ansi (blob lb);blob lb_ret

int li_len
int i,k

li_len = len(lb) - 1
for i = 1 to li_len step 2
	if integer(blobmid(lb,i,2))<256 then
		lb_ret +=blobmid(lb,i,1)
	else
		lb_ret +=blobmid(lb,i,2)
	end if	
next

return lb_ret
end function

public function unsignedlong wf_get_hdr (integer ihandle);//find the hdr if dll
long hdr_offset

//file seek to RTL FromEnd!
FileSeek(ihandle,508,FromEnd!)

return hdr_offset


end function

on w_main.create
this.st_3=create st_3
this.cb_4=create cb_4
this.sle_dir=create sle_dir
this.st_2=create st_2
this.cb_3=create cb_3
this.cb_export=create cb_export
this.st_1=create st_1
this.dw_review=create dw_review
this.dw_list=create dw_list
this.sle_pbd=create sle_pbd
this.cb_load=create cb_load
this.Control[]={this.st_3,&
this.cb_4,&
this.sle_dir,&
this.st_2,&
this.cb_3,&
this.cb_export,&
this.st_1,&
this.dw_review,&
this.dw_list,&
this.sle_pbd,&
this.cb_load}
end on

on w_main.destroy
destroy(this.st_3)
destroy(this.cb_4)
destroy(this.sle_dir)
destroy(this.st_2)
destroy(this.cb_3)
destroy(this.cb_export)
destroy(this.st_1)
destroy(this.dw_review)
destroy(this.dw_list)
destroy(this.sle_pbd)
destroy(this.cb_load)
end on

type st_3 from statictext within w_main
integer x = 37
integer y = 1696
integer width = 2926
integer height = 64
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 67108864
string text = "Note: use excute directly, if running directly from powerbuilder, add pbd or dll to library list"
boolean focusrectangle = false
end type

type cb_4 from commandbutton within w_main
integer x = 2560
integer y = 120
integer width = 123
integer height = 100
integer taborder = 10
integer textsize = -9
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "..."
end type

event clicked;String ls_path
Integer li_result

ls_path = sle_dir.Text

li_result = GetFolder( "Choose Folder", ls_path )

If Len(ls_path) > 0 Then
	sle_dir.Text = ls_path
End If


end event

type sle_dir from singlelineedit within w_main
integer x = 219
integer y = 128
integer width = 2341
integer height = 84
integer taborder = 20
integer textsize = -9
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
borderstyle borderstyle = stylelowered!
end type

type st_2 from statictext within w_main
integer x = 37
integer y = 128
integer width = 183
integer height = 64
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 67108864
string text = "DIR:"
alignment alignment = right!
boolean focusrectangle = false
end type

type cb_3 from commandbutton within w_main
integer x = 2560
integer y = 24
integer width = 123
integer height = 100
integer taborder = 20
integer textsize = -9
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "..."
end type

event clicked;String ls_path, ls_file
Int li_rc

ls_path = sle_pbd.Text
li_rc = GetFileSaveName ( "Select File",   ls_path, ls_file, "pbd",  "PBD (*.pbd),*.pbd,Dll (*.dll),*.dll,Exe (*.exe),*.exe,All Files (*.*),*.*" )

If li_rc = 1 Then
	sle_pbd.Text = ls_path
End If

end event

type cb_export from commandbutton within w_main
integer x = 2706
integer y = 120
integer width = 233
integer height = 100
integer taborder = 20
integer textsize = -9
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Export"
end type

event clicked;
Int writetimes
Long ll_write_wait
UInt ui_unicodeFlag = 65279 //oxFEFF
Blob wb
String ls_syntax, ls_DataInside
Int li_row, li_filenum, wi
String ls_dir
String ls_dwname, ls_chk

ls_dir = sle_dir.Text
If IsNull(ls_dir) Or Len(Trim(ls_dir)) = 0 Then
	MessageBox("Warning", "Dir Is Null")
	Return
End If

For li_row = 1 To dw_list.RowCount()
	ls_chk = dw_list.GetItemString(li_row, "chk" )
	ls_dwname = dw_list.GetItemString(li_row, "dwname" )
	If IsNull(ls_chk) Or Len(Trim(ls_chk)) = 0 Then  ls_chk = ""
	If ls_chk <> "Y" Then Continue
	If IsNull(ls_dir) Or Len(Trim(ls_dir)) = 0 Then  Continue
	
	Try //to catch "unresolvable external func_nam when linek reference" error! used global function error messagebox
		dw_review.DataObject = ls_dwname
	Catch(runtimeerror rte)
	End Try
	
	//note: unicode ahead"_"  replace unicode-file-flag
	ls_syntax = "_$PBExportHeader$" + ls_dwname + ".srd~r~n" + dw_review.Describe('datawindow.syntax')
	ls_DataInside = dw_review.Describe('datawindow.syntax.data')
	If ls_DataInside <> "data()" Then
		ls_syntax += "~r~n" + ls_DataInside
	End If
	
	wb =  Blob(ls_syntax,EncodingUTF16LE!) //not be EncodingANSI!)
	//unicode file,insert flag at beginning.
	BlobEdit(wb,1,ui_unicodeFlag)
	
	ll_write_wait = Len(wb)
	writetimes = Ceiling(ll_write_wait/32765.0)
	
	//open and new file to write srd.
	li_filenum = FileOpen(ls_dir + "\" +  ls_dwname + ".srd", 	StreamMode!, Write!,LockReadWrite!,Replace!)
	If li_filenum < 1 Then Continue
	If(writetimes = 1) Then
		FileWrite(li_filenum,wb)
	Else
		For wi = 1 To writetimes
			FileSeek(li_filenum, 0, FromEnd!)
			If wi < writetimes Then
				FileWrite(li_filenum,BlobMid(wb,32765*(wi -1)+1,32765))
				ll_write_wait -= 32765
			Else
				FileWrite(li_filenum,BlobMid(wb,32765*(wi -1)+1,ll_write_wait))
			End If
		Next
	End If

	FileClose(li_filenum)
Next


MessageBox("Warning", "Success")


end event

type st_1 from statictext within w_main
integer x = 37
integer y = 32
integer width = 183
integer height = 64
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 67108864
string text = "PBD:"
alignment alignment = right!
boolean focusrectangle = false
end type

type dw_review from datawindow within w_main
integer x = 1280
integer y = 256
integer width = 1682
integer height = 1408
integer taborder = 30
string title = "none"
boolean hscrollbar = true
boolean vscrollbar = true
boolean livescroll = true
borderstyle borderstyle = stylelowered!
end type

type dw_list from datawindow within w_main
integer x = 37
integer y = 256
integer width = 1207
integer height = 1408
integer taborder = 20
string title = "none"
string dataobject = "d_dwlist"
boolean hscrollbar = true
boolean vscrollbar = true
boolean livescroll = true
borderstyle borderstyle = stylelowered!
end type

event rowfocuschanged;dw_review.SetRedraw(False)
Try
	dw_review.DataObject = this.getitemstring(currentrow, "dwname")
Catch(runtimeerror rte)
End Try

dw_review.InsertRow(0)
dw_review.InsertRow(0)
//some form style dw,the foreground and background,color is white all.be seen nothing.
dw_review.SetFocus()
dw_review.SetRow(1)
dw_review.SetColumn(1)
dw_review.SetRedraw(True)

end event

event constructor;Long ll_column
String ls_color, ls_border,ls_dw_color

ls_dw_color = This.Describe("datawindow.color")
ls_color  = "0~t if(getrow()=currentrow(), 29935871, "+ls_dw_color+")"
ls_border = "0~t if(getrow()=currentrow(), 5, 0)"

For ll_column = 1 To Long(This.Object.datawindow.column.count)
	If  ll_column > 1 Then
		This.Modify("#"+String(ll_column)+".background.color = '"+ls_color+"'")
		This.Modify("#"+String(ll_column)+".border           = '"+ls_border+"'")
	End If
Next
end event

event clicked;String ls_chk, ls_chkall
Long ll_row
Long ll_found

Choose Case dwo.Name
	Case "chkall"
		If This.RowCount() = 0 Then Return
		ls_chkall = This.GetItemString(1, "chkall")
		If IsNull(ls_chkall) Or Len(Trim(ls_chkall)) = 0 Then ls_chkall = "N"
		If ls_chkall = "N" Then
			ls_chkall = "Y"
		Else
			ls_chkall = "N"
		End If
		For ll_row = 1 To This.RowCount()
			This.SetItem(ll_row, "chk", ls_chkall)
		Next
		This.SetItem(1, "chkall", ls_chkall)
		
End Choose
end event

event itemchanged;Long ll_found

Choose Case dwo.Name
	Case "chk"
		If This.RowCount() = 0 Then Return
		If Data = "Y" Then
			If row > 1 And row < This.RowCount() Then
				ll_found = This.Find(  "chk = 'N'",  1, row -1) +  This.Find(  "chk = 'N'",  row + 1, This.RowCount())
			Else
				If row = 1 Then
					ll_found = This.Find(  "chk = 'N'",  2, This.RowCount())
				Else
					ll_found = This.Find(  "chk = 'N'",  1, This.RowCount() - 1)
				End If
			End If
			If ll_found = 0 Then
				This.SetItem(1, "chkall", "Y")
			Else
				This.SetItem(1, "chkall", "N")
			End If
		Else
			This.SetItem(1, "chkall", "N")
		End If
End Choose


end event

type sle_pbd from singlelineedit within w_main
integer x = 219
integer y = 32
integer width = 2341
integer height = 84
integer taborder = 10
integer textsize = -9
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
borderstyle borderstyle = stylelowered!
end type

type cb_load from commandbutton within w_main
integer x = 2706
integer y = 24
integer width = 233
integer height = 100
integer taborder = 10
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Load"
end type

event clicked;String ls_pbd

ls_pbd = sle_pbd.Text

If IsNull(ls_pbd) Or Len(Trim(ls_pbd)) = 0 Then
	MessageBox("Warning", "Lib Is Null")
	Return
End If

wf_getlistdw(ls_pbd)

// already compiled 
If Handle(GetApplication()) <> 0 Then
	String ls_librarylist, ls_library
	Int li_FileNum
	ls_librarylist = GetLibraryList ()
	ls_library =ls_pbd
	If IsNull(ls_library) Then ls_library = ""
	If Len(ls_library) <= 0 Then Return
	If Pos(ls_librarylist,ls_library) > 0 Then Return
	AddToLibraryList(ls_library)
	
End If
end event

