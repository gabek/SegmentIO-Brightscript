function Analytics(userId as String, apiKey as String, port as Object) as Object
    if GetGlobalAA().DoesExist("Analytics")
        return GetGlobalAA().Analytics
    else

        appInfo = CreateObject("roAppInfo")
        this = {
            type: "Analytics"
            version: "1.0.4"

            apiKey: apiKey

            Init: Init
            Submit: Submit
            Track: Track
            Page: Page
            AddSessionDetails: AddSessionDetails
            Handle: Handle
            
            GetExternalIP: GetExternalIP

            UserAgent: appInfo.GetTitle() + " - " + appInfo.GetVersion()
            AppVersion: appInfo.GetVersion()
            AppName: appInfo.GetTitle()

            userId: userId
            port: port

            queue: invalid
            timer: invalid  

            lastRequest: invalid
        }

        GetGlobalAA().AddReplace("Analytics", this)
        this.init()        
    end if

    return this

end function

function Init() as void

    m.SetModeCaseSensitive()

    m.queue = CreateObject("roArray", 0, true)

    m.timer = CreateObject("roTimeSpan")
    m.timer.mark()

    'print "Analytics Initialized..."
    
    m.GetExternalIP()

end function

function Page(screenName as String)
    event = CreateObject("roAssociativeArray")
    event.action = "screen"
    event.name = screenName
    m.AddSessionDetails(event)
    m.queue.push(event)
end function

function Track(eventName as string, properties = invalid as Object)

    'print "Track " + eventName

    event = CreateObject("roAssociativeArray")
    event.action = "track"
    event.event = eventName
    event.properties = properties
    m.AddSessionDetails(event)
    m.queue.push(event)
end function

function Identify()
    Identify = CreateObject("roAssociativeArray")
    Identify.SetModeCaseSensitive()
    Identify.action = "identify"
    m.AddSessionDetails(Identify)

    m.queue.push(Identify)
end function

function AddSessionDetails(event as Object)
    event.timestamp = AnalyticsDateTime()
    event.userId = m.userId
    event.context = CreateObject("roAssociativeArray")

    if NOT event.DoesExist("options")
        options = CreateObject("roAssociativeArray")
        event.options = options
    end if

    library = CreateObject("roAssociativeArray")
    library.name = "SegmentIO-Brightscript"
    library.version = m.version

    event.options.library = library

    device = CreateObject("roDeviceInfo")

    deviceInfo = CreateObject("roAssociativeArray")
    deviceInfo.model = device.GetModel()
    deviceInfo.version = device.GetVersion()
    deviceInfo.manufacturer = "Roku"
    deviceInfo.name = device.GetModelDisplayName()
    deviceInfo.id = device.GetDeviceUniqueId()
    event.context.device = deviceInfo

    event.context.app = CreateObject("roAssociativeArray")
    event.context.app.name = m.AppName
    event.context.app.version = m.AppVersion
    event.context.useragent = m.useragent

    event.context.os = CreateObject("roAssociativeArray")
    event.context.os.version = device.GetVersion()
    event.context.os.name = "Roku"

    if m.geoData <> invalid
        location = CreateObject("roAssociativeArray")
        if m.geoData.DoesExist("country_code") then location.country = m.geoData.country_code
        if m.geoData.DoesExist("city") then location.city = m.geoData.city
        if m.geoData.DoesExist("longitude") then location.longitude = m.geoData.longitude
        if m.geoData.DoesExist("latitude") then location.latitude = m.geoData.latitude
        event.context.location = location

        if m.geoData.DoesExist("ip") then event.context.ip = m.geoData.ip
    end if

    event.context.ip = m.ipAddress
    event.context.os = device.GetVersion()

    locale = strReplace(device.GetCurrentLocale(), "_", "-")
    event.context.locale = locale

    screen = CreateObject("roAssociativeArray")
    screen.width = device.GetDisplaySize().w
    screen.height = device.getDisplaySize().h
    screen.type = device.GetDisplayType()
    screen.mode = device.GetDisplayMode()
    screen.ratio = device.GetDisplayAspectRatio()
    event.context.screen = screen

end function

function Submit() as Void

    if m.queue.count() > 0 THEN
        'print "Submitting Analytics..."

        batch = CreateObject("roAssociativeArray")
        batch.SetModeCaseSensitive()
        batch.batch = m.queue

        batch.context = CreateObject("roAssociativeArray")
        batch.context.SetModeCaseSensitive()

        library = CreateObject("roAssociativeArray")
        library.name = "SegmentIO-Brightscript"
        library.version = m.version
        batch.context.library = library

        json = strReplace(FormatJson(batch), "userid", "userId") 'Because of the wonky way roAssociativeArrays keys don't care about case :\

        m.queue.clear()

        transfer = CreateObject("roUrlTransfer")

        'Authentication
        Auth = CreateObject("roByteArray")
        Auth.FromAsciiString(m.apikey + ":")

        transfer.AddHeader("Authorization", "Basic " + Auth.ToBase64String())
        transfer.AddHeader("Accept", "application/json")
        transfer.AddHeader("Content-Type", "application/json")

        transfer.SetUrl("https://api.segment.io/v1/import")
        transfer.SetPort(m.port)

        transfer.EnablePeerVerification(false)
        transfer.EnableHostVerification(false)
        transfer.RetainBodyOnError(true)

        m.lastRequest = transfer

        transfer.AsyncPostFromString(json)

    end if
    m.timer.mark()

end function

function Handle(msg)
    'print "Analytics.Handle()"
    if m.timer.totalSeconds() > 5 then
        m.Submit()
    end if

    if type(msg) = "roUrlEvent" AND m.lastRequest <> invalid AND m.lastRequest.GetIdentity() = msg.GetSourceIdentity()
        responseString = msg.GetString()
        response = ParseJSON(responseString)

        'Check for errors
        if response <> invalid AND NOT response.DoesExist("success")
            Print "*** There was an error submitting Analytics to Segment.IO: " + responseString
        end if

        m.lastRequest = invalid
    end If

end function

function AnalyticsDateTime() as String
    date = CreateObject("roDateTime")
    return date.ToISOString() 'works as of 6.2 firmware
end function

function StrReplace(basestr As String, oldsub As String, newsub As String) As String
   newstr = ""

   i = 1
   while i <= Len(basestr)
       x = Instr(i, basestr, oldsub)
       if x = 0 then
           newstr = newstr + Mid(basestr, i)
           exit while
       endif

       if x > i then
           newstr = newstr + Mid(basestr, i, x-i)
           i = x
       endif

       newstr = newstr + newsub
       i = i + Len(oldsub)
   end while

   return newstr
end function

function GetExternalIP()
    'print "GetExternalIP()"
    
    request = CreateObject("roUrlTransfer")
    request.SetMessagePort(m.port)    
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    request.InitClientCertificates()   
    
    request.SetUrl("https://api.ipify.org/?format=text")
    
    m.ipAddress = request.GetToString()
end function