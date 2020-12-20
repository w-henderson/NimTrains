# Import required libraries
import httpclient # For HTTP request
import xmlparser, xmltree # For parsing the XML
import strutils # For the parseInt proc

include stations # For the stations JSON file

# Set up types
type
    Station = object
        name: string
        crs: string
        services: seq[Service]

    CallingPoint = object
        name: string
        crs: string
        scheduledDeparture: array[2, int]
        expectedDeparture: array[2, int]

    Service = object
        destination: string
        destinationCRS: string
        origin: string
        scheduledDeparture: array[2, int]
        expectedDeparture: array[2, int]
        delay: int
        delayCause: string
        platform: string
        platformComment: string
        operator: string
        trainComment: string
        lastReport: string
        carriageCount: int
        callingPoints: seq[CallingPoint]

# Parse time formatted as an "hhmm" string into an array of [h, m]
proc parseTime(time: string): array[2, int] =
    return [parseInt(time.substr(0, 1)), parseInt(time.substr(2))]

# Small function to try and get a string and return "" if it can't
proc noneIfNotFound(xmlThingy: XmlNode, otherThingy: string): string =
    try:
        return xmlThingy.findAll(otherThingy)[0].innerText
    except:
        return ""

# Format time from the format [h,m] to "hh:mm"
proc timeFmt(time: array[2, int]): string =
    var paddedHour = $time[0]
    var paddedMinute = $time[1]
    if len(paddedHour) == 1: paddedHour = "0" & paddedHour
    if len(paddedMinute) == 1: paddedMinute = "0" & paddedMinute
    return paddedHour & ":" & paddedMinute

# Main function to load departures into a Station object
proc loadDepartures(crs: string): Station =
    let stationLink = stations[crs]["link"].getStr()
    let stationName = stations[crs]["name"].getStr()

    # Make the HTTP request for the data
    let client: HttpClient = newHttpClient()
    let stationData: string = client.getContent("http://iris2.rail.co.uk/tiger/" & stationLink)
    let parsedXML = parseXml(stationData)

    let servicesXML = parsedXML.findAll("Service")
    var servicesCount = len(servicesXML)

    # Ensure the sequence only has space for trains that don't terminate
    for service in servicesXML:
        if service.findAll("ServiceType")[0].attr("Type") == "Terminating" or service.findAll("ServiceStatus")[0].attr("Status") == "Cancelled":
            servicesCount -= 1

    var services: seq[Service] = newSeq[Service](servicesCount)

    var actualIterValue = 0
    for s in 0..len(servicesXML)-1:
        let serviceXML = servicesXML[s]

        # If the service terminates, ignore it
        if serviceXML.findAll("ServiceType")[0].attr("Type") == "Terminating" or serviceXML.findAll("ServiceStatus")[0].attr("Status") == "Cancelled":
            continue

        # Put together the list of stops
        var callingPointsObject = serviceXML.findAll("Dest1CallingPoints")[0].findAll("CallingPoint")
        var stops: seq[CallingPoint] = newSeq[CallingPoint](parseInt(serviceXML.findAll("Dest1CallingPoints")[0].attr("NumCallingPoints")) + 1)

        if len(stops) > 1:
            for i in 0..len(callingPointsObject)-1:
                try:
                    stops[i] = CallingPoint(
                        name: callingPointsObject[i].attr("Name"),
                        crs: callingPointsObject[i].attr("crs"),
                        scheduledDeparture: parseTime(callingPointsObject[i].attr("ttdep")),
                        expectedDeparture: parseTime(callingPointsObject[i].attr("etdep"))
                    )
                except:
                    stops[i] = CallingPoint(
                        name: callingPointsObject[i].attr("Name"),
                        crs: callingPointsObject[i].attr("crs"),
                        scheduledDeparture: parseTime(callingPointsObject[i].attr("ttdep")),
                        expectedDeparture: parseTime(callingPointsObject[i].attr("ttdep"))
                    )
        try:
            stops[len(stops) - 1] = CallingPoint(
                name: serviceXML.findAll("Destination1")[0].attr("name"),
                crs: serviceXML.findAll("Destination1")[0].attr("crs"),
                scheduledDeparture: parseTime(serviceXML.findAll("Destination1")[0].attr("ttarr")),
                expectedDeparture: parseTime(serviceXML.findAll("Destination1")[0].attr("etarr"))
            )
        except:
            try:
                stops[len(stops) - 1] = CallingPoint(
                    name: serviceXML.findAll("Destination1")[0].attr("name"),
                    crs: serviceXML.findAll("Destination1")[0].attr("crs"),
                    scheduledDeparture: parseTime(serviceXML.findAll("Destination1")[0].attr("ttarr")),
                    expectedDeparture: parseTime(serviceXML.findAll("Destination1")[0].attr("ttarr"))
                )
            except:
                discard "Ignore exception"

        # Parse the last report of the train
        var report = ""
        if serviceXML.findAll("LastReport")[0].attr("type") == "T":
            report = "At " & serviceXML.findAll("LastReport")[0].attr("station1") & " (" & timeFmt(parseTime(serviceXML.findAll("LastReport")[0].attr("time"))) & ")"
        elif serviceXML.findAll("LastReport")[0].attr("type") == "B":
            report = "Between " & serviceXML.findAll("LastReport")[0].attr("station1") & " and " & serviceXML.findAll("LastReport")[0].attr("station2") & " (" & timeFmt(parseTime(serviceXML.findAll("LastReport")[0].attr("time"))) & ")"
        else:
            report = "No report."

        # Parse the platform of the train
        var platform = serviceXML.findAll("Platform")[0].attr("Number")
        if platform == "":
            platform = "?"

        # If the expected departure is different to the timetabled departure, make it known
        var expectedDeparture = parseTime(serviceXML.findAll("DepartTime")[0].attr("time"))
        try:
            expectedDeparture = parseTime(serviceXML.findAll("ExpectedDepartTime")[0].attr("time"))
        except:
            discard "Ignore exception"

        var coaches = 0
        try:
            coaches = parseInt(serviceXML.findAll("Coaches1")[0].innerText)
        except:
            discard "Ignore exception"

        var delay = 0
        if serviceXML.findAll("Delay")[0].attr("Minutes") != "":
            delay = parseInt(serviceXML.findAll("Delay")[0].attr("Minutes"))

        # Put everything together into a Service object
        services[actualIterValue] = Service(
            destination: serviceXML.findAll("Destination1")[0].attr("name"),
            destinationCRS: serviceXML.findAll("Destination1")[0].attr("crs"),
            origin: serviceXML.findAll("Origin1")[0].attr("name"),
            scheduledDeparture: parseTime(serviceXML.findAll("DepartTime")[0].attr("time")),
            expectedDeparture: expectedDeparture,
            delay: delay,
            delayCause: noneIfNotFound(serviceXML, "DelayCause"),
            platform: platform,
            platformComment: noneIfNotFound(serviceXML, "PlatformComment1") & " " & noneIfNotFound(serviceXML, "PlatformComment2"),
            operator: serviceXML.findAll("Operator")[0].attr("name"),
            trainComment: noneIfNotFound(serviceXML, "AssociatedPageNotices"),
            lastReport: report,
            carriageCount: coaches,
            callingPoints: stops
        )

        actualIterValue += 1

    # Return a Station object with the name, CRS code and the sequence of Service objects
    return Station(
        name: stationName,
        crs: crs,
        services: services
    )