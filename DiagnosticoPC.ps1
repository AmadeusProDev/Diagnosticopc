
#requires -Version 5.1
<#
    DIAGNOSTICO PC v1.1
    Inventario de hardware y diagnostico basico.
    Compatible con Windows PowerShell 5.1.
    Solo lectura: no modifica Windows ni guarda informes.
#>

$ErrorActionPreference = "SilentlyContinue"

# =========================================================
# FUNCIONES GENERALES
# =========================================================

function Write-Title {
    param([string]$Text)

    Write-Host ""
    Write-Host ("=" * 76) -ForegroundColor DarkCyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("=" * 76) -ForegroundColor DarkCyan
}

function Write-Item {
    param(
        [string]$Label,
        [object]$Value,
        [string]$Status = "INFO"
    )

    if ($null -eq $Value -or "$Value".Trim() -eq "") {
        $Value = "No disponible"
    }

    $color = switch ($Status) {
        "OK"      { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        default   { "Gray" }
    }

    $tag = switch ($Status) {
        "OK"      { "[OK]" }
        "WARN"    { "[!!]" }
        "ERROR"   { "[ERROR]" }
        default   { "[INFO]" }
    }

    Write-Host ("{0,-9} {1,-31} {2}" -f $tag, $Label, $Value) `
        -ForegroundColor $color
}

function Format-Bytes {
    param([double]$Bytes)

    if ($Bytes -le 0) { return "No disponible" }
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }

    return "{0:N0} bytes" -f $Bytes
}

function Format-Date {
    param($Value)

    if ($null -eq $Value -or "$Value" -eq "") {
        return "No disponible"
    }

    try {
        if ($Value -is [datetime]) {
            return $Value.ToString("yyyy-MM-dd")
        }

        return ([Management.ManagementDateTimeConverter]::ToDateTime(
            [string]$Value
        )).ToString("yyyy-MM-dd")
    }
    catch {
        return "$Value"
    }
}

function Get-PropertyValue {
    param($Object, [string]$Property)

    if ($null -eq $Object) { return $null }

    $p = $Object.PSObject.Properties[$Property]
    if ($p) { return $p.Value }

    return $null
}

function Get-Activation {
    try {
        $appId = "55c92734-d682-4d71-983e-d6ec3f16059f"

        $licenses = @(
            Get-CimInstance SoftwareLicensingProduct `
                -Filter "PartialProductKey IS NOT NULL" |
            Where-Object {
                $_.ApplicationID -eq $appId -and
                $_.Name -match "Windows"
            }
        )

        if ($licenses | Where-Object { $_.LicenseStatus -eq 1 }) {
            return "Activado"
        }

        if ($licenses.Count -gt 0) {
            return "No aparece activado"
        }

        return "No se pudo determinar"
    }
    catch {
        return "Consulta no disponible"
    }
}

function Get-LicenseDescription {
    param([int]$Code)

    switch ($Code) {
        0 { "Sin licencia" }
        1 { "Licenciado" }
        2 { "Periodo de gracia inicial" }
        3 { "Periodo de gracia adicional" }
        4 { "No original" }
        5 { "Notificacion" }
        6 { "Periodo de gracia extendido" }
        default { "Estado $Code" }
    }
}

# =========================================================
# INICIO
# =========================================================

Clear-Host

Write-Host ""
Write-Host "  DIAGNOSTICO PC v1.1" -ForegroundColor Cyan
Write-Host "  Inventario tecnico de hardware y Windows" -ForegroundColor Gray
Write-Host ("  Fecha: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) `
    -ForegroundColor Gray

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Item "Permisos" "Ejecutando como administrador" "OK"
}
else {
    Write-Item "Permisos" "Usuario normal; algunos datos pueden faltar" "WARN"
}

# =========================================================
# A. IDENTIFICACION DEL EQUIPO
# =========================================================

Write-Title "A. IDENTIFICACION DEL EQUIPO"

$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os = Get-CimInstance Win32_OperatingSystem
$enclosure = Get-CimInstance Win32_SystemEnclosure
$baseboard = Get-CimInstance Win32_BaseBoard

