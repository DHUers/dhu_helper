CourseParser = window.CourseParser

collisionTest = (course, collisionTable) ->
  console.log course, collisionTable

  for i, detail of course
    switch detail.week[0]
      when 'SINGLE' then weekNums = detail.week[1..]
      when 'FULL' then weekNums = [detail.week[1]..detail.week[2]]
      when 'HALF'
        weekNums = []
        for number in [detail.week[1]..detail.week[2]] by 2
          weekNums.push number

    for j, weekNum of weekNums
      if collisionTable[weekNum] &&
         collisionTable[weekNum][detail.time[0]]
        for k, v of detail.time[1..]
          #console.log collisionTable[weekNum][detail.time[0]], v
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
        console.log "Highlight row #AutoNumber2 tr:nth-child(#{parseInt(i) + 2})"
        $("#AutoNumber2 tr:nth-child(#{parseInt(i) + 2})").css('background-color', '#fc5050')
        #$("#AutoNumber2 tr:nth-child(#{(i + 1) * 2 + 1})").css 'background-color', 'red'