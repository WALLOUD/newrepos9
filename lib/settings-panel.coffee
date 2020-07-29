{$, $$, View, TextEditorView} = require 'atom'
_ = require 'underscore-plus'

module.exports =
class SettingsPanel extends View
  @content: ->
    @div class: 'settings-panel'

  initialize: (namespace, @options={}) ->
    settings = atom.config.getSettings()
    @appendSettings(namespace, settings[namespace])

    @bindCheckboxFields()
    @bindSelectFields()
    @bindEditors()

  appendSettings: (namespace, settings) ->
    return if _.isEmpty(settings)

    includeTitle = @options.includeTitle ? true
    if includeTitle
      title = "#{_.undasherize(_.uncamelcase(namespace))} Settings"
    else
      title = "Settings"

    @append $$ ->
      @section class: 'config-section', =>
        @div class: 'block section-heading icon icon-gear', title
        @div class: 'section-body', =>
          for name in _.keys(settings).sort()
            appendSetting.call(this, namespace, name, settings[name])

  bindCheckboxFields: ->
    for input in @find('input[id]').toArray()
      do (input) =>
        input = $(input)
        name = input.attr('id')
        type = input.attr('type')

        @subscribe atom.config.observe name, (value) ->
          if type is 'checkbox'
            input.prop('checked', value)
          else
            input.val(value) if value

        input.on 'change', =>
          value = input.val()
          if type == 'checkbox'
            value = !!input.prop('checked')
          else
            value = @parseValue(type, value)

          atom.config.set(name, value)

  bindSelectFields: ->
    @find('select[id]').toArray().forEach (select) =>
      select = $(select)
      name = select.attr('id')

      @subscribe atom.config.observe name, (value) ->
        select.val(value)

      select.change ->
        atom.config.set(name, select.val())

  bindEditors: ->
    for editorView in @find('.editor[id]').views()
      do (editorView) =>
        name = editorView.attr('id')
        type = editorView.attr('type')

        if defaultValue = @valueToString(atom.config.getDefault(name))
          editorView.setPlaceholderText("Default: #{defaultValue}")

        @subscribe atom.config.observe name, (value) =>
          if atom.config.isDefault(name)
            stringValue = ''
          else
            stringValue = @valueToString(value) ? ''

          return if stringValue is editorView.getText()
          return if _.isEqual(value, @parseValue(type, editorView.getText()))

          editorView.setText(stringValue)

        editorView.getEditor().getBuffer().on 'contents-modified', =>
          atom.config.set(name, @parseValue(type, editorView.getText()))

  valueToString: (value) ->
    if _.isArray(value)
      value.join(", ")
    else
      value?.toString()

  parseValue: (type, value) ->
    if value == ''
      value = undefined
    else if type == 'number'
      floatValue = parseFloat(value)
      value = floatValue unless isNaN(floatValue)
    else if type == 'array'
      arrayValue = (value or '').split(',')
      value = (val.trim() for val in arrayValue when val)

    value

###
# Space Pen Helpers
###

isEditableArray = (array) ->
  for item in array
    return false unless _.isString(item)
  true

appendSetting = (namespace, name, value) ->
  if namespace is 'core'
    return if name is 'themes' # Handled in the Themes panel
    return if name is 'disabledPackages' # Handled in the Packages panel

  @div class: 'control-group', =>
    @div class: 'controls', =>
      if atom.config.getSchema("#{namespace}.#{name}")?.enum
        appendOptions.call(this, namespace, name, value)
      else if _.isBoolean(value)
        appendCheckbox.call(this, namespace, name, value)
      else if _.isArray(value)
        appendArray.call(this, namespace, name, value) if isEditableArray(value)
      else if _.isObject(value)
        appendObject.call(this, namespace, name, value)
      else
        appendEditor.call(this, namespace, name, value)

getSettingTitle = (keyPath, name='') ->
  title = atom.config.getSchema(keyPath)?.title
  title or _.uncamelcase(name).split('.').map(_.capitalize).join(' ')

getSettingDescription = (keyPath) ->
  atom.config.getSchema(keyPath)?.description or ''

appendOptions = (namespace, name, value) ->
  keyPath = "#{namespace}.#{name}"
  title = getSettingTitle(keyPath, name)
  description = getSettingDescription(keyPath)
  options = atom.config.getSchema(keyPath)?.enum ? []

  @label class: 'control-label', =>
    @div class: 'setting-title', title
    @div class: 'setting-description', description

  @select id: keyPath, class: 'form-control', =>
    for option in options
      @option value: option, option

appendCheckbox = (namespace, name, value) ->
  keyPath = "#{namespace}.#{name}"
  title = getSettingTitle(keyPath, name)
  description = getSettingDescription(keyPath)

  @div class: 'checkbox', =>
    @label for: keyPath, =>
      @input id: keyPath, type: 'checkbox'
      @div class: 'setting-title', title
      @div class: 'setting-description', description

appendEditor = (namespace, name, value) ->
  keyPath = "#{namespace}.#{name}"
  if _.isNumber(value)
    type = 'number'
  else
    type = 'string'

  title = getSettingTitle(keyPath, name)
  description = getSettingDescription(keyPath)

  @label class: 'control-label', =>
    @div class: 'setting-title', title
    @div class: 'setting-description', description

  @div class: 'controls', =>
    @div class: 'editor-container', =>
      @subview keyPath.replace(/\./g, ''), new TextEditorView(mini: true, attributes: {id: keyPath, type: type})

appendArray = (namespace, name, value) ->
  keyPath = "#{namespace}.#{name}"
  title = getSettingTitle(keyPath, name)
  description = getSettingDescription(keyPath)

  @label class: 'control-label', =>
    @div class: 'setting-title', title
    @div class: 'setting-description', description

  @div class: 'controls', =>
    @div class: 'editor-container', =>
      @subview keyPath.replace(/\./g, ''), new TextEditorView(mini: true, attributes: {id: keyPath, type: 'array'})

appendObject = (namespace, name, value) ->
  for key in _.keys(value).sort()
    appendSetting.call(this, namespace, "#{name}.#{key}", value[key])