Write-Item "Fabricante" $cs.Manufacturer
Write-Item "Modelo" $cs.Model
Write-Item "Nombre del equipo" $cs.Name
Write-Item "Tipo de sistema" $cs.SystemType
Write-Item "Dominio / grupo" $cs.Domain
Write-Item "Numero de serie" $bios.SerialNumber
Write-Item "Product Number" $cs.SystemSKUNumber
Write-Item "Tipo de chasis" (
    if ($enclosure.ChassisTypes) {
        ($enclosure.ChassisTypes -join ", ")
    } else {
        "No informado"
    }
)

Write-Host ""
Write-Host "  PLACA MADRE" -ForegroundColor White

Write-Item "Fabricante" $baseboard.Manufacturer
Write-Item "Modelo / producto" $baseboard.Product
Write-Item "Version" $baseboard.Version
Write-Item "Serie de placa" $baseboard.SerialNumber

Write-Host ""
Write-Host "  BIOS / UEFI" -ForegroundColor White

Write-Item "Fabricante BIOS" $bios.Manufacturer
Write-Item "Version BIOS" $bios.SMBIOSBIOSVersion
Write-Item "Fecha BIOS" (Format-Date $bios.ReleaseDate)
Write-Item "SMBIOS" $bios.SMBIOSBIOSVersion

# =========================================================
# B. PROCESADOR
# =========================================================

Write-Title "B. PROCESADOR"

$cpus = @(Get-CimInstance Win32_Processor)

foreach ($cpu in $cpus) {
    Write-Item "Modelo" $cpu.Name
    Write-Item "Fabricante" $cpu.Manufacturer
    Write-Item "Nucleos" $cpu.NumberOfCores
    Write-Item "Hilos logicos" $cpu.NumberOfLogicalProcessors
    Write-Item "Frecuencia actual" (
        if ($cpu.CurrentClockSpeed) {
            "$($cpu.CurrentClockSpeed) MHz"
        } else { "No disponible" }
    )
    Write-Item "Frecuencia maxima" (
        if ($cpu.MaxClockSpeed) {
            "$($cpu.MaxClockSpeed) MHz"
        } else { "No disponible" }
    )
    Write-Item "Cache L2" (Format-Bytes ([double]$cpu.L2CacheSize * 1KB))
    Write-Item "Cache L3" (Format-Bytes ([double]$cpu.L3CacheSize * 1KB))
    Write-Item "Socket informado" $cpu.SocketDesignation
}

# =========================================================
# C. MEMORIA RAM
# =========================================================

Write-Title "C. MEMORIA RAM"

$ramTotalGB = [math]::Round(
    ([double]$cs.TotalPhysicalMemory / 1GB), 2
)

Write-Item "RAM total utilizable" "$ramTotalGB GB"

$memoryArray = Get-CimInstance Win32_PhysicalMemoryArray
$memoryModules = @(Get-CimInstance Win32_PhysicalMemory)

$reportedSlots = 0
if ($memoryArray) {
    $reportedSlots = ($memoryArray |
        Measure-Object -Property MemoryDevices -Sum).Sum
}

Write-Item "Dispositivos reportados por SMBIOS" (
    if ($reportedSlots -gt 0) {
        "$reportedSlots"
    } else { "No informado" }
)

Write-Item "Modulos detectados" "$($memoryModules.Count)"

if ($memoryArray) {
    $maxCapacityKB = ($memoryArray |
        Measure-Object -Property MaxCapacity -Sum).Sum

    if ($maxCapacityKB -gt 0) {
        Write-Item "Capacidad maxima SMBIOS" (
            Format-Bytes ([double]$maxCapacityKB * 1KB)
        )
    }
    else {
        Write-Item "Capacidad maxima SMBIOS" "No informada"
    }

    $maxCapacityEx = ($memoryArray |
        Measure-Object -Property MaxCapacityEx -Sum).Sum

    if ($maxCapacityEx -gt 0) {
        Write-Item "Capacidad maxima extendida" (
            Format-Bytes ([double]$maxCapacityEx)
        )
    }
}

$slot = 0

