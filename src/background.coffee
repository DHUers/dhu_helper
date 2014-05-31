class GoogleCalendarHandler
  clientId = '291063324882-u8caq69qaen8ig8i60mqbqeu2em5sucs.apps.googleusercontent.com'
  authUrl = "https://accounts.google.com/o/oauth2/auth?redirect_uri=https://algalon.net/oauth2callback&client_id=#{clientId}&response_type=token&scope=https://www.googleapis.com/auth/calendar"
  callbackUrl = 'https://algalon.net/oauth2callback'

  constructor: () ->

  auth: (sendResponse) ->
    self = @

    windowProperties =
      url: encodeURI authUrl
      left: 300
      top: 280
      width: 700
      height: 600
      focused: true
      type: 'popup'

    chrome.windows.create windowProperties, (window) ->
      chrome.tabs.onUpdated.addListener (tabId, changeInfo) ->
        url = changeInfo.url
        if url && url.indexOf callbackUrl != -1
          self.accessToken = url.split('#')[1].split('&')[0].split('=')[1]
          chrome.windows.remove window.id
          sendResponse {status: self._validateToken self.accessToken}

  header: ->
    headers =
      Authorization: 'Bearer ' + @accessToken

  refreshCalendar: (calendarSummary, sendResponse) ->
    self = @
    self.calendarId = null

    payload = JSON.stringify
                summary: calendarSummary
                timeZone: 'Asia/Shanghai'
              

    $.ajax
      type: 'get'
      url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList'
      headers: self.header()
      success: (data) ->
        for k, v of data.items?
          if v.summary && v.summary == calendarSummary
            self.calendarId = v.id
            break

        unless self.calendarId
          $.ajax
            type: 'post'
            url: 'https://www.googleapis.com/calendar/v3/calendars'
            headers: self.header()
            contentType: 'application/json'
            data: payload
            success: (data) ->
              self.calendarId = data.id
              self._getCalendarInfo sendResponse

        else
          self._getCalendarInfo sendResponse


  _getCalendarInfo: (sendResponse) ->
    $.ajax
      type: 'get'
      url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList/' + @calendarId
      headers: @.header()
      success: (data) ->
        sendResponse {defaultReminders: data.defaultReminders}

  _validateToken: (token) ->
    self = @

    validated = false
    $.ajax
      type: 'get'
      url: 'https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=' + token
      async: false
      success: (data) ->
        validated = data.audience == clientId

    return validated
"""
  syncEvent: (data, sendResponse) ->
    self = @

    $.ajax(
      type: 'patch'
      url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList/' + calendarId
      headers: self.header
      contentType: 'application/json'
      data: JSON.stringify(
        defaultReminders: data.calendarInfo
        timeZone: 'Asia/Shanghai'
      )

    dateTime = data.curriculumInfo.dateTime;
    date = new Date(dateTime.year, dateTime.month - 1, dateTime.day);

    $.ajax(
      type: 'get'
      url: 'https://www.googleapis.com/calendar/v3/calendars/' + calendarId + '/events?timeMin=' + encodeURI(date.toISOString())
      headers: self.header
      async: false
      success: (response) ->
        for (key = 0; key < response.items; ++key)
          $.ajax(
            type: 'delete'
            url: 'https://www.googleapis.com/calendar/v3/calendars/' + calendarId + '/events/' + response.items[key].id
            headers: self.header
            tryCount: 0
            retryLimit: 3
            error: ->
              if (@tryCount <= @retryLimit)
                @tryCount++
                $.ajax(@)
                return
          )
    )

    for (k = 0; k < data.curriculumInfo.course.length; k++)
      v = data.curriculumInfo.course[k];

      startDateTime = new Date(dateTime.year, dateTime.month - 1, dateTime.day);
      if v.weekRange.isArray()
        startDateTime.setDate(dateTime.day + v.weekDay + (parseInt(v.weekRange[0]) - 1) * 7);
      else
        startDateTime.setDate(dateTime.day + v.weekDay + (parseInt(v.weekRange) - 1) * 7);

      startDateTime.setHours(v.classBegin[0], v.classBegin[1]);


      endDateTime = new Date(startDateTime);
      endDateTime.setHours(v.classEnd[0], v.classEnd[1]);

      var requestBody =
        start:
          dateTime: startDateTime.toISOString()
          timeZone: 'Asia/Shanghai'
        end:
          dateTime: endDateTime.toISOString()
          timeZone: 'Asia/Shanghai'
        location: v.location
        description: '老师：' + v.teacherName
        summary: v.courseName

      if (v.recurrenceType !== 'SINGLE')
        requestBody.recurrence = [_generateRecurrenceRule(v.recurrenceType, v.weekRange)];
      requestBody = JSON.stringify(requestBody);

      $.ajax(
        type: 'post'
        url: 'https://www.googleapis.com/calendar/v3/calendars/' + calendarId + '/events'
        headers: self.header
        contentType: 'application/json'
        async: false
        tryCount: 0
        retryLimit: 3
        data: requestBody
        error: ->
          if (@tryCount <= @retryLimit)
            @tryCount++
            $.ajax(@)
            return
      )

    sendResponse(true);

  _generateRecurrenceRule: (type, weekRange) ->
    if type === 'FULL'
      return 'RRULE:FREQ=WEEKLY;COUNT=' + parseInt(parseInt(weekRange[weekRange.length - 1]) - parseInt(weekRange[0]) + 1);
    else if type === 'HALF'
      return 'RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=' + parseInt((parseInt(weekRange[weekRange.length - 1]) - parseInt(weekRange[0])) / 2 + 1);
"""

class DHUHelper
  constructor: ->
    @handler = new GoogleCalendarHandler()

  addChromeChannel: ->
    self = @

    chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
      switch request.type
        when 'AUTH_GOOGLE'
          self.handler.auth(sendResponse)
        when 'GET_CALENDAR_INFO'
          true
          #handler.refreshCalendar(request.data, sendResponse)
        when 'SYNC_CALENDAR_EVENT'
          true
          #handler.syncEvent(request.data, sendResponse)
      return true # keep the message channel open to the other end until sendResponse is called

  run: ->
    @addChromeChannel()

app = new DHUHelper()
app.run()