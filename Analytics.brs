Function Analytics(userId as String, apikey as string, port as Object) as Object
	if GetGlobalAA().DoesExist("Analytics")
		return GetGlobalAA().Analytics
	else

		appInfo = CreateObject("roAppInfo")
		this = {
			type: "Analytics"
			version: "1.0.3"

			apikey: apikey

			Init: init_analytics
			Submit: submit_analytics
			AddEvent: add_analytics
			ViewScreen: ViewScreen
			AddSessionDetails: AddSessionDetails
			HandleAnalyticsEvents: handle_analytics
			GetGeoData: getGeoData_analytics

			UserAgent: appInfo.GetTitle() + " - " + appInfo.GetVersion()
			AppVersion: appInfo.GetVersion()
			AppName: appInfo.GetTitle()

			userId: userId
			port: port

			useGeoData: true
			geoData: invalid

			queue: invalid
			timer: invalid

			lastRequest: invalid
		}

		GetGlobalAA().AddReplace("Analytics", this)
		this.init()
	end if

	return this

End Function

Function init_analytics() as void
	if m.useGeoData = true
		m.GetGeoData()
	end if

	m.SetModeCaseSensitive()

	m.queue = CreateObject("roArray", 0, true)

	m.timer = CreateObject("roTimeSpan")
	m.timer.mark()

	Identify = CreateObject("roAssociativeArray")
	Identify.SetModeCaseSensitive()
	Identify.action = "identify"
	m.AddSessionDetails(Identify)

	m.queue.push(Identify)

	print "Analytics Initialized..."

End Function

Function ViewScreen(screenName as String)
	event = CreateObject("roAssociativeArray")
	event.action = "screen"
	event.name = screenName
	m.AddSessionDetails(event)
	m.queue.push(event)
End Function

Function add_analytics(eventName as string, properties = invalid as Object)
	event = CreateObject("roAssociativeArray")
	event.action = "track"
	event.event = eventName
	event.properties = properties
	m.AddSessionDetails(event)
	m.queue.push(event)
End Function

Function AddSessionDetails(event as Object)
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

End Function

Function submit_analytics() as Void

	if m.queue.count() > 0 THEN
		print "Submitting Analytics..."

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
		transfer.AddHeader("Content-type", "application/json")

		transfer.SetUrl("https://api.segment.io/v1/import")
		transfer.SetPort(m.port)

		transfer.EnablePeerVerification(false)
		transfer.EnableHostVerification(false)
		transfer.RetainBodyOnError(true)

		m.lastRequest = transfer

		transfer.AsyncPostFromString(json)

	end if
	m.timer.mark()

End Function

Function handle_analytics(msg)
	if m.timer.totalSeconds() > 60 then
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
	End If

End Function

Function AnalyticsDateTime() as String
	date = CreateObject("roDateTime")
	return date.ToISOString() 'works as of 6.2 firmware
End Function


'This queries the telize open GeoIP service Telize to get Geo and public IP data
Function getGeoData_analytics()
	url = "http://www.telize.com/geoip"

	transfer = CreateObject("roUrlTransfer")
	transfer.SetUrl(url)
	data = transfer.GetToString()

	object = ParseJSON(data)
	m.geoData = object
End Function