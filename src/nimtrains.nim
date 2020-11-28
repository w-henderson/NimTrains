include api # Import procs from api.nim
import terminal # For coloring text
import strutils # For string stuff
import strformat # For more string stuff
import os # For printing stuff I think

proc coloredWrite(textToWrite: string, color: enum = fgWhite) = 
    setForegroundColor(color)
    setStyle({styleBright})
    stdout.write(textToWrite)

if not isMainModule:
    quit(0)

# If no parameters supplied, show help text
if paramCount() == 0 or paramStr(1) == "-h" or paramStr(1) == "--help":
    coloredWrite("\n  == Welcome to NimTrains! ==\n\n", fgCyan)
    coloredWrite("  Welcome to NimTrains, a simple Nim library and command-line interface to\n  obtain realtime UK train information from Worldline's Tiger API.\n\n")
    coloredWrite("  To get basic departure information for a station:\n    - ")
    coloredWrite("nimtrains <station name or CRS code>\n\n", fgYellow)
    coloredWrite("  To get information about a specific service:\n    - ")
    coloredWrite("nimtrains <station> [-i, --id] <service ID>\n\n", fgYellow)
    coloredWrite("  To get the next service to a destination:\n    - ")
    coloredWrite("nimtrains <origin station> [-d, --dest] <destination station>\n\n", fgYellow)
    resetAttributes()
    quit(0)

# Proc to justify text by padding on the right until it meets the target length
proc ljust(toJustify: string, justification: int): string =
    if len(toJustify) >= justification: return toJustify
    return toJustify & repeat(" ", 1 + justification - len(toJustify))

# Try to parse the name, throws an exception if not
proc tryToParseName(name: string): string =
    if name.toUpper() in stations:
        return name.toUpper()
    else:
        return nameToCrs(name)

# Proc to render a basic departure board
proc renderStation(station: Station) =
    coloredWrite("\n  == Departures from " & station.name & " ==\n\n", fgCyan)

    if len(station.services) == 0:
        coloredWrite("  No services found.\n", fgRed)

    for i in 0..len(station.services)-1:
        let departure = station.services[i]
        var delayString = "On time"
        var delayColor = fgGreen
        if departure.delay > 0:
            delayColor = fgRed
            delayString = "Ex. " & timeFmt(departure.expectedDeparture)

        coloredWrite("  " & ljust($(i + 1), 3))
        coloredWrite(ljust(timeFmt(departure.scheduledDeparture), 6))
        coloredWrite(ljust(delayString, 10), delayColor)
        coloredWrite(ljust("Platform " & departure.platform, 13))
        coloredWrite(departure.destination & "\n", fgYellow)

    return

# Proc to render info about a specific service
proc renderAdditionalInfo(service: Service, highlight: string = "") =
    let time = timeFmt(service.expectedDeparture)
    let dest = service.destination
    let cc = service.carriageCount
    let plat = service.platform
    coloredWrite(&"\n  == {time} to {dest} ({cc} carriages, platform {plat}) ==\n\n", fgCyan)

    if service.delayCause != "":
        coloredWrite(&"  Delayed due to {service.delayCause}.\n")
    
    for note in [service.lastReport, service.trainComment, service.platformComment]:
        if not (note in ["", " ", "No report."]): coloredWrite("  " & note & "\n\n")

    coloredWrite("  Calling at:\n")

    for callingPoint in service.callingPoints:
        coloredWrite("  " & ljust(timeFmt(callingPoint.expectedDeparture), 6))
        coloredWrite(callingPoint.name & "\n", (if callingPoint.crs == highlight: fgGreen else: fgYellow))

# Commands for each method
let idCommands = ["-i", "--id"]
let destCommands = ["-d", "--dest"]

# If only given a station, get info about that station
if paramCount() == 1:
    try:
        let services = loadDepartures(tryToParseName(paramStr(1)))
        renderStation(services)
    except:
        coloredWrite("[ERROR]: Can't find the specified station! If it's a full name instead of a CRS code, make sure it's in quote marks.\n", fgRed)

# If given the wrong number of arguments throw an error
elif paramCount() != 3:
    coloredWrite("[ERROR]: Incorrectly formatted arguments, run nimtrains -h for help.\n", fgRed)

# If given the right number of arguments and an ID argument, show the train with the specified ID
elif paramStr(2) in idCommands:
    try:
        let services = loadDepartures(tryToParseName(paramStr(1)))
        try:
            let id = parseInt(paramStr(3))
            renderAdditionalInfo(services.services[id - 1])
        except:
            coloredWrite("[ERROR]: An error occured while selecting the service.\n", fgRed)
    except:
        coloredWrite("[ERROR]: Can't find the specified station! If it's a full name instead of a CRS code, make sure it's in quote marks.\n", fgRed)

# If given the right number of arguments and a destination argument, show the train to that destination
elif paramStr(2) in destCommands:
    try:
        let services = loadDepartures(tryToParseName(paramStr(1)))
        try:
            let target = tryToParseName(paramStr(3))
            for service in services.services:
                for callingPoint in service.callingPoints:
                    if callingPoint.crs == target:
                        renderAdditionalInfo(service, highlight=target)
                        resetAttributes()
                        quit(1)
            coloredWrite("[ERROR]: No services found to the specified destination.\n", fgRed)
        except:
            coloredWrite("[ERROR]: Destination station does not exist, please check your spelling.\n", fgRed)
    except:
        coloredWrite("[ERROR]: Can't find the specified station! If it's a full name instead of a CRS code, make sure it's in quote marks.\n", fgRed)

# If arguments are bad
else:
    coloredWrite("[ERROR]: Incorrectly formatted arguments, run nimtrains -h for help.\n", fgRed)

# Clear text formatting so we don't mess up the user's terminal
resetAttributes()