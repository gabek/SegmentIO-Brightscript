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
```
sub Main()
    print "This is a test, this is only a test"
    
    Port = CreateObject("roMessagePort") 
    User = CreateObject("roDeviceInfo").GetDeviceUniqueId()
    Analytics(User, "SegmentAPIKey", Port)                        
        
    showSpringBoard(Port)
end sub

function showSpringBoard(port as object)

    Analytics = GetGlobalAA().Analytics

    springBoard = CreateObject("roSpringboardScreen")
    springBoard.SetBreadcrumbText("[location 1]", "[location2]")
    springBoard.SetMessagePort(port)
    springBoard.AddButton(1,"Play")
    o = CreateObject("roAssociativeArray")
    o.ContentType = "episode"
    o.Title = "[Title]"
    o.ShortDescriptionLine1 = "[ShortDescriptionLine1]"
    o.ShortDescriptionLine2 = "[ShortDescriptionLine2]"
    o.Description = ""
    For i = 1 To 15
        o.Description = o.Description + "[Description] "
    End For
    o.SDPosterUrl = ""
    o.HDPosterUrl = ""
    o.Rating = "NR"
    o.StarRating = "75"
    o.ReleaseDate = "[mm/dd/yyyy]"
    o.Length = 5400
    o.Categories = CreateObject("roArray", 10, true)
    o.Categories.Push("[Category1]")
    o.Categories.Push("[Category2]")
    o.Categories.Push("[Category3]")
    o.Actors = CreateObject("roArray", 10, true)
    o.Actors.Push("[Actor1]")
    o.Actors.Push("[Actor2]")
    o.Actors.Push("[Actor3]")
    o.Director = "[Director]"
    springBoard.SetContent(o)
    springBoard.Show()
    
    count = 0
    
    while True
        msg = wait(0, port)
        if type(msg) = "roSpringboardScreenEvent"
            if msg.isScreenClosed()
                Return -1
            else if msg.GetIndex() = 1
                details = CreateObject("roAssociativeArray")
                details.foo = "baz"
                Analytics.Track("Roku Test " + count.ToStr(), details)
                count = count + 1
            end if
        end if
        Analytics.Handle(msg)
    end while
end function    
```

**Tracking**
-----------
Utilizing your reference to the **Analytics** object you initialized above you can make tracking calls using **ViewScreen**, and **AddEvent**.

###**Screen Views**
**Page** takes a simple string parameter like so: `Analytics.Page("VideoContentGridScreen")`

###**Events**
**LogEvent** takes in a string with the event that took place and an optional [roAssociativeArray](http://sdkdocs.roku.com/display/sdkdoc/roAssociativeArray) of details for your event.


	details = CreateObject("roAssociativeArray")
	details.buttonName = "Back"
	
	Analytics = GetGlobalAA().Analytics
	Analytics.Track("Button Pressed", details)
	

**Details**
-----------
All events (Including the initial **Identify** at initialization time are queued up and sent as batches to SegmentIO.  This is why the timer needs to be ping'ed during the event loop.  The events are sent to Segment.IO every 60 seconds as long as your event loop is still active.