foreach ($ram in $memoryModules) {
    Write-Host ""

    Write-Item "Fabricante" $ram.Manufacturer
    Write-Item "Modelo / Parte" $ram.PartNumber
    Write-Item "Capacidad" (Format-Bytes ([double]$ram.Capacity))

    # Velocidad configurada
    $ramSpeed = "No informada"

    if ($ram.Speed) {
        $ramSpeed = "$($ram.Speed) MT/s"
    }

    Write-Item "Velocidad" $ramSpeed

    # Velocidad nominal, si SMBIOS la proporciona
    $ramConfiguredSpeed = "No informada"

    if ($ram.ConfiguredClockSpeed) {
        $ramConfiguredSpeed = "$($ram.ConfiguredClockSpeed) MT/s"
    }

    Write-Item "Velocidad configurada" $ramConfiguredSpeed

    Write-Item "Banco / Slot" $ram.DeviceLocator
    Write-Item "Banco físico" $ram.BankLabel
}

Write-Host ""
Write-Host "  NOTA: las ranuras y la capacidad maxima son datos SMBIOS." `
    -ForegroundColor Yellow
Write-Host "  No confirman por si solos si la RAM esta soldada o es extraible." `
    -ForegroundColor Yellow

# =========================================================
# D. GRAFICOS
# =========================================================

Write-Title "D. GRAFICOS / GPU"

$gpus = @(Get-CimInstance Win32_VideoController)

foreach ($gpu in $gpus) {
    Write-Host ""
    Write-Host "  $($gpu.Name)" -ForegroundColor White

    Write-Item "Fabricante" $gpu.AdapterCompatibility
    Write-Item "Memoria informada" (
        Format-Bytes ([double]$gpu.AdapterRAM)
    )
    Write-Item "Resolucion actual" (
        "$($gpu.CurrentHorizontalResolution) x $($gpu.CurrentVerticalResolution)"
    )
    Write-Item "Controlador" $gpu.DriverVersion
    Write-Item "Fecha controlador" (Format-Date $gpu.DriverDate)
    Write-Item "Estado" $gpu.Status
}

# =========================================================
# E. ALMACENAMIENTO Y SALUD
# =========================================================

Write-Title "E. ALMACENAMIENTO"

$disks = @(Get-CimInstance Win32_DiskDrive)

foreach ($disk in $disks) {
    Write-Host ""
    Write-Host "  DISCO: $($disk.Model)" -ForegroundColor White

    Write-Item "Modelo" $disk.Model
    Write-Item "Fabricante" $disk.Manufacturer
    Write-Item "Serie" $disk.SerialNumber
    Write-Item "Firmware" $disk.FirmwareRevision
    Write-Item "Interfaz" $disk.InterfaceType
    Write-Item "Tipo de medio" $disk.MediaType
    Write-Item "Capacidad" (Format-Bytes ([double]$disk.Size))
    Write-Item "Estado Windows" $disk.Status (
        if ($disk.Status -eq "OK") { "OK" } else { "WARN" }
    )
}
Write-Host ""
Write-Host "  ESTADO DE STORAGE SPACES / STORAGE PROVIDER" `
    -ForegroundColor White

try {
    $physicalDisks = @(Get-PhysicalDisk -ErrorAction Stop)

    foreach ($pd in $physicalDisks) {
        Write-Host ""

        Write-Item "Modelo" $pd.FriendlyName
        Write-Item "Tipo" $pd.MediaType
        Write-Item "Bus" $pd.BusType
        Write-Item "Tamaño" (Format-Bytes ([double]$pd.Size))

        # Estado de salud
        $healthLabel = "INFO"

        if ($pd.HealthStatus -eq "Healthy") {
            $healthLabel = "OK"
        }
        elseif (
            $pd.HealthStatus -eq "Warning" -or
            $pd.HealthStatus -eq "Unhealthy"
        ) {
            $healthLabel = "WARN"
        }

        Write-Item "Salud" $pd.HealthStatus $healthLabel

        # Estado operativo
        $operationalStatus = "No informado"

        if ($pd.OperationalStatus) {
            $operationalStatus = $pd.OperationalStatus -join ", "
        }

        Write-Item "Estado operativo" $operationalStatus

        # Vida restante
        $remainingLife = "No informada"

        if ($null -ne $pd.RemainingLife) {
            $remainingLife = "$($pd.RemainingLife)%"
        }

        Write-Item "Vida restante" $remainingLife

        # Contadores de confiabilidad, si el proveedor los ofrece
        try {
            $rc = $pd | Get-StorageReliabilityCounter -ErrorAction Stop

            if ($null -ne $rc) {
                # Temperatura actual
                $temperature = "No informada"

                if ($null -ne $rc.Temperature) {
                    $temperature = "$($rc.Temperature) C"
                }

                Write-Item "Temperatura" $temperature

                # Temperatura maxima
                $temperatureMax = "No informada"

                if ($null -ne $rc.TemperatureMax) {
                    $temperatureMax = "$($rc.TemperatureMax) C"
                }

                Write-Item "Temperatura maxima" $temperatureMax

                Write-Item "Horas encendido" $rc.PowerOnHours
                Write-Item "Ciclos encendido" $rc.StartStopCycleCount
                Write-Item "Errores lectura" $rc.ReadErrorsTotal
                Write-Item "Errores escritura" $rc.WriteErrorsTotal
                Write-Item "Desgaste" $rc.Wear
            }
            else {
                Write-Item "Contadores SMART" "Sin datos" "INFO"
            }
        }
        catch {
            Write-Item "Contadores SMART" "No disponibles" "INFO"
        }
    }
}
catch {
    Write-Item "Storage Provider" "Consulta no disponible" "WARN"
}

Write-Host ""
Write-Host "  Los datos anteriores no equivalen a una lectura SMART completa." `
    -ForegroundColor Yellow
