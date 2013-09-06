'use strict';

function filterCourse(display) {
  $('tr').each(function() {
    var courseId = $(this).find('td:nth-child(2)');
    if (typeof parseInt(courseId.text()) !== 'number' || isNaN(parseInt(courseId.text())))
      return;

    var row = $(this);
    row.find('font').each(function() {
      if (typeof parseInt($(this).text()) !== 'number' || isNaN(parseInt($(this).text())))
        return;

      if (display)
        row.addClass('hide-course');
      else
        if (row.hasClass('hide-course'))
          row.removeClass('hide-course');
    });
  });
}


function hook() {
  var showToolList = '<button id="control-display-button" type="button" class="btn btn-large btn-info">只显示未获得学分课程</button>';
  $('body').append(showToolList);
  $('#control-display-button').click(function() {
    if ($(this).text() === '只显示未获得学分课程') {
      $(this).text('显示所有课程');
      filterCourse(true);
    } else {
      $(this).text('只显示未获得学分课程');
      filterCourse(false);
    }
  });
}

hook();