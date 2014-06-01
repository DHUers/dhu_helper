CourseParser = window.CourseParser

collisionTest = (course, collisionTable) ->
  console.log course, collisionTable

  for i, detail of course
    weekNums = if detail.week[0] == 'SINGLE' then detail.week[1..] else [detail.week[1]..detail.week[2]]

    for j, weekNum of weekNums
      if collisionTable[weekNum] &&
         collisionTable[weekNum][detail.time[0]]
        for k, v of detail.time[1..]
          return true if collisionTable[weekNum][detail.time[0]].indexOf(v) != -1

  return false

$(document).ready ->
  parser = new CourseParser

  chrome.storage.local.get 'collisionTable', (blob) ->
    collisionTable = blob['collisionTable']

    courses = parser.parseSelectCourse()
    for i, v of courses
      course = v.details
      if collisionTest course, collisionTable
        $("#AutoNumber2 tr:nth-child(#{(i + 1) * 2})").css 'background-color', 'red'
        $("#AutoNumber2 tr:nth-child(#{(i + 1) * 2 + 1})").css 'background-color', 'red'