Write-Host "  Un valor ausente no significa que el disco este defectuoso." `
    -ForegroundColor Yellow

# =========================================================
# F. VOLUMENES Y ESPACIO LIBRE
# =========================================================

Write-Title "F. PARTICIONES Y ESPACIO"

$volumes = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3")

foreach ($volume in $volumes) {
    $freePct = 0

    if ($volume.Size -gt 0) {
        $freePct = [math]::Round(
            100 * $volume.FreeSpace / $volume.Size, 1
        )
    }

    $status = if ($freePct -lt 10) { "WARN" } else { "OK" }

    Write-Item $volume.DeviceID (
        "$(Format-Bytes ([double]$volume.FreeSpace)) libres de " +
        "$(Format-Bytes ([double]$volume.Size)) ($freePct% libre)"
    ) $status
}

# =========================================================
# G. BATERIA
# =========================================================

Write-Title "G. BATERIA"

$batteries = @(Get-CimInstance Win32_Battery)

if ($batteries.Count -eq 0) {
    Write-Item "Bateria" "No detectada"
}
else {
    foreach ($battery in $batteries) {
        Write-Host ""
        Write-Item "Nombre" $battery.Name
        Write-Item "Fabricante" $battery.Manufacturer
        Write-Item "Serie" $battery.SerialNumber
        Write-Item "Estado" $battery.Status
        Write-Item "Carga restante" (
            if ($null -ne $battery.EstimatedChargeRemaining) {
                "$($battery.EstimatedChargeRemaining)%"
            } else { "No informada" }
        )
        Write-Item "Capacidad de diseño" (
            if ($battery.DesignCapacity) {
                "$($battery.DesignCapacity) mWh"
            } else { "No informada" }
        )
        Write-Item "Capacidad de carga completa" (
            if ($battery.FullChargeCapacity) {
                "$($battery.FullChargeCapacity) mWh"
            } else { "No informada" }
        )
    }
}

Write-Host ""
Write-Host "  Para generar un informe detallado de bateria:" `
    -ForegroundColor Gray
Write-Host "  powercfg /batteryreport" -ForegroundColor Gray

# =========================================================
# H. WINDOWS Y SEGURIDAD
# =========================================================

Write-Title "H. WINDOWS Y SEGURIDAD"

Write-Item "Edicion" $os.Caption
Write-Item "Version" $os.Version
Write-Item "Compilacion" $os.BuildNumber
Write-Item "Arquitectura" $os.OSArchitecture
Write-Item "Instalacion" (Format-Date $os.InstallDate)

$activation = Get-Activation
$activationStatus = if ($activation -eq "Activado") {
    "OK"
} else {
    "WARN"
}
Write-Item "Activacion" $activation $activationStatus

$uptime = (Get-Date) - $os.LastBootUpTime
Write-Item "Tiempo encendido" (
    "{0} dias, {1} horas" -f
    [math]::Floor($uptime.TotalDays), $uptime.Hours
)

