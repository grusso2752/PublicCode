'--------------------------------------------------------------------
' Portswitch.vbs
' Usage: Portswitch (HTTP port number)
' Example:Portswitch 1337
' (c) Microsoft Corporation. All rights reserved.
'
' This script will set the HTTP port on which the
' ConfigMgr Advanced Client will use to communicate with the Management Point.
' This script is intended to be used with software distribution.
' Because file associations can change it is recommended that you execute portswitch.vbs in the
' following way:
'
' The command line provided in the package's program should be "wscript.exe portswitch.vbs
' (HTTP port number) (optional: HTTPS port number)"
'
' Example: "Wscript.exe portswitch.vbs 1337 31337"
'
'
' To properly generate pass/fail status for software distribution you must do the following:
' 1) In the ConfigMgr package, set the MIF matching properties to the following:
'      MIF Filename:  "Portswitch.mif"
' 2) In the ConfigMgr Program, you must specify that the "Program will reboot"
'      (this is because CCMExec restarts)
'
'--------------------------------------------------------------------

Dim objShell 'This establishes the variable Shell that will become the WScript.Shell object.
Dim nPortValue, nSslPortValue, nReadValue 'Holds the value passed as a command argument
Dim CCMService

Const EVENT_SUCESS = 0
Const EVENT_FAILED = 2

Const Reg_PortKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\CCM\HttpPort" 'Set constant as the registry path to the desired key.
Const Reg_PortKeySSL = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\CCM\HttpsPort" 'SSL port for ConfigMgr client

' Create a WScript.Shell oject
Set objShell = Wscript.CreateObject("Wscript.Shell")

' check the argument count
iNumberOfArguments = Wscript.Arguments.Count
If iNumberOfArguments > 2 or iNumberOfArguments < 1 Then
    objShell.LogEvent EVENT_FAILED, _
            "Portswitch.vbs was executed with no specified port. " & _
            "Usage: Portswitch (HTTP port number) " & _
            "(optional HTTPS port number). Examples: ""Portswitch 8080"" or ""PortSwitch 8080 8443""" 
    FailAndQuit
End if

On Error Resume Next
' Validate the port arguments, and set the ports in the registry
nPortValue = CLng(Wscript.Arguments.Item(0))
ValidatePort nPortValue

' If we have an SSL port, validate it, too.
If iNumberOfArguments = 2 Then
    nSslPortValue = CLng(Wscript.Arguments.Item(1))
    If nSslPortValue = nPortValue Then
        objShell.LogEvent EVENT_FAILED, _
            "Portswitch.vbs had an invalid port specification: HTTP and HTTPS ports cannot be identical."
        FailAndQuit
    End If

    ValidatePort nSslPortValue
    WriteRegKey Reg_PortKeySSL, nSslPortValue
End If

WriteRegKey Reg_PortKey, nPortValue

Set objWmiservice = GetObject("winmgmts:root\cimv2:Win32_Service.Name=""CCMExec""")

' Stop the CCMExec so the port change may be picked up by the client.
errReturnCode = objWMIService.StopService()

If errReturnCode <> 0 Then
    objShell.LogEvent EVENT_FAILED, _
        "Portswitch.vbs was unable to stop the CCMExec service: (Err=" & errReturnCode & ")"
    FailAndQuit
End If

' Wait for the ccmexec service to stop  (to a maximum of 10 minutes)
Dim dWaitUntil
dWaitUntil = DateAdd("n", 10, Now)
Do While (objWMIService.InterrogateService() <> 6) And (Now < dWaitUntil)
    ' The service is still running
    WScript.Sleep 1000
Loop

' Did the service stop?
If objWMIService.InterrogateService() <> 6 then
    objShell.LogEvent EVENT_FAILED, _
        "Portswitch.vbs timed out trying to stop the CCMExec service after 3 minutes."
    FailAndQuit
End If

If Err.number <> 0 Then
    objShell.LogEvent EVENT_FAILED, _
    "Portswitch.vbs - An error occured: " & Err.Description
    FailAndQuit
End If

' Generate a success status mif
WriteStatusMIF(true)

