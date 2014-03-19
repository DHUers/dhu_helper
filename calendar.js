'use strict';

function settingPanel() {
  var panel = '<div id="sync_panel" class="panel panel-success"><div class="panel-heading"><h3 class="panel-title">设置</h3></div><div id="sync_panel_body" class="panel-body" style="display: none;"></div></div>'
  $('body').append(panel);
  $(document).mouseup(function (e) {
    var container = $('#sync_panel');

    if (!container.is(e.target) && container.has(e.target).length === 0)
      exitScript();
  });
  authGoogle();
}

function authGoogle() {
  var detail = '<p>Google验证服务及API被GFW干扰，请使用代理（翻墙）保证同步过程正常。</p><p>点击下面的按钮获得Google的授权：</p><div class="panel-button"><button id="auth_google" type="button" class="btn btn-large btn-primary">获取Google授权</button></div>';
  $('#sync_panel_body').append(detail).fadeIn(function() {
    $('#auth_google').click(function() {
      $(this).prop('disabled', true);
      chrome.runtime.sendMessage({type: 'AUTH_GOOGLE'}, function(response) {
        if (response.status) {
          $('#sync_panel_body').fadeOut(function() {
            $(this).empty();
            calendarName();
          });
        } else {
          $(this).prop('disabled', false);
        }
      });
    });
  });
}

function calendarName() {
  var detail = '<p>设置日历名：</p><input type="text" value="Curriculum" placeholder="日历名" maxlength="32" class="form-control" id="calendar-name" required><div class="panel-button"><button id="sync_calendar" type="button" class="btn btn-large btn-success">下一步</button></div>';
  $('#sync_panel_body').append(detail).fadeIn(function() {
    $('#sync_calendar').click(function() {
      var calendarSummary = $('#calendar-name').attr('value');
      $('#sync_panel_body').fadeOut(function() {
        $(this).empty();
        calendarSetting(calendarSummary);
      });
    });
  });
}

function calendarSetting(calendarSummary) {
  var detail = '<div id="reminder-setting"><p>提醒设置：</p></div><button type="button" class="btn btn-large btn-primary" id="add-reminder-setting">添加</button><div class="panel-button"><button id="sync_calendar" type="button" class="btn btn-large btn-success" style="display: none;">同步</button></div>';
  var template = '<div class="row"><div class="col-lg-4"><select class="calendar-remind-method form-control" required><option value="email">电子邮件</option><option value="popup" selected>弹出窗口</option></select></div><div class="col-lg-6"><input class="calendar-remind-time form-control" type="number" step="1" value="18" max="30" max="1" required></div><button class="btn btn-danger calendar-remind-delete-button">删除</button></div>'
  $('#sync_panel_body').append(detail);
  $('#sync_calendar').click(function() {
    var methods = $('.calendar-remind-method').map(function() { return $(this).val(); });
    var time = $('.calendar-remind-time').map(function() { return $(this).val() });

    var calendarReminder = [];
    for (var i = 0; i < methods.length; i++)
      calendarReminder.push({
        method: methods[i],
        minutes: time[i]
      });
    $('#sync_panel').remove();

    chrome.runtime.sendMessage({
      type: 'SYNC_CALENDAR_EVENT',
      data: {
        calendarInfo: calendarReminder,
        curriculumInfo: fetchCurriculumInfo()
      }
    }, function(response) {

    });
  });
  $('#add-reminder-setting').click(function() {
    $('#reminder-setting').append(template);
    initDeleteButton();
    var syncCalendarButton = $('#sync_calendar');
    if (syncCalendarButton.css('display') === 'none')
      syncCalendarButton.fadeIn();
  });

  chrome.runtime.sendMessage({type: 'GET_CALENDAR_INFO', data: calendarSummary}, function(response) {
    if (response.defaultReminders) {
      for (var i in response.defaultReminders) {
        $('#reminder-setting').append(template);
        initDeleteButton();

        var num = parseInt(i) + 1;
        var line = $('#reminder-setting .row:nth-child(' + num + ')');

        line.find('select').val(response.defaultReminders[i].method);
        line.find('input').val(parseInt(response.defaultReminders[i].minutes));
      }

      $('#sync_calendar').css('display', 'inline-block');
    }

    $('#sync_panel_body').fadeIn();
  });
}

function initDeleteButton() {
  $('.calendar-remind-delete-button').each(function() {
    $(this).click(function() {
      $(this).parent().remove();

      if ($('#reminder-setting .row').length === 0) {
        $('#sync_calendar').prop('disabled', true);
        $('#sync_calendar').fadeOut();
      }
    });
  });
}

function fetchCurriculumInfo() {
  var curriculum;

  if (window.location.href.indexOf('seeselectedcourse') != -1)
    curriculum = fetchSeletedCoursePage();
  else if (window.location.href.indexOf('studentcoursetable') != -1)
    curriculum = fetchCourseTablePage();

  if (typeof curriculum === 'undefined')
    exitScript();
  else
    return curriculum;
}

