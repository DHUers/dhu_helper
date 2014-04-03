'use strict';

var clientId = '291063324882-u8caq69qaen8ig8i60mqbqeu2em5sucs.apps.googleusercontent.com';
var accessToken;
var calendarId;

function validateToken(token) {
  var validated;
  $.ajax({
    type: 'get',
    url: 'https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=' + token,
    async: false,
    success: function(data) {
      validated = data.audience == clientId;
    },
  });
  return validated;
}

function authGoogle(sendResponse) {
  var authUrl = encodeURI('https://accounts.google.com/o/oauth2/auth?redirect_uri=https://algalon.net/oauth2callback&client_id=' + clientId + '&response_type=token&scope=https://www.googleapis.com/auth/calendar')
  var windowProperties = {
    url: authUrl,
    left: 300,
    top: 280,
    width: 700,
    height: 600,
    focused: true,
    type: 'popup'
  };
  chrome.windows.create(windowProperties, function(window) {
    chrome.tabs.onUpdated.addListener(function(tabId, changeInfo) {
      var url = changeInfo.url;
      if (url && url.indexOf('https://algalon.net/oauth2callback') != -1) {
        accessToken = url.split('#')[1].split('&')[0].split('=')[1];
        chrome.windows.remove(window.id);
        sendResponse({status: validateToken(accessToken)});
      }
    });
  });
}

function checkCalendarExist(calendarSummary, sendResponse) {
  var header = {Authorization: 'Bearer ' + accessToken};
  $.ajax({
    type: 'get',
    url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList',
    headers: header,
    success: function(data) {
      var item;
      var found = false;
      for (var i in data.items) {
        item = data.items[i];
        if (item.summary && item.summary == calendarSummary) {
          found = true;
          break;
        }
      }
      if (!found) {
        $.ajax({
          type: 'post',
          url: 'https://www.googleapis.com/calendar/v3/calendars',
          headers: header,
          contentType: 'application/json',
          data: JSON.stringify({
            summary: calendarSummary,
            timeZone: 'Asia/Shanghai'
          }),
          success: function(data) {
            calendarId = data.id;
            getCalendarInfo(sendResponse);
          }
        });
      } else {
        calendarId = item.id;
        getCalendarInfo(sendResponse);
      }
    }
  });
}

function getCalendarInfo(sendResponse) {
  var header = {Authorization: 'Bearer ' + accessToken};
  $.ajax({
    type: 'get',
    url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList/' + calendarId,
    headers: header,
    success: function(data) {
      sendResponse({defaultReminders: data.defaultReminders});
    }
  });
}

function syncCalendarEvent(data, sendResponse) {
  var header = {Authorization: 'Bearer ' + accessToken};
  $.ajax({
    type: 'patch',
    url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList/' + calendarId,
    headers: header,
    contentType: 'application/json',
    data: JSON.stringify({
      defaultReminders: data.calendarInfo,
      timeZone: 'Asia/Shanghai'
    })
  });

  var dateTime = data.curriculumInfo.dateTime;
  var date = new Date(dateTime.year, dateTime.month - 1, dateTime.day);

  $.ajax({
    type: 'get',
    url: 'https://www.googleapis.com/calendar/v3/calendars/' + calendarId + '/events?timeMin=' + encodeURI(date.toISOString()),
    headers: header,
    async: false,
    success: function(response) {
      for (var key in response.items) {
        $.ajax({
          type: 'delete',
          url: 'https://www.googleapis.com/calendar/v3/calendars/' + calendarId + '/events/' + response.items[key].id,
          headers: header,
          tryCount: 0,
          retryLimit: 3,
          error: function() {
            if (this.tryCount <= this.retryLimit) {
              this.tryCount++;
              $.ajax(this);
              return;
            }
          }
        });
      }
    }
  });

  for (var k in data.curriculumInfo.course) {
    var v = data.curriculumInfo.course[k];

    var startDateTime = new Date(dateTime.year, dateTime.month - 1, dateTime.day);
    if (v.weekRange.isArray)
      startDateTime.setDate(dateTime.day + v.weekDay + (parseInt(v.weekRange[0]) - 1) * 7);
    else
      startDateTime.setDate(dateTime.day + v.weekDay + (parseInt(v.weekRange) - 1) * 7);
    startDateTime.setHours(v.classBegin[0], v.classBegin[1]);
    var endDateTime = new Date(startDateTime);
    endDateTime.setHours(v.classEnd[0], v.classEnd[1]);

    var requestBody = {
      start: {
        dateTime: startDateTime.toISOString().slice(0, -1) + '+08:00',
        timeZone: 'Asia/Shanghai'
      },
      end: {
        dateTime: endDateTime.toISOString().slice(0, -1) + '+08:00',
        timeZone: 'Asia/Shanghai'
      },
      location: v.location,
      description: '老师：' + v.teacherName,
      summary: v.courseName
    };
    if (v.recurrenceType !== 'SINGLE')
      requestBody.recurrence = [generateRecurrenceRule(v.recurrenceType, v.weekRange)];
    requestBody = JSON.stringify(requestBody);

    $.ajax({
      type: 'post',
      url: 'https://www.googleapis.com/calendar/v3/calendars/' + calendarId + '/events',
      headers: header,
      contentType: 'application/json',
      async: false,
      tryCount: 0,
      retryLimit: 3,
      data: requestBody,
      error: function() {
        if (this.tryCount <= this.retryLimit) {
          this.tryCount++;
          $.ajax(this);
          return;
        }
      }
    });
  }

  sendResponse(true);
}

function generateRecurrenceRule(type, weekRange) {
  if (type === 'FULL') {
    return 'RRULE:FREQ=WEEKLY;COUNT=' + parseInt(parseInt(weekRange[weekRange.length - 1]) - parseInt(weekRange[0]) + 1);
  } else if (type === 'HALF') {
    return 'RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=' + parseInt((parseInt(weekRange[weekRange.length - 1]) - parseInt(weekRange[0])) / 2 + 1);
  }
}

chrome.runtime.onMessage.addListener(function(request, sender, sendResponse) {
  if (request.type == 'AUTH_GOOGLE')
    authGoogle(sendResponse);
  else if (request.type == 'GET_CALENDAR_INFO')
    checkCalendarExist(request.data, sendResponse);
  else if (request.type == 'SYNC_CALENDAR_EVENT')
    syncCalendarEvent(request.data, sendResponse);

  return true; // keep the message channel open to the other end until sendResponse is called
});