' Starting CCMExec so the port change may be picked up by the client.
errReturnCode = objWMIService.StartService ()
If iNumberOfArguments = 2 Then
    objShell.LogEvent EVENT_SUCCESS, _
        "The ConfigMgr Advanced Client has been successfully set to communicate with the MP on ports " & nPortValue & " (HTTP) and " & nSslPortValue & " (HTTPS)"
Else
    objShell.LogEvent EVENT_SUCCESS, _
        "The ConfigMgr Advanced Client has been successfully set to communicate with the MP on port " & nPortValue
End If

WScript.Quit(0)
' -----------------------------

ErrorHandler:
    objShell.LogEvent EVENT_FAILED, _
        "Portswitch failed with an internal error: " & Err.Description
    FailAndQuit

' -----------------------------
Sub ValidatePort(nPort)
    If Err.number <> 0 Then
        objShell.LogEvent EVENT_FAILED, _
            "Portswitch.vbs - An invalid port number was specified  (Valid ports are 1-65535). " & _
            "Usage: Portswitch (HTTP port number) Example: Portswitch 8080"
        FailAndQuit
    End If

    ' Check the port value
    If nPort  < 1 or nPort > 65535 then
        objShell.LogEvent EVENT_FAILED, _
            "Portswitch.vbs was executed with an invalid port number (" & nPort & "). Port numbers must fall " & _
            "between 1-65535 Usage: Portswitch (HTTP port number) Example: Portswitch 8080"
        FailAndQuit
    End if
End Sub

' -----------------------------
Sub WriteRegKey(sRegKey, nPort)
    nReadValue = objShell.RegRead(sRegKey)
    If nReadValue then
        ' Write current path to registry key and read it to become constant for script.
        objShell.RegWrite (sRegKey), nPort, "REG_DWORD"
        nReadValue = objShell.RegRead(sRegKey)
    else
        objShell.LogEvent EVENT_FAILED, _
            "Portswitch is unable to modify the Registry. The Registry Key is not present. This must be an RTM Advanced Client or a Legacy Client."
        FailAndQuit
    End If
End Sub

' -----------------------------
Sub FailAndQuit()
    WriteStatusMIF(false)
    WScript.Quit(1)
End Sub