# Antivirus: Defender
try {
    $defender = Get-MpComputerStatus -ErrorAction Stop

    if ($defender) {
        $antivirusStatus = "No determinado"
        $realtimeStatus = "No determinado"

        if ($defender.AntivirusEnabled) {
            $antivirusStatus = "Activado"
        }
        else {
            $antivirusStatus = "No activo"
        }

        if ($defender.RealTimeProtectionEnabled) {
            $realtimeStatus = "Activada"
        }
        else {
            $realtimeStatus = "No activa"
        }

        Write-Item "Antivirus Microsoft Defender" $antivirusStatus
        Write-Item "Proteccion en tiempo real" $realtimeStatus
    }
    else {
        Write-Item "Microsoft Defender" "Sin datos" "INFO"
    }
}
catch {
    Write-Item "Microsoft Defender" `
        "No disponible: $($_.Exception.Message)" "INFO"
}

# Antivirus registrados en el Centro de seguridad
try {
    $avProducts = @(
        Get-CimInstance -Namespace root/SecurityCenter2 `
            -ClassName AntivirusProduct
    )

    foreach ($av in $avProducts) {
        Write-Item "Antivirus registrado" $av.displayName
    }
}
catch {
    Write-Item "Antivirus registrados" "Consulta no disponible"
}

# =========================================================
# I. DISPOSITIVOS Y CONTROLADORES
# =========================================================

Write-Title "I. DISPOSITIVOS Y CONTROLADORES"

$problemDevices = @(
    Get-CimInstance Win32_PnPEntity |
    Where-Object { $_.ConfigManagerErrorCode -ne 0 }
)

if ($problemDevices.Count -eq 0) {
    Write-Item "Errores PnP" "No se detectaron errores" "OK"
}
else {
    Write-Item "Errores PnP" "$($problemDevices.Count) dispositivo(s)" "WARN"

    foreach ($device in $problemDevices) {
        Write-Host ""
        Write-Item "Dispositivo" $device.Name "WARN"
        Write-Item "Codigo de error" $device.ConfigManagerErrorCode "WARN"
        Write-Item "Descripcion" $device.Description
    }
}

$allDevices = @(Get-CimInstance Win32_PnPEntity)

$checks = @(
    @{ Label = "Teclado"; Pattern = "Keyboard" },
    @{ Label = "Wi-Fi"; Pattern = "Wireless|Wi-Fi|802\.11" },
    @{ Label = "Audio"; Pattern = "Audio|Sound" },
    @{ Label = "Bluetooth"; Pattern = "Bluetooth" },
    @{ Label = "Camara"; Pattern = "Camera|Webcam|Imaging" },
    @{ Label = "GPU"; Pattern = "Display|Video|VGA" }
)

foreach ($check in $checks) {
    $found = @($allDevices | Where-Object {
        $_.Name -match $check.Pattern
    })

    if ($found.Count -gt 0) {
        $bad = @($found | Where-Object {
            $_.ConfigManagerErrorCode -ne 0
        })

        if ($bad.Count -gt 0) {
            Write-Item $check.Label "Detectado con posible error" "WARN"
        }
        else {
            Write-Item $check.Label "Detectado; prueba funcional pendiente" "OK"
        }
    }
    else {
        Write-Item $check.Label "No identificado por Windows" "WARN"
    }
}

# =========================================================
# J. RESUMEN Y LIMITACIONES
# =========================================================

Write-Title "J. FIN DEL DIAGNOSTICO"

Write-Host "  Inventario finalizado." -ForegroundColor Green
Write-Host ""
Write-Host "  LIMITACIONES IMPORTANTES" -ForegroundColor Yellow
Write-Host "  1. SMBIOS puede omitir o informar mal ranuras y capacidades."
Write-Host "  2. RAM detectada no confirma si es soldada o extraible."
Write-Host "  3. La capacidad maxima requiere verificar el modelo exacto."
Write-Host "  4. La salud del disco depende del controlador y del fabricante."
Write-Host "  5. No todos los SSD exponen porcentaje de vida restante."
Write-Host "  6. Detectar teclado no prueba cada tecla."
Write-Host "  7. Detectar GPU no confirma su rendimiento ni temperatura."
Write-Host ""
Write-Host "  No se ha guardado ni enviado ningun informe." `
    -ForegroundColor Gray
Write-Host ""

Read-Host "Presiona ENTER para cerrar"