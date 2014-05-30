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

  constructor: ->
    @idealCourseTable = $(IDEAL_COURSE_TABLE_SELECTOR)
    @termInfo = $(TERM_INFO_SELECTOR)

    @enrolledCourses = []
    @idealCourses = []

  parse: ->
    @parseEnrolledCourseTable()

  _nthTdChild: (id) ->
    template = "td:nth-child(#{id + 1})"
    template += ' *:not([width="100"])' if id == 1
    return template

  _tableCellText: (row, id) ->
    cell = $(row).find(@._nthTdChild(id))
    $.trim(cell.text())

  parseEnrolledCourseTable: ->
    self = @

    enrolledCourseTable = $(ENROLLED_COURSE_TABLE_SELECTOR)
    rows = enrolledCourseTable.find('> tbody > tr')

    headerRow = $(rows[0])
    courseRows = $(rows[1..])

    withDeleteLink = headerRow.html().indexOf('删除') != -1
    columnId = if withDeleteLink then ENROLLED_COURSE_TABLE_COLUMN_ID_WITH_DELETE else ENROLLED_COURSE_TABLE_COLUMN_ID

    @enrolledCourses = courseRows.map(->

      course = 
        courseId: self._tableCellText(@, columnId.id)
        courseName: self._tableCellText(@, columnId.name)
        grade: self._tableCellText(@, columnId.grade)
        internalId: self._tableCellText(@, columnId.internalId)
        teacherName: self._tableCellText(@, columnId.teacherName)

    ).get()
    console.log @enrolledCourses


p = new CourseParser()
p.parse()