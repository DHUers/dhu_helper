sidebarTemplate = """<div id="sidebar">
<p id="last-updated"></p>
</div>"""
openSidebarButtonTemplate = """<button id="sidebar-switch" class="btn btn-large btn-primary">打开侧栏</button>"""
sidrOptions =
  name: 'sidebar'
  side: 'right'
  onClose: ->
    $('body').append openSidebarButtonTemplate
    $('#sidebar-switch').on 'click', ->
      $.sidr 'open', 'sidebar'
      $(@).remove()

$(document).ready ->
  $('body').append sidebarTemplate

  chrome.storage.local.get 'calendar', (calendar) ->
    lastUpdated = if calendar.lastUpdated? then calendar.lastUpdated else '未保存课表信息'
    $('#last-updated').text lastUpdated

  $('#sidebar').sidr sidrOptions
