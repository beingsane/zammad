class App.CTI extends App.Controller
  events:
    'click .js-check': 'done'

  constructor: ->
    super

    return if !@isRole('CTI')

    @list = []
    @backends = []
    @meta =
      active: false
      counter: 0
      state: {}

    preferences = @Session.get('preferences') || {}
    @meta.active = preferences.cti || false

    @load()

    @bind('cti_event', (data) =>
      if data.direction is 'in'
        if data.state is 'newCall'
          if @switch()
            @notify(data)
          return if @meta.state[data.id]
          @meta.state[data.id] = true
          @meta.counter += 1
          @updateNavMenu()
        if data.state is 'answer' || data.state is 'hangup'
          return if !@meta.state[data.id]
          delete @meta.state[data.id]
          @meta.counter -= 1
          @updateNavMenu()
      'cti_event'
    )
    @bind('cti_list_push', (data) =>
      if data.assets
        App.Collection.loadAssets(data.assets)
      if data.backends
        @backends = data.backends
      if data.list
        @list = data.list
        @render()
      'cti_list_push'
    )
    @bind('auth', (data) =>
      @meta.counter = 0
    )

    @bind('cti:reload', =>
      @load()
      'cti_reload'
    )

    # rerender view, e. g. on langauge change
    @bind('ui:rerender', =>
      @render()
      'cti_rerender'
    )

  # fetch data, render view
  load: ->
    @ajax(
      id:    'cti_log'
      type:  'GET'
      url:   "#{@apiPath}/cti/log"
      success: (data) =>
        if data.assets
          App.Collection.loadAssets(data.assets)
        if data.backends
          @backends = data.backends
        if data.list
          @list = data.list
          @render()
    )

  notify: (data) ->
    text = App.i18n.translateContent('Call from %s for %s', data.from_comment || data.from, data.to_comment || data.to)
    title = App.Utils.html2text(text.replace(/<.+?>/g, '"'))
    @notifyDesktop(
      url: '#cti'
      title: title
    )

  featureActive: ->
    true

  render: ->
    if !@isRole('CTI')
      @renderScreenUnauthorized(objectName: 'CTI')
      return

    # check if min one backend is enabled
    backendEnabled = false
    for backend in @backends
      if backend.enabled
        backendEnabled = true
    if !backendEnabled
      @html App.view('cti/not_configured')(
        backends: @backends
        isAdmin: @isRole('Admin')
      )
      @updateNavMenu()
      return

    format = (time) ->
      # Minutes and seconds
      mins = ~~(time / 60)
      secs = time % 60

      # Hours, minutes and seconds
      hrs = ~~(time / 3600)
      mins = ~~((time % 3600) / 60)
      secs = time % 60

      # Output like "1:01" or "4:03:59" or "123:03:59"
      mins = "0#{mins}" if mins < 10
      secs = "0#{secs}" if secs < 10
      if hrs > 0
        return "#{hrs}:#{mins}:#{secs}"
      "#{mins}:#{secs}"

    for item in @list
      item.status_class = ''

      if item.state is 'newCall'
        item.state_human = 'ringing'
        item.status_class = 'neutral'
      else if item.state is 'answer'
        item.state_human = 'connected'
        item.status_class = 'ok'
      else if item.state is 'hangup'
        item.state_human = switch item.comment
          when 'cancel', 'noAnswer', 'congestion' then 'not reached'
          when 'busy' then 'busy'
          when 'notFound' then 'not exist'
          when 'normalClearing' then ''
          else item.comment
      else
        item.state_human = item.state
        if item.comment
          item.state_human += ", #{item.comment}"

      if item.start && item.end
        item.duration = format((Date.parse(item.end) - Date.parse(item.start))/1000)

    @userPopupsDestroy()
    @html App.view('cti/index')(
      list: @list
    )
    @userPopups()
    @updateNavMenu()

  done: (e) =>
    element = $(e.currentTarget)
    id = element.closest('tr').data('id')
    done = element.prop('checked')
    @ajax(
      type:  'POST'
      url:   "#{@apiPath}/cti/done/#{id}"
      data:  JSON.stringify(done: done)
    )

  show: (params) =>
    @title 'CTI', true
    @navupdate '#cti'

  active: (state) =>
    return @shown if state is undefined
    @shown = state

  counter: =>
    count = 0
    for item in @list
      if item.state is 'hangup' && !item.done
        count++
    @meta.counter + count

  switch: (state = undefined) =>

    # read state
    if state is undefined
      return @meta.active

    @meta.active = state

    # update user preferences
    @ajax(
      id:          'preferences'
      type:        'PUT'
      url:         "#{@apiPath}/users/preferences"
      data:        JSON.stringify(user: {cti: state})
      processData: true
    )

class CTIRouter extends App.ControllerPermanent
  constructor: (params) ->
    super

    # check authentication
    return if !@authenticate(false, 'CTI')

    App.TaskManager.execute(
      key:        'CTI'
      controller: 'CTI'
      params:     {}
      show:       true
      persistent: true
    )

App.Config.set('cti', CTIRouter, 'Routes')
App.Config.set('CTI', { controller: 'CTI', authentication: true }, 'permanentTask')
App.Config.set('CTI', { prio: 1300, parent: '', name: 'Phone', target: '#cti', key: 'CTI', shown: false, role: ['CTI'], class: 'phone' }, 'NavBar')