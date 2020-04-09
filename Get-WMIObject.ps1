$List = @()
$server = "S-90R39FT"



$bios = Get-WmiObject Win32_BIOS -ComputerName $server
$system= Get-WmiObject Win32_ComputerSystem -ComputerName $server
$Proc = Get-WmiObject Win32_processor -ComputerName $server | Select-Object -First 1
$memory = Get-WmiObject Win32_physicalmemory -ComputerName $server
$harddrive = Get-WmiObject Win32_logicaldisk -ComputerName $server

$List += [pscustomobject]@{
    'ComputerName'         = $server
    'Manufacturer'        = $bios.Manufacturer
    'BIOS Version'        = $bios.Version
    'Serial Number'       = $bios.SerialNumber
    'Processor Number'    = $system.NumberOfProcessors
    'Processor Name'      = $proc.name
    'CPUs'                 = $system.NumberOfLogicalProcessors
    'Speed (MHZ)'          = $proc.CurrentClockSpeed
    'RAM (GB)'             = $system.TotalPhysicalMemory / 1GB -as [int]
    'Used RAM slot'       = $memory.count
    'Hard Drive'             = $harddrive.size / 1GB -as [int]
}


$List | Out-GridView