function fetchSeletedCoursePage() {
  var termInfoRegex = /.*(\d{4}).*(\d{4}).*(\d).*/
  var date = getFirstDate($('table[height="30"] caption').text().match(termInfoRegex));

  if (!date)
    return;

  var courses = [];
  var teacherColumn = 7;
  $('table[width="900"] > tbody > tr').each(function(key) {
    if (key == 0) {
      if ($(this).find('th:nth-child(7)').html().indexOf('删除') != -1) {
        teacherColumn = 8;
      };
      return;
    }

    var courseName = $.trim($(this).find('td:nth-child(2) *:not([width="100"])').text());
    var teacherName = $.trim($(this).find('td:nth-child(' + teacherColumn + ')').text());

    var timeLocationTable = $(this).find('tr').each(function() {
      var time = $.trim($(this).find('td:nth-child(2)').text()).match(/周(.)(.*)节/);
      var classList = time[2].split('.').slice(1);
      var rawWeekRange = $.trim($(this).find('td:first-child').text());

      if (rawWeekRange.indexOf(',') != -1) {
        var rawWeekRangeTable = rawWeekRange.split(',');
        for (key in rawWeekRangeTable) {
          courses.push({
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

function fetchCourseTablePage() {
  var termInfoRegex = /.*(\d{4}).*(\d{4}).*(\d).*/
  var date = getFirstDate($('body > div').text().match(termInfoRegex));

  if (!date)
    return;

  var courses = [];
  $('table[width="0"] > tbody > tr').each(function(i) {
    if (i === 0)
      return;

    $(this).find('td').each(function(j) {
      if (j === 0)
        return;

      var tableDataCell =  $(this).html();
      if (tableDataCell === '')
        return;

      var courseInfoTable = tableDataCell.split('<br>');
      for (var k in courseInfoTable) {
        var courseInfo = courseInfoTable[k].match(/\s*(\S*)\s*(\S*)\s*(\S*)\s*(\S*).*/);
        var rawWeekRange = courseInfo[2];

        if (rawWeekRange.indexOf(',') != -1) {
          var rawWeekRangeTable = rawWeekRange.split(',');

          for (var key in rawWeekRangeTable) {
            if (rawWeekRangeTable[key].indexOf('-') != -1) {
              if (rawWeekRangeTable[key].indexOf('单') != -1 || rawWeekRangeTable[key].indexOf('双') != -1) {
                courses.push({
                  courseName: courseInfo[1],
                  weekRange: rawWeekRangeTable[key].match(/\D*(\d*)\D*(\d*)\D*/).slice(1),
                  recurrenceType: 'HALF',
                  teacherName: courseInfo[3],
                  location: courseInfo[4],
                  classBegin: getClassTime(i).start,
                  classEnd: getClassTime(i + parseInt($(this).attr('rowspan')) - 1).end,
                  weekDay: j
                });
              } else {
                courses.push({
                  courseName: courseInfo[1],
                  weekRange: rawWeekRangeTable[key].match(/\D*(\d*)\D*(\d*)\D*/).slice(1),
                  recurrenceType: 'FULL',
                  teacherName: courseInfo[3],
                  location: courseInfo[4],
                  classBegin: getClassTime(i).start,
                  classEnd: getClassTime(i + parseInt($(this).attr('rowspan')) - 1).end,
                  weekDay: j
                });
              }
            } else {
              courses.push({
                courseName: courseInfo[1],
                weekRange: rawWeekRangeTable[key].match(/\D*(\d*)\D*/)[1],
                recurrenceType: 'SINGLE',
                teacherName: courseInfo[3],
                location: courseInfo[4],
                classBegin: getClassTime(i).start,
                classEnd: getClassTime(i + parseInt($(this).attr('rowspan')) - 1).end,
                weekDay: j
              });
            }
          }
        } else if (rawWeekRange.indexOf('单') != -1 || rawWeekRange.indexOf('双') != -1) {
          courses.push({
            courseName: courseInfo[1],
            weekRange: rawWeekRange.match(/\D*(\d*)\D*(\d*)\D*/).slice(1),
            recurrenceType: 'HALF',
            teacherName: courseInfo[3],
            location: courseInfo[4],
            classBegin: getClassTime(i).start,
            classEnd: getClassTime(i + parseInt($(this).attr('rowspan')) - 1).end,
            weekDay: j
          });
        } else {
          courses.push({
            courseName: courseInfo[1],
            weekRange: rawWeekRange.match(/\D*(\d*)\D*(\d*)\D*/).slice(1),
            recurrenceType: 'FULL',
            teacherName: courseInfo[3],
            location: courseInfo[4],
            classBegin: getClassTime(i).start,
            classEnd: getClassTime(i + parseInt($(this).attr('rowspan')) - 1).end,
            weekDay: j
          });
        }
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

function exitScript() {
  $('#sync_panel').remove();
  $('#sync_button').prop('disabled', false);
}

function hook() {
  var syncButton = '<button id="sync_button" type="button" class="btn btn-large btn-info">同步至Google Calendar</button>';
  $('body').append(syncButton);
  $('#sync_button').click(function() {
    $(this).prop('disabled', true);
    settingPanel();
  });
}

hook();