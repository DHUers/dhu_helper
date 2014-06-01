sidebarTemplate = """<ul id="sidebar">
  <li><button id="control-display-button" type="button" class="btn btn-large btn-info">只显示未获得学分课程</button></li>
</ul>
"""

filterCourse = (display) ->
  $('tr').each ->
    courseId = $(@).find('td:nth-child(2)').text()
    return if typeof parseInt(courseId) != 'number' || isNaN(parseInt(courseId))
      
    row = $(@);
    row.find('font').each ->
      courseId = $(this).text()
      return if typeof parseInt(courseId) != 'number' || isNaN(parseInt(courseId))

      if (display)
        row.addClass 'hide-course'
      else
        row.removeClass 'hide-course' if row.hasClass 'hide-course'

onControlDisplayButtonClicked = ->
  if $(@).text() == '只显示未获得学分课程'
    $(@).text '显示所有课程'
    filterCourse true
  else
    $(@).text '只显示未获得学分课程'
    filterCourse false

sidebarOptions =
  position: 'right'
  open: 'click'

$(document).ready ->
  $('body').append sidebarTemplate

  $('#control-display-button').click onControlDisplayButtonClicked

  $('tr').each ->
    courseId = $(@).find('td:nth-child(2)').text()
    return if typeof parseInt(courseId) != 'number' || isNaN(parseInt(courseId))
    $(@).addClass('course-item')

  $('#sidebar').sidebar sidebarOptions
