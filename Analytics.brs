Function Analytics(userId as String, apikey as string, port as Object) as Object
	if GetGlobalAA().DoesExist("Analytics") THEN
		return GetGlobalAA().Analytics
	else
		this = {
			type: "Analytics"
			apikey: apikey

			Init: init_analytics
			Submit: submit_analytics
			AddEvent: add_analytics
			ViewScreen: ViewScreen
			LogEvent: LogEvent
			HandleAnalyticsEvents: handle_analytics
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

End Function

Function init_analytics() as void
	m.SetModeCaseSensitive()

	m.queue = CreateObject("roArray", 0, true)

	m.timer = CreateObject("roTimeSpan")
	m.timer.mark()

	Identify = CreateObject("roAssociativeArray")
	Identify.SetModeCaseSensitive()
	Identify.action = "identify"
	Identify.userId = m.userId

	Identify.timestamp = AnalyticsDateTime()

	m.queue.push(Identify)

	print "Anlytics Initialized..."

End Function

Function ViewScreen(screenName as String)
	event = CreateObject("roAssociativeArray")
	event.action = "screen"
	event.name = screenName
	m.AddEvent(event)
End Function

Function LogEvent(eventString as String)
	event = CreateObject("roAssociativeArray")
	event.action = "track"
	event.event = eventString
	m.AddEvent(event)
End Function

Function add_analytics(event as object)
	event.timestamp = AnalyticsDateTime()
	event.userId = m.userId
	m.queue.push(event)
End Function

Function submit_analytics() as Void

	if m.queue.count() > 0 THEN
		print "Submitting Analytics..."

		batch = CreateObject("roAssociativeArray")
		batch.SetModeCaseSensitive()
		batch.batch = m.queue

		batch.context = CreateObject("roAssociativeArray")
		batch.context.SetModeCaseSensitive()
		device = CreateObject("roDeviceInfo")
		batch.context.deviceModel = device.GetModel()
		batch.context.deviceVersion = device.GetVersion()
		batch.context.ipAddress = GetIPAddress()

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
		if NOT response.DoesExist("success")
			Print "*** There was an error submitting Analytics to Segment.IO: " + responseString
		end if

		m.lastRequest = invalid
	End If

End Function

Function AnalyticsDateTime() as String
	date = CreateObject("roDateTime")
	date.mark()
	return DateToISO8601String(date, true)
End Function


'From http://forums.roku.com/viewtopic.php?p=336966&sid=393c92b8708c0ba9f00c2650d60fbd69
Function DateToISO8601String(date As Object, includeZ = True As Boolean) As String
   iso8601 = PadLeft(date.GetYear().ToStr(), "0", 4)
   iso8601 = iso8601 + "-"
   iso8601 = iso8601 + PadLeft(date.GetMonth().ToStr(), "0", 2)
   iso8601 = iso8601 + "-"
   iso8601 = iso8601 + PadLeft(date.GetDayOfMonth().ToStr(), "0", 2)
   iso8601 = iso8601 + "T"
   iso8601 = iso8601 + PadLeft(date.GetHours().ToStr(), "0", 2)
   iso8601 = iso8601 + ":"
   iso8601 = iso8601 + PadLeft(date.GetMinutes().ToStr(), "0", 2)
   iso8601 = iso8601 + ":"
   iso8601 = iso8601 + PadLeft(date.GetSeconds().ToStr(), "0", 2)
   If includeZ Then
      iso8601 = iso8601 + "Z"
   End If
   Return iso8601
End Function

Function PadLeft(value As String, padChar As String, totalLength As Integer) As String
   While value.Len() < totalLength
      value = padChar + value
   End While
   Return value
End Function
