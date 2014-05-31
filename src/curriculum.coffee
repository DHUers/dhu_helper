CourseParser = window.CourseParser
DHUInternel = window.DHUInternel

sidebarTemplate = """<ul id="sidebar">
  <li><span id="last-updated">未保存课表信息</span></li>
  <li><button id="save-curriculum" class="btn btn-large btn-primary">保存课表</button></li>
  <hr>
  <li><button id="sync-curriculum" class="btn btn-large btn-primary">与Google Calendar同步</button></li>
</ul>
"""
syncPanelTemplate = """<div id="sync-panel" class="panel panel-success">
  <div class="panel-heading">
    <h3 class="panel-title">设置</h3>
  </div>
  <div id="sync-panel-body" class="panel-body">
  </div>
</div>
"""
# Step 1
oauth2WithGoogleStepTemplate = """<p>Google验证服务及API被GFW干扰，请使用代理（翻墙）保证同步过程正常。</p>
<p>点击下面的按钮获得Google的授权：</p>
<div class="panel-button">
  <button id="auth-google" type="button" class="btn btn-large btn-primary">获取Google授权</button>
</div>
"""
# Step 2
calendarMetaTemplate = """
<p>日历设置：</p>
<input type="text" value="Curriculum" placeholder="日历名" maxlength="32" class="form-control" id="calendar-name" required>
<div id="reminder-setting">
  <p>提醒设置：</p>
</div>
<button type="button" class="btn btn-large btn-primary" id="add-reminder-setting">添加</button>
<br>
<button id="sync-calendar" type="button" class="btn btn-large btn-success">同步</button></div>
"""
reminderSettingTemplate = """
<div class="row">
  <div class="col-lg-4">
    <select class="calendar-remind-method form-control" required>
      <option value="email">电子邮件</option>
      <option value="popup" selected>弹出窗口</option>
    </select>
  </div>
  <div class="col-lg-6">
    <input class="calendar-remind-time form-control" type="number" step="1" value="18" max="30" max="1" required>
  </div>
  <button class="btn btn-danger calendar-remind-delete-button">删除</button>
</div>
"""

onSaveCurriculumButtonClick = (e) ->
  e.preventDefault()

  parser = new CourseParser
  calendar = parser.parseCurriculum()

  saveCurriculum calendar

saveCurriculum = (data) ->
  calendar =
    curriculum: data
    lastUpdated: moment().format('MMMDo h:mm:ss');
  console.log calendar

  chrome.storage.local.set calendar, ->
    refreshLastUpdated

refreshLastUpdated = ->
  chrome.storage.local.get 'lastUpdated', (blob) ->
    $('#last-updated').text blob.lastUpdated

onSyncCurriculumButtonClick = (e) ->
  e.preventDefault()

  $('body').append syncPanelTemplate

  wizard()

wizard = ->
  setting =
    enablePagination: false
    onFinishing: validateMeta
    onFinished: syncCalendar

  wizard = $('#sync-panel-body').steps(setting)

  # Step: 1
  oauth2WithGoogle =
    title: '授权'
    content: oauth2WithGoogleStepTemplate
    enablePagination: false
  wizard.steps 'add', oauth2WithGoogle

  authGoogleButton = $('#auth-google')
  authGoogleButton.click ->
    authGoogleButton.prop 'disabled', true
    chrome.runtime.sendMessage {type: 'AUTH_GOOGLE'}, (response) ->
      console.log "Step 1: #{response.status}" 
      if response.status
        wizard.steps 'next'
      else
        authGoogleButton.prop 'disabled', false

  # Step: 2
  calendarMeta =
    title: '日历设置'
    content: calendarMetaTemplate
  wizard.steps 'add', calendarMeta
  $('#add-reminder-setting').click ->
    $('#reminder-setting').append(reminderSettingTemplate)
    $('.calendar-remind-delete-button').each ->
      $(@).click ->
        $(@).parent().remove()

  $('#sync-calendar').click ->
    wizard.steps 'finish'

validateMeta = ->
  $('#calendar-name').attr('value').length > 0

syncCalendar = ->
  # get filled wizard
  calendarName = $('#calendar-name').attr('value')

  methods = $('.calendar-remind-method').map(-> return $(@).val()).get()
  time = $('.calendar-remind-time').map(-> return $(@).attr('value')).get()

  calendarReminder = []
  for i, v of methods
    calendarReminder.push
      method: methods[i]
      minutes: time[i]

  chrome.runtime.sendMessage
    type: 'SYNC_CALENDAR_EVENT'
    data:
      name: calendarName
      reminder: calendarReminder

sidebarOptions =
  position: 'right'
  open: 'click'

$(document).ready ->
  $('body').append sidebarTemplate

  refreshLastUpdated()
  $('#save-curriculum').on 'click', onSaveCurriculumButtonClick
  $('#sync-curriculum').on 'click', onSyncCurriculumButtonClick

  $('#sidebar').sidebar sidebarOptions