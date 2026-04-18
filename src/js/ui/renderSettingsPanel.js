(function (game) {
  var format = game.utils.format;

  function renderSettingsPanel(state) {
    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">设置页面</p>' +
      '<h2 class="page-title">管理本地存档与基础选项</h2>' +
      '<p class="page-copy">这里可以修改玩家名字、切换自动存档、导出 JSON、导入已有存档，或重新开档。</p>' +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">存档信息</p>' +
      '<p class="page-copy">当前使用 `localStorage` 保存，主键为 `catGameSaveV1`。</p>' +
      '<p class="helper-text" style="margin-top: 8px;">当前版本：v' +
      format.escapeHtml(game.config.version) +
      "</p>" +
      '<p class="helper-text" style="margin-top: 8px;">最近保存：' +
      format.escapeHtml(state.meta.lastSavedAt || "尚未保存") +
      "</p></div></section>" +
      '<section class="settings-grid">' +
      '<div class="settings-card">' +
      '<p class="section-eyebrow">基础设置</p>' +
      '<div class="setting-row"><label for="player-name-input">玩家名字</label></div>' +
      '<input id="player-name-input" class="field" type="text" maxlength="12" value="' +
      format.escapeHtml(state.player.name) +
      '" />' +
      '<div class="inline-row" style="margin-top: 14px;"><button class="primary-button" data-rename-player>保存名字</button>' +
      '<span class="task-meta">建议保持 12 字以内</span></div>' +
      '<div class="setting-row" style="margin-top: 18px;"><label for="setting-auto-save">自动存档</label>' +
      '<input id="setting-auto-save" class="toggle-field" type="checkbox" data-setting-key="autoSave" ' +
      (state.settings.autoSave ? "checked" : "") +
      " /></div>" +
      '<div class="setting-row"><label for="setting-bgm">背景音量</label><span>' +
      state.settings.bgmVolume +
      "</span></div>" +
      '<input id="setting-bgm" class="range-field" type="range" min="0" max="100" value="' +
      state.settings.bgmVolume +
      '" data-setting-key="bgmVolume" />' +
      '<div class="setting-row" style="margin-top: 16px;"><label for="setting-sfx">音效音量</label><span>' +
      state.settings.sfxVolume +
      "</span></div>" +
      '<input id="setting-sfx" class="range-field" type="range" min="0" max="100" value="' +
      state.settings.sfxVolume +
      '" data-setting-key="sfxVolume" />' +
      "</div>" +
      '<div class="settings-card">' +
      '<p class="section-eyebrow">导出存档</p>' +
      '<button class="primary-button" data-export-save>导出 JSON 文件</button>' +
      '<p class="helper-text" style="margin-top: 12px;">下面会同步显示当前存档文本，方便手动复制备份。</p>' +
      '<textarea class="textarea-field" readonly>' +
      format.escapeHtml(game.state.saveSystem.exportText()) +
      "</textarea></div>" +
      "</section>" +
      '<section class="settings-grid" style="margin-top: 18px;">' +
      '<div class="settings-card">' +
      '<p class="section-eyebrow">导入存档</p>' +
      '<textarea id="save-import-text" class="textarea-field" placeholder="把导出的 JSON 存档粘贴到这里"></textarea>' +
      '<div class="inline-row" style="margin-top: 14px; flex-wrap: wrap;">' +
      '<button class="secondary-button" data-import-save>导入文本存档</button>' +
      '<label class="ghost-button" for="save-import-file">选择 JSON 文件</label>' +
      '<input id="save-import-file" type="file" accept=".json,application/json" style="display:none;" />' +
      "</div></div>" +
      '<div class="settings-card">' +
      '<p class="section-eyebrow">危险操作</p>' +
      '<p class="page-copy">重置后会立刻生成新档，并覆盖当前本地进度。</p>' +
      '<button class="ghost-button" style="margin-top: 16px;" data-reset-save>重置存档</button>' +
      "</div></section>"
    );
  }

  game.ui.renderSettingsPanel = renderSettingsPanel;
})(window.CatGame);