' -----------------------------
Sub WriteStatusMIF(bSuccess)

    ' Writing a status MIF for SWDist to return a success or a failure to execute
    Const ForWriting = 2
    Const TemporaryFolder = 2
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    Dim strTempDir
    strTempDir = objFSO.GetSpecialFolder(TemporaryFolder)
    Set objFile = objFSO.CreateTextFile(strTempDir & "\portswitch.mif", ForWriting)
    objFile.Writeline ("START COMPONENT")
    objFile.Writeline ("NAME = ""WORKSTATION""")
    objFile.Writeline ("  START GROUP")
    objFile.Writeline ("    NAME = ""ComponentID""")
    objFile.Writeline ("    ID = 1")
    objFile.Writeline ("    CLASS = ""DMTF|ComponentID|1.0""")
    objFile.Writeline ("    START ATTRIBUTE")
    objFile.Writeline ("      NAME = ""Manufacturer""")
    objFile.Writeline ("      ID = 1")
    objFile.Writeline ("      ACCESS = READ-ONLY")
    objFile.Writeline ("      STORAGE = SPECIFIC")
    objFile.Writeline ("      TYPE = STRING(64)")
    objFile.Writeline ("      VALUE = ""Microsoft""")
    objFile.Writeline ("    END ATTRIBUTE")
    objFile.Writeline ("    START ATTRIBUTE")
    objFile.Writeline ("      NAME = ""Product""")
    objFile.Writeline ("      ID = 2")
    objFile.Writeline ("      ACCESS = READ-ONLY")
    objFile.Writeline ("      STORAGE = SPECIFIC")
    objFile.Writeline ("      TYPE = STRING(64)")
    objFile.Writeline ("      VALUE = ""Portswitch""")
    objFile.Writeline ("    END ATTRIBUTE")
    objFile.Writeline ("    START ATTRIBUTE")
    objFile.Writeline ("      NAME = ""Version""")
    objFile.Writeline ("      ID = 3")
    objFile.Writeline ("      ACCESS = READ-ONLY")
    objFile.Writeline ("      STORAGE = SPECIFIC")
    objFile.Writeline ("      TYPE = STRING(64)")
    objFile.Writeline ("      VALUE = ""1.0""")
    objFile.Writeline ("    END ATTRIBUTE")
    objFile.Writeline ("    START ATTRIBUTE")
    objFile.Writeline ("      NAME = ""Locale""")
    objFile.Writeline ("      ID = 4")
    objFile.Writeline ("      ACCESS = READ-ONLY")
    objFile.Writeline ("      STORAGE = SPECIFIC")
    objFile.Writeline ("      TYPE = STRING(16)")
    objFile.Writeline ("      VALUE = ""ENU""")
    objFile.Writeline ("    END ATTRIBUTE")
    objFile.Writeline ("    START ATTRIBUTE")
    objFile.Writeline ("      NAME = ""Serial Number""")
    objFile.Writeline ("      ID = 5")
    objFile.Writeline ("      ACCESS = READ-ONLY")
    objFile.Writeline ("      STORAGE = SPECIFIC")
    objFile.Writeline ("      TYPE = STRING(64)")
    objFile.Writeline ("      VALUE = """"")
    objFile.Writeline ("    END ATTRIBUTE")
    objFile.Writeline ("    START ATTRIBUTE")
    objFile.Writeline ("      NAME = ""Installation""")
    objFile.Writeline ("      ID = 6")
    objFile.Writeline ("      ACCESS = READ-ONLY")
    objFile.Writeline ("      STORAGE = SPECIFIC")
    objFile.Writeline ("      TYPE = STRING(64)")
    objFile.Writeline ("      VALUE = ""DateTime""")
    objFile.Writeline ("    END ATTRIBUTE")
    objFile.Writeline ("  END GROUP")
    objFile.Writeline ("  START GROUP")
    objFile.Writeline ("    NAME = ""InstallStatus""")
    objFile.Writeline ("    ID = 2")
    objFile.Writeline ("    CLASS = ""MICROSOFT|JOBSTATUS|1.0""")
    objFile.Writeline ("    START ATTRIBUTE")
    objFile.Writeline ("      NAME = ""Status""")
    objFile.Writeline ("      ID = 1")
    objFile.Writeline ("      ACCESS = READ-ONLY")
    objFile.Writeline ("      STORAGE = SPECIFIC")
    objFile.Writeline ("      TYPE = STRING(32)")

    ' Pass or fail this status mif?
    If bSuccess = true then
        objFile.Writeline ("      VALUE = ""Success""")
    else
        objFile.Writeline ("      VALUE = ""Failed""")
    End if

    objFile.Writeline ("    END ATTRIBUTE")
    objFile.Writeline ("    START ATTRIBUTE")
    objFile.Writeline ("      NAME = ""Description""")
    objFile.Writeline ("      ID = 2")
    objFile.Writeline ("      ACCESS = READ-ONLY")
    objFile.Writeline ("      STORAGE = SPECIFIC")
    objFile.Writeline ("      TYPE = STRING(128)")

    If bSuccess = true and iNumberOfArguments = 2 then
        objFile.Writeline ("      VALUE = ""The ConfigMgr Advanced Client has been successfully set to communicate with the MP on ports " & nPortValue & " (HTTP) and " & nSslPortValue & " (HTTPS)""")
    ElseIf bSuccess = true then
        objFile.Writeline ("      VALUE = ""The ConfigMgr Advanced Client has been successfully set to communicate with the MP on ports " & nPortValue & """")
    Else
        objFile.Writeline ("      VALUE = ""The ConfigMgr Advanced Client has not been set to communicate with the MP on the specified port.  See the client's Application Event Log for more details""")
    End If

    objFile.Writeline ("    END ATTRIBUTE")
    objFile.Writeline ("  END GROUP")
    objFile.Writeline ("END COMPONENT")

End Sub
