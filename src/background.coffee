class DHUInternal
  timeTableArray = [0,
      start: [8, 15]
      end: [9, 0]
    ,
      start: [9, 0]
      end: [9, 45]
    ,
      start: [10, 5]
      end: [10, 50]
    ,
      start: [10, 50]
      end: [11, 35]
    ,
      start: [13, 0]
      end: [13, 45]
    ,
      start: [13, 45]
      end: [14, 30]
    ,
      start: [14, 50]
      end: [15, 35]
    ,
      start: [15, 35]
      end: [16, 20]
    ,
      start: [16, 20]
      end: [17, 5]
    ,
      start: [18, 0]
      end: [18, 45]
    ,
      start: [18, 45]
      end: [19, 30]
    ,
      start: [19, 50]
      end: [20, 35]
    ,
      start: [20, 35]
      end: [21, 20]
    ]
  termBeginDate =
    2013:
      2:
        year: 2014
        month: 2
        day: 23
    2014:
      1:
        year: 2014
        month: 9
        day: 1

  timeTable: (classNumber) ->
    timeTableArray[classNumber]

  firstDate: (info) ->
    termInfoRegex = /.*(\d{4}).*(\d{4}).*(\d).*/
    info = info.match termInfoRegex

    return termBeginDate[parseInt(info[1])][parseInt(info[3])]

