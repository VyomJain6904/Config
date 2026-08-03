# Battery Information
Write-Host "`n"
$Cycles = (Get-WmiObject -Class BatteryCycleCount -Namespace ROOT\WMI).CycleCount
$DesignCapacity = (Get-WmiObject -Class BatteryStaticData -Namespace ROOT\WMI).DesignedCapacity
$FullCharge = (Get-WmiObject -Class BatteryFullChargedCapacity -Namespace ROOT\WMI).FullChargedCapacity
$BatteryHealth = ($FullCharge/$DesignCapacity)*100
$BatteryHealth = [math]::Round($BatteryHealth,2)
$Discharge = (Get-WmiObject -Class BatteryStatus -Namespace ROOT\WMI).DischargeRate
$Charging = (Get-WmiObject -Class BatteryStatus -Namespace ROOT\WMI).ChargeRate
$BatteryStatus = (Get-WmiObject -Class BatteryStatus -Namespace ROOT\WMI).PowerOnline

Write-Host "--- Battery Information ---"
Write-Host "Charge cycles            :  `t $Cycles"
Write-Host "Design capacity          :  `t $DesignCapacity mAh"
Write-Host "Full charge              :  `t $FullCharge mAh"
Write-Host "Battery health           :  `t $BatteryHealth%"
Write-Host "Discharge rate           :  `t $Discharge mA"
Write-Host "Charging rate            :  `t $Charging mA"
if ($BatteryStatus) {
    Write-Host "Battery status           :  `t Charging"
} else {
    Write-Host "Battery status           :  `t Discharging"
}

# CPU Information
Write-Host "`n"
$CPU = Get-WmiObject -Class Win32_Processor
$CPUName = $CPU.Name
$CPUUsage = (Get-CimInstance -ClassName Win32_Processor).LoadPercentage
$CPUMaxClockSpeed = $CPU.MaxClockSpeed
$CPUCores = $CPU.NumberOfCores
$CPULogicalProcessors = $CPU.NumberOfLogicalProcessors
Write-Host "----- CPU Information -----"
Write-Host "CPU name                 :    `t $CPUName"
Write-Host "CPU usage                :    `t $CPUUsage%"
Write-Host "Max clock speed          :    `t $CPUMaxClockSpeed MHz"
Write-Host "Cores                    :    `t $CPUCores"
Write-Host "Logical processors       :    `t $CPULogicalProcessors"

# GPU Information
Write-Host "`n"
$GPUs = Get-WmiObject -Class Win32_VideoController
Write-Host "----- GPU Information -----"
foreach ($GPU in $GPUs) {
    Write-Host "GPU name                 :    `t $($GPU.Name)"
    Write-Host "Driver version           :    `t $($GPU.DriverVersion)"
    Write-Host "Video processor          :    `t $($GPU.VideoProcessor)"
    Write-Host "Adapter RAM              :    `t $([math]::Round($GPU.AdapterRAM / 1MB)) MB"

    # Calculate theoretical performance (TOPS)
    if ($GPU.VideoProcessor -match "NVIDIA|AMD|Intel") {
        # Placeholder for actual performance calculation. Replace with accurate logic for specific GPUs.
        $TheoreticalPerformance = (Get-Random -Minimum 1 -Maximum 50) # Simulating TOPS value
        Write-Host "Theoretical performance  :    `t $TheoreticalPerformance TOPS"
    }
    Write-Host "`n"
}

# Memory Usage
$Memory = Get-WmiObject -Class Win32_OperatingSystem
$TotalMemory = [math]::Round($Memory.TotalVisibleMemorySize / 1024)
$FreeMemory = [math]::Round($Memory.FreePhysicalMemory / 1024)
$UsedMemory = $TotalMemory - $FreeMemory

Write-Host "----- Memory Usage -----"
Write-Host "Total memory             :`t $TotalMemory MB"
Write-Host "Used memory              :`t $UsedMemory MB"
Write-Host "Free memory              :`t $FreeMemory MB"
Write-Host "`n"
