path = require 'path'
KeybindingsPanel = require '../lib/keybindings-panel'

describe "KeybindingsPanel", ->
  [keyBindings, panel] = []

  beforeEach ->
    expect(atom.keymap).toBeDefined()
    keyBindings = [
      {
        source: "#{atom.getLoadSettings().resourcePath}#{path.sep}keymaps"
        keystrokes: 'ctrl-a'
        command: 'core:select-all'
        selector: '.editor, .platform-test'
      }
      {
        source: "#{atom.getLoadSettings().resourcePath}#{path.sep}keymaps"
        keystrokes: 'ctrl-u'
        command: 'core:undo'
        selector: ".platform-test"
      }
      {
        source: "#{atom.getLoadSettings().resourcePath}#{path.sep}keymaps"
        keystrokes: 'ctrl-u'
        command: 'core:undo'
        selector: ".platform-a, .platform-b"
      }
    ]
    spyOn(atom.keymap, 'getKeyBindings').andReturn(keyBindings)
    panel = new KeybindingsPanel

  it "loads and displays core key bindings", ->
    expect(panel.keybindingRows.children().length).toBe 1

    row = panel.keybindingRows.children(':first')
    expect(row.find('.keystroke').text()).toBe 'ctrl-a'
    expect(row.find('.command').text()).toBe 'core:select-all'
    expect(row.find('.source').text()).toBe 'Core'
    expect(row.find('.selector').text()).toBe '.editor, .platform-test'

  describe "when a keybinding is copied", ->
    describe "when the keybinding file ends in .cson", ->
      it "writes a CSON snippet to the clipboard", ->
        spyOn(atom.keymap, 'getUserKeymapPath').andReturn 'keymap.cson'
        panel.find('.copy-icon').click()
        expect(atom.clipboard.read()).toBe """
          '.editor, .platform-test':
            'ctrl-a': 'core:select-all'
        """

    describe "when the keybinding file ends in .json", ->
      it "writes a JSON snippet to the clipboard", ->
        spyOn(atom.keymap, 'getUserKeymapPath').andReturn 'keymap.json'
        panel.find('.copy-icon').click()
        expect(atom.clipboard.read()).toBe """
          ".editor, .platform-test": {
            "ctrl-a": "core:select-all"
          }
        """

  describe "when the key bindings change", ->
    it "reloads the key bindings", ->
      keyBindings.push
        source: atom.keymap.getUserKeymapPath(), keystrokes: 'ctrl-b', command: 'core:undo', selector: '.editor'
      atom.keymap.emit 'reloaded-key-bindings'

      waitsFor ->
        panel.keybindingRows.children().length is 2

      runs ->
        row = panel.keybindingRows.children(':last')
        expect(row.find('.keystroke').text()).toBe 'ctrl-b'
        expect(row.find('.command').text()).toBe 'core:undo'
        expect(row.find('.source').text()).toBe 'User'
        expect(row.find('.selector').text()).toBe '.editor'
