"""

class CalendarHelper
  _showSettingPanel: =>
    panelTemplate = '<div id="sync_panel" class="panel panel-success"><div class="panel-heading"><h3 class="panel-title">设置</h3></div><div id="sync_panel_body" class="panel-body" style="display: none;"></div></div>'
    $('body').append(panelTemplate);

    # Auto close the panel if click otherwise
    $(document).mouseup (e) =>
      container = $('#sync_panel');

      if !container.is(e.target) && container.has(e.target).length === 0
        @_exitScript()

    @_authGoogle();

  _authGoogle: =>
    detailTemplate = '<p>Google验证服务及API被GFW干扰，请使用代理（翻墙）保证同步过程正常。</p><p>点击下面的按钮获得Google的授权：</p><div class="panel-button"><button id="auth_google" type="button" class="btn btn-large btn-primary">获取Google授权</button></div>'
    $('#sync_panel_body').append(detailTemplate)

    panel_body = $('#sync_panel_body')
    panel_body.fadeIn =>
      authGoogleButton = $('#auth_google')
      authGoogleButton.click =>
        authGoogleButton.prop('disabled', true)
        chrome.runtime.sendMessage {type: 'AUTH_GOOGLE'}, (response) =>
          if response.status
            panel_body.fadeOut =>
              panel_body.empty()
              @_setCalendarName()
          else
            authGoogleButton.prop('disabled', false)

  _setCalendarName: =>
    detailTemplate = '<p>设置日历名：</p><input type="text" value="Curriculum" placeholder="日历名" maxlength="32" class="form-control" id="calendar-name" required><div class="panel-button"><button id="sync_calendar" type="button" class="btn btn-large btn-success">下一步</button></div>'

    panel_body = $('#sync_panel_body')
    panel_body.append(detail).fadeIn =>
      $('#sync_calendar').click =>
        calendarSummary = $('#calendar-name').attr('value')
        panel_body.fadeOut =>
          panel_body.empty()
          @_calendarSetting(calendarSummary)

  @_calendarSetting: (calendarSummary) =>
    detailTemplate = '<div id="reminder-setting"><p>提醒设置：</p></div><button type="button" class="btn btn-large btn-primary" id="add-reminder-setting">添加</button><div class="panel-button"><button id="sync_calendar" type="button" class="btn btn-large btn-success" style="display: none;">同步</button></div>'
    template = '<div class="row"><div class="col-lg-4"><select class="calendar-remind-method form-control" required><option value="email">电子邮件</option><option value="popup" selected>弹出窗口</option></select></div><div class="col-lg-6"><input class="calendar-remind-time form-control" type="number" step="1" value="18" max="30" max="1" required></div><button class="btn btn-danger calendar-remind-delete-button">删除</button></div>'
    $('#sync_panel_body').append(detailTemplate);

    $('#sync_calendar').click =>
      methods = $('.calendar-remind-method').map(-> return $(@).val())
      time = $('.calendar-remind-time').map(-> return $(@).val());

      calendarReminder = [];
      for (i = 0; i < methods.length; i++)
        calendarReminder.push(
          method: methods[i]
          minutes: time[i]
        )
      $('#sync_panel').remove();

      chrome.runtime.sendMessage(
        type: 'SYNC_CALENDAR_EVENT'
        data:
          calendarInfo: calendarReminder
          curriculumInfo: @_fetchCurriculumInfo()
      , (response) ->

    $('#add-reminder-setting').click =>
      $('#reminder-setting').append(template)
      @_initDeleteButton();
      syncCalendarButton = $('#sync_calendar')
      syncCalendarButton.fadeIn() if syncCalendarButton.css('display') === 'none'

    chrome.runtime.sendMessage(
      type: 'GET_CALENDAR_INFO'
      data: calendarSummary
    , (response) =>
      if response.defaultReminders?
        for (i = 0; i < response.defaultReminders.length; i++)
          $('#reminder-setting').append(template)
          @_initDeleteButton()

          num = parseInt(i) + 1
          line = $('#reminder-setting .row:nth-child(' + num + ')')

          line.find('select').val(response.defaultReminders[i].method)
          line.find('input').val(parseInt(response.defaultReminders[i].minutes))

      $('#sync_calendar').css('display', 'inline-block')

      $('#sync_panel_body').fadeIn();
    )

  @_initDeleteButton: ->
    $('.calendar-remind-delete-button').each ->
      $(@).click ->
        $(@).parent().remove()

        if $('#reminder-setting .row').length === 0
          $('#sync_calendar').prop('disabled', true);
          $('#sync_calendar').fadeOut();

  @_fetchCurriculumInfo: ->
    curriculum = @_fetchSeletedCoursePage()

    if (typeof curriculum === 'undefined')
      exitScript()
    else
      return curriculum

  @_fetchSeletedCoursePage: =>
    termInfoRegex = /.*(\d{4}).*(\d{4}).*(\d).*/
    date = @_getFirstDate($('table[height="30"] caption').text().match(termInfoRegex));

    return unless date

    courses = []
    teacherColumn = 7 
    courseEnrolledTable = $('table[width="900"] > tbody > tr')
    courseEnrolledTable.each (key) =>
      courseRow = courseEnrolledTable[key]
      if key == 0
        if courseEnrolledTable.find('th:nth-child(7)').html().indexOf('删除') != -1)
          teacherColumn = 8
        return

      courseName = $.trim(courseRow.find('td:nth-child(2) *:not([width="100"])').text())
      teacherName = $.trim(courseRow.find('td:nth-child(' + teacherColumn + ')').text())

      timeLocationTable = courseRow.find('tr').each =>
        time = $.trim(courseRow.find('td:nth-child(2)').text()).match(/周(.)(.*)节/)
        return if time == null

        classList = time[2].split('.').slice(1)
        rawWeekRange = $.trim(courseRow.find('td:first-child').text())

        if rawWeekRange.indexOf(',') != -1
          rawWeekRangeTable = rawWeekRange.split(',')
          for (key = 0; key < rawWeekRangeTable.length; key++)
            courses.push(
              courseName: courseName,
              teacherName: teacherName,
              weekRange: rawWeekRangeTable[key].match(/\D*(\d*)\D*/)[1],
              recurrenceType: 'SINGLE',
              weekDay: chineseNumberToInt(time[1]),
              classBegin: getClassTime(classList[0]).start,
              classEnd: getClassTime(classList[classList.length - 1]).end,
              location: $.trim($(this).find('td:nth-child(3)').text())
            });
          }
        } else if (rawWeekRange.indexOf('(') != -1) {
          courses.push({
            courseName: courseName,
            teacherName: teacherName,
            weekRange: rawWeekRange.match(/\D*(\d*)\D*(\d*)\D*/).slice(1),
            recurrenceType: 'HALF',
            weekDay: chineseNumberToInt(time[1]),
            classBegin: getClassTime(classList[0]).start,
            classEnd: getClassTime(classList[classList.length - 1]).end,
            location: $.trim($(this).find('td:nth-child(3)').text())
          });
        } else {
          courses.push({
            courseName: courseName,
            teacherName: teacherName,
            weekRange: rawWeekRange.match(/\D*(\d*)\D*(\d*)\D*/).slice(1),
            recurrenceType: 'FULL',
            weekDay: chineseNumberToInt(time[1]),
            classBegin: getClassTime(classList[0]).start,
            classEnd: getClassTime(classList[classList.length - 1]).end,
            location: $.trim($(this).find('td:nth-child(3)').text())
          });
        }
      });
    });

    return {dateTime: date, course: courses};
  }

function getFirstDate(info) {
  if (parseInt(info[1]) == 2013 && parseInt(info[3]) == 1) {
    return {
      year: 2013,
      month: 9,
      day: 1
    };
  } else if (parseInt(info[1]) == 2013 && parseInt(info[3]) == 2) {
    return {
      year: 2014,
      month: 2,
      day: 23
    };
  }
}

function getClassTime(classNumber) {
  var timeTable = [0, {
    start: [8, 15],
    end: [9, 0]
  }, {
    start: [9, 0],
    end: [9, 45]
  }, {
    start: [10, 5],
    end: [10, 50]
  }, {
    start: [10, 50],
    end: [11, 35]
  }, {
    start: [13, 0],
    end: [13, 45]
  }, {
    start: [13, 45],
    end: [14, 30]
  }, {
    start: [14, 50],
    end: [15, 35]
  }, {
    start: [15, 35],
    end: [16, 20]
  }, {
    start: [16, 20],
    end: [17, 5]
  }, {
    start: [18, 0],
    end: [18, 45]
  }, {
    start: [18, 45],
    end: [19, 30]
  }, {
    start: [19, 50],
    end: [20, 35]
  }, {
    start: [20, 35],
    end: [21, 20]
  }];

  return timeTable[classNumber];
}

function chineseNumberToInt(str) {
  return '日一二三四五六'.indexOf(str);
}

  _exitScript: ->
    $('#sync_panel').remove();
    $('#sync_button').prop('disabled', false);

  _hook: =>
    syncButtonTemplate = '<button id="sync_button" type="button" class="btn btn-large btn-info">同步至Google Calendar</button>'
    $('body').append(syncButtonTemplate)
    sync_button = $('#sync_button')
    sync_button.click(=>
      sync_button.prop('disabled', true);
      @_showSettingPanel();

helper = new CalendarHelper()
helper.hook()
"""
