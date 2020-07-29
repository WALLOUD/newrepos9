path = require 'path'
fs = require 'fs'

_ = require 'underscore-plus'
CSON = require 'season'
Q = require 'q'

PackageManager = require '../lib/package-manager'
ThemesPanel = require '../lib/themes-panel'
SettingsView = require '../lib/settings-view'

describe "ThemesPanel", ->
  [panel, packageManager, reloadedHandler] = []
  settingsView = null

  beforeEach ->
    settingsView = new SettingsView
    atom.packages.loadPackage('atom-light-ui')
    atom.packages.loadPackage('atom-dark-ui')
    atom.packages.loadPackage('atom-light-syntax')
    atom.packages.loadPackage('atom-dark-syntax')
    atom.packages.packageDirPaths.push(path.join(__dirname, 'fixtures'))
    atom.config.set('core.themes', ['atom-dark-ui', 'atom-dark-syntax'])
    reloadedHandler = jasmine.createSpy('reloadedHandler')
    atom.themes.onDidChangeActiveThemes(reloadedHandler)
    atom.themes.activatePackages()

    waitsFor "themes to be reloaded", ->
      reloadedHandler.callCount is 1

    runs ->
      packageManager = new PackageManager
      themeMetadata = CSON.readFileSync(path.join(__dirname, 'fixtures', 'a-theme', 'package.json'))
      spyOn(packageManager, 'getFeatured').andCallFake (callback) ->
        Q([themeMetadata])
      panel = new ThemesPanel(packageManager)
      settingsView.addPanel('Themes', null, -> panel)

      # Make updates synchronous
      spyOn(panel, 'scheduleUpdateThemeConfig').andCallFake -> @updateThemeConfig()

  afterEach ->
    atom.packages.unloadPackage('a-theme') if atom.packages.isPackageLoaded('a-theme')
    atom.themes.deactivateThemes()

  it "selects the active syntax and UI themes", ->
    expect(panel.uiMenu.val()).toBe 'atom-dark-ui'
    expect(panel.syntaxMenu.val()).toBe 'atom-dark-syntax'

  describe "when a UI theme is selected", ->
    it "updates the 'core.themes' config key with the selected UI theme", ->
      panel.uiMenu.val('atom-light-ui').trigger('change')
      expect(atom.config.get('core.themes')).toEqual ['atom-light-ui', 'atom-dark-syntax']

  describe "when a syntax theme is selected", ->
    it "updates the 'core.themes' config key with the selected syntax theme", ->
      panel.syntaxMenu.val('atom-light-syntax').trigger('change')
      expect(atom.config.get('core.themes')).toEqual ['atom-dark-ui', 'atom-light-syntax']

  describe "when the 'core.config' key changes", ->
    it "refreshes the theme menus", ->
      reloadedHandler.reset()
      atom.config.set('core.themes', ['atom-light-ui', 'atom-light-syntax'])

      waitsFor ->
        reloadedHandler.callCount is 1

      runs ->
        expect(panel.uiMenu.val()).toBe 'atom-light-ui'
        expect(panel.syntaxMenu.val()).toBe 'atom-light-syntax'

  xdescribe "when the themes panel is navigated to", ->
    xit "focuses the search filter", ->
      settingsView.showPanel('Themes')
      expect(panel.filterEditor.hasFocus()).toBe true

  describe "theme lists", ->
    [installed] = []
    beforeEach ->
      installed = JSON.parse fs.readFileSync(path.join(__dirname, 'fixtures', 'installed.json'))
      spyOn(packageManager, 'loadCompatiblePackageVersion').andCallFake ->
      spyOn(packageManager, 'getInstalled').andReturn Promise.resolve(installed)
      panel = new ThemesPanel(packageManager)

      waitsFor ->
        packageManager.getInstalled.callCount is 1 and panel.communityCount.text().indexOf('…') < 0

    it 'shows the themes', ->
      expect(panel.communityCount.text().trim()).toBe '1'
      expect(panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 1

      expect(panel.coreCount.text().trim()).toBe '1'
      expect(panel.corePackages.find('.package-card:not(.hidden)').length).toBe 1

      expect(panel.devCount.text().trim()).toBe '1'
      expect(panel.devPackages.find('.package-card:not(.hidden)').length).toBe 1

    it 'filters themes by name', ->
      panel.filterEditor.getModel().setText('user-')
      window.advanceClock(panel.filterEditor.getModel().getBuffer().stoppedChangingDelay)
      expect(panel.communityCount.text().trim()).toBe '1/1'
      expect(panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 1

      expect(panel.coreCount.text().trim()).toBe '0/1'
      expect(panel.corePackages.find('.package-card:not(.hidden)').length).toBe 0

      expect(panel.devCount.text().trim()).toBe '0/1'
      expect(panel.devPackages.find('.package-card:not(.hidden)').length).toBe 0

    it 'adds newly installed themes to the list', ->
      [installCallback] = []
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        installCallback = callback
        onWillThrowError: ->
      spyOn(atom.packages, 'loadPackage').andCallFake (name) =>
        installed.user.push {name, theme: 'ui'}

      expect(panel.communityCount.text().trim()).toBe '1'
      expect(panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 1

      packageManager.install({name: 'another-user-theme', theme: 'ui'})
      installCallback(0, '', '')

      advanceClock ThemesPanel.loadPackagesDelay
      waits 1
      runs ->
        expect(panel.communityCount.text().trim()).toBe '2'
        expect(panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 2
