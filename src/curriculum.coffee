CourseParser = window.CourseParser

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
oauth2WithGoogleStepTemplate = """<p>Google验证服务及API被GFW干扰，请使用代理（翻墙）保证同步过程正常。</p>
<p>点击下面的按钮获得Google的授权：</p>
<div class="panel-button">
  <button id="auth-google" type="button" class="btn btn-large btn-primary">获取Google授权</button>
</div>
"""

onSaveCurriculumButtonClick = (e) ->
  e.preventDefault()

  parser = new CourseParser
  calendar = parser.parseCurriculum()

  saveCurriculum calendar

saveCurriculum = (data) ->
  calendar =
    calendar: data
    lastUpdated: moment().format('MMMDo');

  chrome.storage.local.set calendar, ->
    refreshLastUpdated

refreshLastUpdated = ->
  chrome.storage.local.get 'lastUpdated', (blob) ->
    $('#last-updated').text blob.lastUpdated

onSyncCurriculumButtonClick = (e) ->
  e.preventDefault()
  $('#sync-curriculum').prop('disabled', true);

  $('body').append syncPanelTemplate
  $(document).mouseup (e) ->
    container = $('#sync-panel');

    cleanPanel() if !container.is e.target && container.has(e.target).length == 0

  wizard()

cleanPanel = ->
  $('#sync_panel').remove();
  $('#sync_button').prop('disabled', false);

wizard = ->
  # Step: 1
  oauth2WithGoogle =
    title: '授权'
    content: oauth2WithGoogleStepTemplate
  wizard = $('#sync-panel-body').steps()
  wizard.steps 'add', oauth2WithGoogle

  authGoogleButton = $('#auth-google')
  authGoogleButton.click ->
    authGoogleButton.prop 'disabled', true
    chrome.runtime.sendMessage {type: 'AUTH_GOOGLE'}, (response) ->



options =
  position: 'right'
  open: 'click'

$(document).ready ->
  $('body').append sidebarTemplate

  refreshLastUpdated()
  $('#save-curriculum').on 'click', onSaveCurriculumButtonClick
  $('#sync-curriculum').on 'click', onSyncCurriculumButtonClick

  $('#sidebar').sidebar options