#define fbc -s gui copycopypastepaste.rc

#include "windows.bi"
#include "win\shellapi.bi"

#define sAppName "copycopypastepaste"

enum MenuID
  miStart 
  miQuit
end enum

dim shared as NOTIFYICONDATA tNotify
dim shared as HINSTANCE AppInstance
dim shared as HWND hMsgWnd = any, hNextWnd = null
dim shared as HICON hTrayBitmap = any
dim shared as HICON hTrayIcon = any
dim shared as HGLOBAL pCurObj , pOldObj
dim shared as ULONG uCurFmt , uOldFmt
dim shared as hwnd uCurWnd , uOldWnd
dim shared as HMENU hContext
dim shared as integer iIgnoreClipboard
dim shared as integer iVkPasteEx

sub FatalError( pzMessage as zstring ptr )
  Messagebox(null,pzMessage,sAppName, MB_SYSTEMMODAL or MB_ICONERROR)
  ExitProcess(1)
end sub
function GlobalClone(hMem as handle) as handle
  if hMem = null then return null
  var iSz = GlobalSize( hMem )
  if iSz = 0 then return null
  var hResu = GlobalAlloc( GMEM_MOVEABLE , iSz )
  var pIn = GlobalLock( hMem )
  var POut = GlobalLock( hResu )
  memcpy( pOut , pIn , iSz )
  GlobalUnlock( hMem )
  GlobalUnlock( hResu )
  return hResu
end function
function GetStartupState() as integer
  dim as HKEY hRunKey = any
  dim as DWORD dwType = 0   
  var iResu = RegOpenKeyEx( HKEY_LOCAL_MACHINE , "SOFTWARE\Microsoft\Windows\CurrentVersion\Run" , 0 , KEY_QUERY_VALUE , @hRunKey )
  if iResu <> ERROR_SUCCESS then return 0
  iResu = RegQueryValueEx( hRunKey , sAppName , null , @dwType , null , null )
  RegCloseKey( hRunKey)
  if iResu <> ERROR_SUCCESS or dwType<>REG_SZ then return 0  
  return 1
