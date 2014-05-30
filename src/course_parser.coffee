class CourseParser
  ENROLLED_COURSE_TABLE_SELECTOR = 'table[width="900"]'
  IDEAL_COURSE_TABLE_SELECTOR    = 'table[width="899"]'
  TERM_INFO_SELECTOR             = 'table[height="30"] caption'

  ENROLLED_COURSE_TABLE_COLUMN_ID =
    id: 0
    name: 1
    grade: 2
    internalId: 4
    teacherName: 6
    timeTable: 7
  ENROLLED_COURSE_TABLE_COLUMN_ID_WITH_DELETE =
    id: 0
    name: 1
    grade: 2
    internalId: 4
    teacherName: 7
    timeTable: 8
  IDEAL_COURSE_TABLE_COLUMN_ID =
    id: 0
    name: 1
    grade: 2
    internalId: 5
    teacherName: 8
    timeTable: 9
  IDEAL_COURSE_TABLE_COLUMN_ID_WITH_DELETE =
    id: 0
    name: 1
    grade: 2
    internalId: 5
    teacherName: 9
    timeTable: 10
  TIME_TABLE_COLUMN_ID =
    weekRange: 0
    datetime: 1
    location: 2

  constructor: ->
    @termInfo = $(TERM_INFO_SELECTOR)

    @enrolledCourses = []
    @idealCourses = []

  parse: ->
    @parseEnrolledCourseTable()
    @parseIdealCourseTable()

  _nthTdChild: (id, excludeNestedTable = false) ->
    template = "td:nth-child(#{id + 1})"
    template += '*:not(td[width="100"])' if excludeNestedTable
    return template

  _tableCellText: (row, id, excludeNestedTable = false) ->
    cell = $(row).find(@._nthTdChild(id, excludeNestedTable))
    $.trim(cell.text())

  # parse awful time and location from nested table
  _parseDetails: (tableDOM) ->
    self = @

    timeTableRows = $($(tableDOM).find('tr'))
    details = timeTableRows.map(->
      timeText = self._tableCellText(@, TIME_TABLE_COLUMN_ID.datetime)
      return if timeText.indexOf('周') == -1 # test if exist time text. if not, no details.

      weekRangeText = self._tableCellText(@, TIME_TABLE_COLUMN_ID.weekRange)
      locationText = self._tableCellText(@, TIME_TABLE_COLUMN_ID.location)

      detail =
        week: self._parseDetailsWeekRangeText(weekRangeText)
        time: self._parseDetailsTimeText(timeText)
        location: self._parseDetailsLocationText(locationText)
    ).get()

  _parseDetailsWeekRangeText: (weekRangeText) ->
    weekRanges = []

    if weekRangeText.indexOf(',') != -1
      weekRanges.push('SINGLE')
      timeTextTable = timeText.split(',')
      for i, v of timeTextTable
        weekRanges = weekRanges.concat(v.match(/\D*(\d*)\D*/)[1].map(Number))
    else if weekRangeText.indexOf('(') != -1
      weekRanges.push('HALF')
      weekRanges = weekRanges.concat(weekRangeText.match(/\D*(\d*)\D*(\d*)\D*/)[1..].map(Number))
    else
      weekRanges.push('FULL')
      weekRanges = weekRanges.concat(weekRangeText.match(/\D*(\d*)\D*(\d*)\D*/)[1..].map(Number))

    weekRanges

  _parseDetailsTimeText: (timeText) ->
    parsed = []

    time = timeText.match(/周(.)(.*)节/)
    return if time == null

    parsed = ['日一二三四五六'.indexOf time[1]].concat time[2].split('.')[1..].map(Number)

  _parseDetailsLocationText: (locationText) ->
    locationText

  _columnIdTable: (withDelete, selector) ->
    switch selector
      when ENROLLED_COURSE_TABLE_SELECTOR
        if withDelete then ENROLLED_COURSE_TABLE_COLUMN_ID_WITH_DELETE else ENROLLED_COURSE_TABLE_COLUMN_ID
      when IDEAL_COURSE_TABLE_SELECTOR
        if withDelete then IDEAL_COURSE_TABLE_COLUMN_ID_WITH_DELETE else IDEAL_COURSE_TABLE_COLUMN_ID

  _parseCourseTable: (selector) ->
    self = @

    selectedCourseTable = $(selector)
    rows = selectedCourseTable.find('> tbody > tr')

    headerRow = $(rows[0])
    courseRows = $(rows[1..])

    withDeleteLink = headerRow.html().indexOf('删除') != -1
    columnId = self._columnIdTable(withDeleteLink, selector)

    courses = courseRows.map(->
      timeTableDOM = $(@).find(self._nthTdChild(columnId.timeTable))

      # other information in the same row
      course =
        courseId: self._tableCellText(@, columnId.id, true)
        courseName: self._tableCellText(@, columnId.name, true)
        grade: self._tableCellText(@, columnId.grade, true)
        internalId: self._tableCellText(@, columnId.internalId)
        teacherName: self._tableCellText(@, columnId.teacherName)
        details: self._parseDetails(timeTableDOM)
    ).get()

  parseEnrolledCourseTable: ->
    @enrolledCourses = @_parseCourseTable(ENROLLED_COURSE_TABLE_SELECTOR)

  parseIdealCourseTable: ->
    @idealCourses = @_parseCourseTable(IDEAL_COURSE_TABLE_SELECTOR)
