###class GoogleCalendarHandler
  clientId = '291063324882-u8caq69qaen8ig8i60mqbqeu2em5sucs.apps.googleusercontent.com'
  authUrl = encodeURI('https://accounts.google.com/o/oauth2/auth?redirect_uri=https://algalon.net/oauth2callback&client_id=' + clientId + '&response_type=token&scope=https://www.googleapis.com/auth/calendar')

  constructor: () ->

  auth: (sendResponse) ->
    windowProperties =
      url: authUrl
      left: 300
      top: 280
      width: 700
      height: 600
      focused: true
      type: 'popup'

    chrome.windows.create(windowProperties, (window) =>
      chrome.tabs.onUpdated.addListener((tabId, changeInfo) =>
        url = changeInfo.url
        if (url && url.indexOf('https://algalon.net/oauth2callback') != -1)
          @accessToken = url.split('#')[1].split('&')[0].split('=')[1]
          chrome.windows.remove(window.id)
          sendResponse({status: @_validateToken(@accessToken)})

  refreshCalendar: (calendarSummary, sendResponse) ->
    header = 
      Authorization: 'Bearer ' + accessToken

    self = @
    $.ajax(
      type: 'get'
      url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList'
      headers: header
      success: (data) =>
        found = false
        if data.items
          for (i = 0; i < data.items.length; i++)
            item = data.items[i]
            if item.summary && item.summary === calendarSummary
              found = true
              break
    
        unless found
          $.ajax(
            type: 'post'
            url: 'https://www.googleapis.com/calendar/v3/calendars'
            headers: header
            contentType: 'application/json'
            data: JSON.stringify(
              summary: calendarSummary
              timeZone: 'Asia/Shanghai'
            )
            success: (data) ->
              self.calendarId = data.id
              getCalendarInfo(sendResponse)
        else
          self.calendarId = item.id
          getCalendarInfo(sendResponse)

  _getCalendarInfo: (sendResponse) ->
    header =
      Authorization: 'Bearer ' + accessToken
    $.ajax(
      type: 'get'
      url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList/' + calendarId
      headers: header
      success: (data) ->
        sendResponse {defaultReminders: data.defaultReminders}
    )

  _validateToken: (token) ->
    validated = false
    $.ajax(
      type: 'get'
      url: 'https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=' + token
      async: false
      success: (data) =>
        validated = data.audience === clientId

    return validated

  syncEvent: (data, sendResponse) ->
    header =
      {Authorization: 'Bearer ' + accessToken}
    $.ajax(
      type: 'patch'
      url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList/' + calendarId
      headers: header
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
      headers: header
      async: false
      success: (response) ->
        for (key = 0; key < response.items; ++key)
          $.ajax(
            type: 'delete'
            url: 'https://www.googleapis.com/calendar/v3/calendars/' + calendarId + '/events/' + response.items[key].id
            headers: header
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
        headers: header
        contentType: 'application/json'
        async: false
        tryCount: 0
        retryLimit: 3
        data: requestBody
        error: () ->
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

handler = new GoogleCalendarHandler()

chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
  if (request.type == 'AUTH_GOOGLE')
    handler.auth(sendResponse)
  else if (request.type == 'GET_CALENDAR_INFO')
    handler.refreshCalendar(request.data, sendResponse)
  else if (request.type == 'SYNC_CALENDAR_EVENT')
    handler.syncEvent(request.data, sendResponse)

  return true # keep the message channel open to the other end until sendResponse is called
###