end function
sub SetStartupState( iStart as integer )
  dim as HKEY hRunKey = any
  dim as DWORD dwType = 0   
  
  var iResu = RegOpenKeyEx( HKEY_LOCAL_MACHINE , "SOFTWARE\Microsoft\Windows\CurrentVersion\Run" , 0 , KEY_SET_VALUE , @hRunKey )
  if iResu <> ERROR_SUCCESS then exit sub  
  
  if iStart then
    dim as wstring*4096 wThisApp = any
    wThisApp[ 0 ] = asc("""")
    var iLen = GetModuleFileNameW( AppInstance , @wThisApp+1 , 4092 )
    wThisApp[ iLen+1 ] = asc("""") : wThisApp[ iLen+2 ] = 0      
    RegSetValueExW( hRunKey , sAppName , null , REG_SZ , cast(byte ptr,@wThisApp) , (iLen+3)*sizeof(wstring) )    
  else    
    RegDeleteValueW( hRunKey , sAppName )        
  end if
  
  RegCloseKey( hRunKey )
  
end sub

function MsgProc ( hwnd as HWND , uMsg as ulong , wParam as WPARAM , lParam as LPARAM ) as LRESULT
  select case uMsg
  case WM_CHANGECBCHAIN    
    if cast(HWND,wParam) = hNextWnd then
      hNextWnd = cast(HWND,lParam)    
    elseif hNextWnd <> NULL then
      SendMessage(hNextWnd, uMsg, wParam, lParam)
    end if  
    return 0
  case WM_DRAWCLIPBOARD     
    if iIgnoreClipboard=0 andalso IsClipboardFormatAvailable( CF_UNICODETEXT ) then
      if OpenClipboard( hMsgWnd ) then      
        if pOldObj then GlobalFree( pOldObj ): pOldObj = null      
        uOldFmt = uCurFmt: pOldObj = pCurObj: uOldWnd = uCurWnd      
        uCurFmt = CF_UNICODETEXT 'EnumClipboardFormats( null )
        pCurObj = GlobalClone( GetClipboardData( uCurFmt ) )
        CloseClipboard()
      end if
    end if 
    SendMessage(hNextWnd, uMsg, wParam, lParam)
  case WM_DESTROY
     ChangeClipboardChain( hMsgWnd , hNextWnd )
     hMsgWnd = null
  case WM_HOTKEY
    if wParam = &hBEEF then
      iIgnoreClipboard = 1
      BlockInput( True )
      
      var hWnd = iif(uOldWnd=0,hMsgWnd,uOldWnd)
      if OpenClipboard( hWnd ) then
        if EmptyClipboard() then
          var hNew = GlobalClone( pOldObj )        
          if SetClipBoardData( uOldFmt , hNew )=0 then
            if hNew then GlobalFree( hNew )
          end if
        end if
        CloseClipboard()
                
        dim as INPUT_ aInput(1) = any      
        aInput(0).Type = INPUT_KEYBOARD
        aInput(0).ki = type( asc("V")   , 0 , 0 , 0 , 0 )
        aInput(1).Type = INPUT_KEYBOARD
        aInput(1).ki = type( asc("V")   , 0 , KEYEVENTF_KEYUP , 0 , 0 )
        SendInput( 2 , @aInput(0) , sizeof(INPUT_) )
        
        BlockInput( False )
        
        var OldPriority = GetPriorityClass(GetCurrentProcess())
        SetPriorityClass(GetCurrentProcess(),BELOW_NORMAL_PRIORITY_CLASS)
        sleepEx 5,1
        while (GetAsyncKeyState(iVkPasteEx) shr 15)
          SleepEx 1,1
        wend
        SetPriorityClass(GetCurrentProcess,OldPriority)
                
        hWnd = iif(uCurWnd=0,hMsgWnd,uCurWnd)
        if OpenClipboard( hWnd ) then 
          if EmptyClipboard() then
            var hNew = GlobalClone( pCurObj )
            if SetClipBoardData( uCurFmt , hNew )=0 then
              if hNew then GlobalFree( hNew )
            end if
          end if
          CloseClipboard()
        end if
        
      end if
      
      BlockInput( False )
      iIgnoreClipboard = 0
    end if
  case WM_APP+1    
    if lParam = WM_LBUTTONUP or lParam = WM_RBUTTONUP then
      dim as POINT CurPt : GetCursorPos( @CurPt )
      const TPMFlags = TPM_CENTERALIGN or TPM_VCENTERALIGN or TPM_RIGHTBUTTON or TPM_RETURNCMD 
      SetForegroundWindow( hMsgWnd )
      var uResu = TrackPopupMenu( hContext , TPMFlags , CurPt.x , CurPt.y , null , hMsgWnd , null )
      PostMessage( hMsgWnd , WM_NULL , 0 , 0 )
      Select case uResu
      case MiStart
        dim as MENUITEMINFO tInfo = type( sizeof(tInfo) , MIIM_STATE )
        GetMenuItemInfo( hContext , MiStart , false , @tInfo )
        SetStartupState( (tInfo.fState and MFS_CHECKED)=0 )
        tInfo.fState = iif(GetStartupState(),MF_CHECKED,MF_UNCHECKED)
        SetMenuItemInfo( hContext , MiStart , false , @tInfo )        
      case MiQuit
        PostQuitMessage(0)
      end select      
    end if
  case else
    return DefWindowProc( hwnd , uMsg , wParam , lParam )
  end select
end function

sub InitProgram() constructor

  dim as WNDCLASS tWndClass
  AppInstance = GetModuleHandle(null)
  hTrayIcon = LoadIcon(AppInstance,MAKEINTRESOURCE(1))    
  
  with tWndClass
    .style = 0
    .lpfnWndProc = @MsgProc
    .hInstance = AppInstance
    .lpszClassName = @sAppName
  end with
  
  if RegisterClass( @tWndClass )=0 then    
    FatalError( "Failed to register Window Class" )
  end if  
  
  hMsgWnd = CreateWindow(sAppName,null,0,0,0,0,0,HWND_MESSAGE,null,AppInstance,null)
  if hMsgWnd = 0 then
    FatalError( "Failed to create window" )
  end if
  
  var wKey = VkKeyScan(asc("<")), uMod = MOD_CONTROL
  if (wKey and &h100) then uMod or= MOD_SHIFT
  if (wKey and &h400) then uMod or= MOD_ALT
  iVkPasteEx = wKey and &hFF
  if RegisterHotKey( hMsgWnd , &hBEEF , uMod , iVkPasteEx ) = 0 then
    FatalError( !"Could not create the global hotkey\r\n" _
    !"Is there already a instance of the program running?" )
  end if
  
  hContext = CreatePopupMenu()
  var MF_STATE = MF_STRING or (iif(GetStartupState(),MF_CHECKED,MF_UNCHECKED))
  AppendMenu( hContext , MF_STATE , miStart , "&Start with Windows" )
  AppendMenu( hContext , MF_STRING , miQuit , "&Quit" )
  
  with tNotify
    .cbSize = sizeof(NOTIFYICONDATA)
    .hWnd = hMsgWnd
    .uID = cast(ULONG,hMsgWnd)
    .uFlags = NIF_ICON or NIF_MESSAGE
    .hIcon = hTrayIcon
    .uCallbackMessage = WM_APP+1
  end with
  
  Shell_NotifyIcon( NIM_ADD , @tNotify )     

  hNextWnd = SetClipboardViewer( hMsgWnd )
  if hNextWnd=null andalso GetLastError=0  then
    FatalError( "Error, failed to start the application." )
  end if
  
end sub
sub FinishProgram() destructor
  if tNotify.hWnd then
    Shell_NotifyIcon( NIM_DELETE , @tNotify )
    tNotify.hWnd = null
  end if
  
  if hMsgWnd then UnregisterHotKey( hMsgWnd , &hBEEF )
  if hMsgWnd then DestroyWindow( hMsgWnd ): hMsgWnd = null
  
  if pCurObj then GlobalFree( pCurObj ) : pCurObj = null
  if pOldObj then GlobalFree( pOldObj ) : pOldObj = null
  
  
end sub

dim as MSG msg = any
while GetMessage( @msg, null, 0, 0 )
  TranslateMessage(@msg)
  DispatchMessage(@msg)
wend  
