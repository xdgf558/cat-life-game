(function (game) {
  var format = game.utils.format;
  var dom = {};
  var liveTickId = null;

  function getSelectedCat() {
    var current = game.state.game.cats.find(function (cat) {
      return cat.id === game.state.selectedCatId && cat.unlocked;
    });

    if (current) {
      return current;
    }

    current = game.state.game.cats.find(function (cat) {
      return cat.unlocked;
    });

    game.state.selectedCatId = current ? current.id : null;
    return current;
  }

  function pushNotice(text) {
    if (!text) {
      return;
    }

    game.state.notifications.unshift({
      id: Date.now() + Math.random(),
      text: text,
      time: format.formatGameTime(game.state.game.player),
    });

    game.state.notifications = game.state.notifications.slice(0, 8);
  }

  function persistGame(force) {
    if (force) {
      game.state.saveSystem.saveGame(game.state.game);
      return;
    }
    game.state.saveSystem.autoSave();
  }

  function handleActionResult(result) {
    if (!result) {
      return;
    }

    if (result.messages && result.messages.length) {
      result.messages.forEach(pushNotice);
    } else if (result.message) {
      pushNotice(result.message);
    }

    game.systems.homeSystem.recalculateComfort();
    game.systems.workSystem.refreshJobUnlocks();
    game.systems.taskSystem.refreshAllTasks();
    persistGame(Boolean(result.forceSave));
    render();
  }

  function refreshLiveBindings() {
    var activeWork = game.systems.workSystem.getActiveWork();
    var remainingText = activeWork
      ? format.formatDuration(game.systems.workSystem.getRemainingMs(activeWork))
      : "已完成";

    Array.prototype.forEach.call(document.querySelectorAll("[data-live-clock]"), function (node) {
      node.textContent = format.formatGameTime();
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-active-work-remaining]"), function (node) {
      node.textContent = remainingText;
    });
  }

  function syncRealtime(source) {
    var result = game.systems.timeSystem.syncRealtimeState(source);

    if (result.messages && result.messages.length) {
      result.messages.forEach(pushNotice);
    }

    if (result.changed) {
      game.systems.homeSystem.recalculateComfort();
      game.systems.workSystem.refreshJobUnlocks();
      game.systems.taskSystem.refreshAllTasks();
      persistGame(true);
      render();
      return;
    }

    refreshLiveBindings();
  }

  function renderQuickPanel() {
    var selectedCat = getSelectedCat();
    if (!selectedCat) {
      return '<section class="quick-card"><div class="empty-state">当前还没有可用的猫咪数据。</div></section>';
    }

    var notices = game.state.notifications.length
      ? game.state.notifications
          .map(function (notice) {
            return (
              '<div class="notice-item"><p><strong>' +
              format.escapeHtml(notice.time) +
              "</strong></p><p>" +
              format.escapeHtml(notice.text) +
              "</p></div>"
            );
          })
          .join("")
      : '<div class="empty-state">还没有新的记录，先开始今天的第一件事吧。</div>';

    return (
      '<section class="quick-card">' +
      '<p class="section-eyebrow">快捷信息</p>' +
      '<h3 class="panel-title">' +
      format.escapeHtml(selectedCat.name) +
      "</h3>" +
      '<p class="page-copy">' +
      format.escapeHtml(selectedCat.breed) +
      " · 亲密度 " +
      selectedCat.intimacy +
      "/100</p>" +
      '<div style="margin-top: 14px;">' +
      game.ui.helpers.renderBar("饱腹", selectedCat.hunger) +
      game.ui.helpers.renderBar("清洁", selectedCat.clean) +
      game.ui.helpers.renderBar("心情", selectedCat.mood) +
      "</div></section>" +
      (game.systems.workSystem.hasActiveWork()
        ? '<section class="quick-card"><p class="section-eyebrow">打工倒计时</p><h3 class="panel-title">' +
          format.escapeHtml(game.systems.workSystem.getActiveWork().jobName) +
          '</h3><p class="page-copy">剩余时间：<span data-active-work-remaining>' +
          format.formatDuration(game.systems.workSystem.getRemainingMs(game.systems.workSystem.getActiveWork())) +
          "</span></p></section>"
        : "") +
      '<section class="quick-card">' +
      '<p class="section-eyebrow">最近记录</p>' +
      '<div class="notice-list">' +
      notices +
      "</div></section>"
    );
  }

  function render() {
    var pageRenderers = {
      home: game.ui.renderHome,
      work: game.ui.renderWorkPanel,
      cats: game.ui.renderCatPanel,
      shop: game.ui.renderShopPanel,
      tasks: game.ui.renderTaskPanel,
      settings: game.ui.renderSettingsPanel,
    };
    var renderer = pageRenderers[game.state.currentPage] || game.ui.renderHome;

    dom.header.innerHTML = game.ui.renderHeader(game.state.game);
    dom.main.innerHTML = renderer(game.state.game);
    dom.quick.innerHTML = renderQuickPanel();

    Array.prototype.forEach.call(document.querySelectorAll(".nav-button[data-page-target]"), function (button) {
      button.classList.toggle("is-active", button.dataset.pageTarget === game.state.currentPage);
    });
  }

  function updateSetting(target) {
    var key = target.dataset.settingKey;
    if (!key) {
      return;
    }

    if (target.type === "checkbox") {
      game.state.game.settings[key] = target.checked;
    } else if (target.type === "range") {
      game.state.game.settings[key] = Number(target.value);
    } else {
      game.state.game.settings[key] = target.value;
    }

    game.state.saveSystem.saveGame(game.state.game);
    pushNotice("设置已更新。");
    render();
  }

  function importFromText(rawText) {
    var imported = game.state.saveSystem.importText(rawText);
    game.state.game = imported;
    game.systems.homeSystem.recalculateComfort();
    game.systems.workSystem.refreshJobUnlocks();
    game.systems.taskSystem.refreshAllTasks();
    syncRealtime("import");
    getSelectedCat();
    pushNotice("存档导入成功。");
    render();
  }

  function handleClick(event) {
    var pageButton = event.target.closest("[data-page-target]");
    var catSelectButton = event.target.closest("[data-select-cat]");
    var jobButton = event.target.closest("[data-job-id]");
    var catActionButton = event.target.closest("[data-cat-action]");
    var shopButton = event.target.closest("[data-store-item]");
    var taskButton = event.target.closest("[data-task-claim]");
    var exportButton = event.target.closest("[data-export-save]");
    var importButton = event.target.closest("[data-import-save]");
    var resetButton = event.target.closest("[data-reset-save]");
    var renameButton = event.target.closest("[data-rename-player]");
    var releaseNoteButton = event.target.closest("[data-dismiss-release-note]");

    if (pageButton) {
      game.state.currentPage = pageButton.dataset.pageTarget;
      render();
      return;
    }

    if (catSelectButton) {
      game.state.selectedCatId = catSelectButton.dataset.selectCat;
      render();
      return;
    }

    if (jobButton) {
      handleActionResult(game.systems.workSystem.startJob(jobButton.dataset.jobId));
      return;
    }

    if (catActionButton) {
      handleActionResult(game.systems.catSystem.performAction(game.state.selectedCatId, catActionButton.dataset.catAction));
      return;
    }

    if (shopButton) {
      handleActionResult(game.systems.shopSystem.purchase(shopButton.dataset.storeItem));
      return;
    }

    if (taskButton) {
      handleActionResult(
        game.systems.taskSystem.claimTask(taskButton.dataset.taskCategory, taskButton.dataset.taskClaim)
      );
      return;
    }

    if (exportButton) {
      game.state.saveSystem.downloadExport();
      pushNotice("当前存档已导出为 JSON 文件。");
      render();
      return;
    }

    if (importButton) {
      var importField = document.getElementById("save-import-text");
      if (!importField || !importField.value.trim()) {
        handleActionResult({ ok: false, message: "请先粘贴要导入的 JSON 存档内容。" });
        return;
      }
      try {
        importFromText(importField.value.trim());
      } catch (error) {
        handleActionResult({ ok: false, message: "导入失败，请确认 JSON 格式正确。" });
      }
      return;
    }

    if (resetButton) {
      if (!window.confirm("确定要重置当前存档吗？此操作会覆盖本地进度。")) {
        return;
      }
      game.state.game = game.state.saveSystem.resetGame();
      game.systems.homeSystem.recalculateComfort();
      game.systems.workSystem.refreshJobUnlocks();
      game.systems.taskSystem.refreshAllTasks();
      game.state.selectedCatId = "cat_001";
      pushNotice("已重置为新档。");
      render();
      return;
    }

    if (renameButton) {
      var nameInput = document.getElementById("player-name-input");
      var nextName = nameInput ? nameInput.value.trim() : "";
      game.state.game.player.name = nextName || "玩家";
      game.state.saveSystem.saveGame(game.state.game);
      pushNotice("玩家名字已更新。");
      render();
      return;
    }

    if (releaseNoteButton) {
      game.state.game.meta.lastSeenVersion = game.config.version;
      persistGame(true);
      pushNotice("已记录本次版本说明。");
      render();
    }
  }

  function handleChange(event) {
    var target = event.target;

    if (target.matches("[data-setting-key]")) {
      updateSetting(target);
      return;
    }

    if (target.id === "save-import-file" && target.files && target.files[0]) {
      var reader = new FileReader();
      reader.onload = function () {
        try {
          importFromText(String(reader.result || ""));
        } catch (error) {
          handleActionResult({ ok: false, message: "文件导入失败，请确认内容是有效的 JSON 存档。" });
        }
      };
      reader.readAsText(target.files[0], "utf-8");
    }
  }

  function init() {
    dom.header = document.getElementById("app-header");
    dom.main = document.getElementById("app-main");
    dom.quick = document.getElementById("app-quick");

    game.state.game = game.state.saveSystem.loadOrCreateGame();

    if (typeof game.state.game.tasks._dailySpendOffset !== "number") {
      game.state.game.tasks._dailySpendOffset = 0;
    }

    game.systems.homeSystem.recalculateComfort();
    game.systems.workSystem.refreshJobUnlocks();
    game.systems.taskSystem.refreshAllTasks();
    getSelectedCat();

    document.addEventListener("click", handleClick);
    document.addEventListener("change", handleChange);
    window.addEventListener("beforeunload", function () {
      game.state.saveSystem.saveGame(game.state.game);
    });
    window.addEventListener("pagehide", function () {
      game.state.saveSystem.saveGame(game.state.game);
    });

    syncRealtime("init");
    pushNotice("存档已载入，时间会按电脑当前时间同步。");
    render();
    game.state.saveSystem.saveGame(game.state.game);

    if (liveTickId) {
      window.clearInterval(liveTickId);
    }
    liveTickId = window.setInterval(function () {
      syncRealtime("timer");
    }, 1000);
  }

  window.addEventListener("DOMContentLoaded", init);
})(window.CatGame);
