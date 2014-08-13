SegmentIO-Brightscript
======================

A [BrightScript](http://sdkdocs.roku.com/display/sdkdoc/BrightScript+Language+Reference) interface to [Segment.IO](https://segment.io/) event tracking

If you're in the market to add analytics to your Roku application this might be the solution for you.


**Setup**
-----------

1. Copy **Analytics.brs** to your source folder.
2. Decide how you're going to reference the "user".  If they have an actual user ID, or email address, or username and are logged in to a session, then use those.  Otherwise
`User = createObject("roDeviceInfo").GetDeviceUniqueId()` is a great way to uniquely identify.
3. Get access to the [message port](http://sdkdocs.roku.com/display/sdkdoc/roMessagePort) that's being used in your global event loop.
4. And in your Session, or somewhere else that's persistant, create an instance of the Analytics object via the following:
`Analytics = Analytics("UserIdentifier", "SegmentIOAPIKey", YourEventLoopPort)`

The above will set up an initial "Identify" call to Segment.IO in order to start tracking this user.


###**Example**
    MessagePort = GetGlobal().MessagePort
    User = createObject("roDeviceInfo").GetDeviceUniqueId()
    ApiKey = "ABCD1234"
    
    Analytics = Analytics(User, ApiKey, MessagePort)
    
    'My event loop
    while true
        msg = wait(0,MessagePort)
        'You do stuff with events in your app here
        Analytics.HandleSubmissionTimer()
    end while



**Tracking**
-----------
Utilizing your reference to the **Analytics** object you initialized above you can make tracking calls using **ViewScreen**, and **AddEvent**.

###**Screen Views**
**ViewScreen** takes a simple string parameter like so: `Analytics.ViewScreen("VideoContentGridScreen")`

###**Events**
**LogEvent** takes in a [roAssociativeArray](http://sdkdocs.roku.com/display/sdkdoc/roAssociativeArray) of details for your event.


	action = CreateObject("roAssociativeArray")
	action.event = "Button Pressed"
	
	action.properties = CreateObject("roAssociativeArray")
	action.properties.buttonName = "Back"
	
	Analytics = GetSession().Analytics
	Analytics.AddEvent(action)
	
A convinience function for simple actions without context can be fired with `Analytics.LogEvent("Back Button Pressed")`


**Details**
-----------
All events (Including the initial **Identify** at initialization time are queued up and sent as batches to SegmentIO.  This is why the timer needs to be ping'ed during the event loop.  The events are sent to Segment.IO every 60 seconds as long as your event loop is still active.