class GoogleCalendarHandler
  clientId = '291063324882-u8caq69qaen8ig8i60mqbqeu2em5sucs.apps.googleusercontent.com'
  authUrl = "https://accounts.google.com/o/oauth2/auth?redirect_uri=https://algalon.net/oauth2callback&client_id=#{clientId}&response_type=token&scope=https://www.googleapis.com/auth/calendar"
  callbackUrl = 'https://algalon.net/oauth2callback'
  windowProperties =
    url: encodeURI authUrl
    left: 300
    top: 280
    width: 700
    height: 600
    focused: true
    type: 'popup'

  constructor: () ->
    @internal = new DHUInternal()

  auth: (sendResponse) ->
    self = @

    chrome.windows.create windowProperties, (window) ->
      chrome.tabs.onUpdated.addListener (tabId, changeInfo) ->
        url = changeInfo.url
        if url && url.indexOf callbackUrl != -1
          self.accessToken = url.split('#')[1].split('&')[0].split('=')[1]
          chrome.windows.remove window.id
          self._validateToken sendResponse

  header: ->
    headers =
      Authorization: 'Bearer ' + @accessToken

  addCalendar: (calendarMeta) ->
    self = @
    self.calendarId = null

    # make sure we create the calendar list with the name
    $.ajax
      type: 'get'
      url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList'
      headers: self.header()
      success: (data) ->
        if data.items
          for k, v of data.items
            if v.summary && v.summary == calendarMeta.name
              self.calendarId = v.id
              break

        unless self.calendarId
          $.ajax
            type: 'post'
            url: 'https://www.googleapis.com/calendar/v3/calendars'
            headers: self.header()
            contentType: 'application/json'
            data: JSON.stringify
                summary: calendarMeta.name
                timeZone: 'Asia/Shanghai'
            success: (data) ->
              self.calendarId = data.id

              self._setDefaultReminder(calendarMeta)
            error: (error) ->
              console.log error
        else
          self._setDefaultReminder(calendarMeta)

  _setDefaultReminder: (calendarMeta) ->
    self = @

    $.ajax
      type: 'patch'
      url: "https://www.googleapis.com/calendar/v3/users/me/calendarList/#{self.calendarId}"
      headers: self.header()
      contentType: 'application/json'
      data: JSON.stringify
        defaultReminders: calendarMeta.reminder
        timeZone: 'Asia/Shanghai'
      success: (data) ->
        self._syncEvents()

  _validateToken: (sendResponse) ->
    $.ajax
      type: 'get'
      url: "https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=#{@accessToken}"
      async: false
      success: (data) ->
        sendResponse {status: data.audience == clientId}

  _syncEvents: ->
    self = @

    chrome.storage.local.get 'curriculum', (blob) ->
      curriculum = blob['curriculum']
      dateTime = self.internal.firstDate curriculum.termInfo
      self.termBeginDate = new Date dateTime.year, dateTime.month - 1, dateTime.day

      # Erase any exist event after first date in this term
      $.ajax
        type: 'get'
        url: "https://www.googleapis.com/calendar/v3/calendars/#{self.calendarId}/events?timeMin=#{encodeURI self.termBeginDate.toISOString()}"
        headers: self.header()
        async: false
        success: (response) ->
          for key, v of response.items
            $.ajax
              type: 'delete'
              url: "https://www.googleapis.com/calendar/v3/calendars/#{self.calendarId}/events/#{v.id}"
              headers: self.header()
              tryCount: 0
              retryLimit: 3
              error: ->
                if @tryCount <= @retryLimit
                  @tryCount++
                  $.ajax(@)
                  return

      self._insertEvent(curriculum)

  _generateDateTime: (weekNum, detail) ->
    startDateTime = new Date @termBeginDate
    startDateTime.setDate startDateTime.getDay() + # term begin in that day
                          detail[0] + # weekday
                          (weekNum - 1) * 7 # offset week
    startTime = @internal.timeTable(detail[1]).start
    startDateTime.setHours startTime[0], startTime[1] # course time duration

    endDateTime = new Date startDateTime
    endTime = @internal.timeTable(detail[detail.length - 1]).end
    endDateTime.setHours endTime[0], endTime[1]

    dateTime =
      start: startDateTime
      end: endDateTime
    dateTime

  _generateEventPayloads: (curriculum)->
    payloads = []
    # Insert events
    for i, course of curriculum.enrolled
      for j, detail of course.details
        # generate every event for single event
        if detail.week[0] == 'SINGLE'
          for k, weekNum of detail.week[1..] # iter every single week
            daytime = @_generateDateTime weekNum, detail.time

            payloads.push
              start:
                dateTime: daytime.start.toISOString()
                timeZone: 'Asia/Shanghai'
              end:
                dateTime: daytime.end.toISOString()
                timeZone: 'Asia/Shanghai'
              location: detail.location
              description: "老师：#{course.teacherName} 学分：#{course.grade}"
              summary: course.courseName

        # generate payloads for FULL or HALF course
        else
          daytime = @_generateDateTime detail.week[1], detail.time
          recurrenceRule = @_generateRecurrenceRule detail.week

          payloads.push
            start:
              dateTime: daytime.start.toISOString()
              timeZone: 'Asia/Shanghai'
            end:
              dateTime: daytime.end.toISOString()
              timeZone: 'Asia/Shanghai'
            location: detail.location
            description: "老师：#{course.teacherName} 学分：#{course.grade}"
            summary: course.courseName
            recurrence: recurrenceRule

    payloads

  _insertEvent: (curriculum) ->
    payloads = @_generateEventPayloads(curriculum)

    console.log payloads

    for i, v of payloads
      payload = JSON.stringify v

      $.ajax
        type: 'post'
        url: "https://www.googleapis.com/calendar/v3/calendars/#{@calendarId}/events"
        headers: self.header()
        contentType: 'application/json'
        async: false
        tryCount: 0
        retryLimit: 3
        data: payload
        error: ->
          if @tryCount <= @retryLimit
            @tryCount++
            $.ajax(@)
            return

    sendResponse(true);

  syncCalendarEvent: (data) ->
    self = @
    @addCalendar data

  _generateRecurrenceRule: (detail) ->
    prefix = 'RRULE:FREQ=WEEKLY;'
    switch detail[0] # type
      when 'FULL'
        return prefix + "COUNT=#{detail[2] - detail[1] + 1}"
      when 'HALF'
        return prefix + "RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=#{(detail[2] - detail[1]) / 2 + 1}"

class DHUHelper
  constructor: ->
    @handler = new GoogleCalendarHandler()

  addChromeChannel: ->
    self = @

    chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
      switch request.type
        when 'AUTH_GOOGLE' then self.handler.auth sendResponse
        when 'SYNC_CALENDAR_EVENT'
          self.handler.syncCalendarEvent request.data
          sendResponse(true)
      true # keep the message channel open to the other end until sendResponse is called

  run: ->
    @addChromeChannel()

app = new DHUHelper()
app.run()