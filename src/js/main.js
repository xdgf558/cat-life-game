(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;
  var dom = {};
  var liveTickId = null;

  function getSelectedCat() {
    var current = game.state.game.cats.find(function (cat) {
      return cat.id === game.state.selectedCatId;
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

  function updateShellText() {
    var brandTitle = document.querySelector(".brand-card h1");
    var brandCopy = document.querySelector(".brand-copy");
    var sidebarTitle = document.querySelector(".sidebar-tip .section-eyebrow");
    var sidebarCopy = document.querySelector(".sidebar-tip p:last-child");

    document.title = t("appTitle");
    document.documentElement.lang = game.utils.i18n.getLanguage();

    if (brandTitle) {
      brandTitle.textContent = t("brandTitle");
    }
    if (brandCopy) {
      brandCopy.textContent = t("brandCopy");
    }
    if (sidebarTitle) {
      sidebarTitle.textContent = t("sidebar_tip_title");
    }
    if (sidebarCopy) {
      sidebarCopy.textContent = t("sidebar_tip_copy");
    }

    Array.prototype.forEach.call(document.querySelectorAll(".nav-button[data-page-target]"), function (button) {
      button.textContent = t("nav_" + button.dataset.pageTarget);
    });
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
      : t("task_completed");

    Array.prototype.forEach.call(document.querySelectorAll("[data-live-clock]"), function (node) {
      node.textContent = format.formatGameTime();
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-active-work-remaining]"), function (node) {
      node.textContent = remainingText;
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-stamina-recovery]"), function (node) {
      var countdown = game.systems.timeSystem.getStaminaRecoveryCountdown();
      node.textContent = countdown === null ? t("stamina_full") : format.formatDuration(countdown);
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-cat-stat-countdown]"), function (node) {
      var cat = game.systems.catSystem.getCat(node.dataset.catId);
      var countdown = cat ? game.systems.catSystem.getStatCountdown(cat, node.dataset.catStat) : null;
      node.textContent = countdown === null ? t("stopped") : format.formatDuration(countdown);
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-cat-hunger-zero]"), function (node) {
      var cat = game.systems.catSystem.getCat(node.dataset.catId);
      var deathEta = cat ? game.systems.catSystem.getHungerDeathEta(cat) : null;
      node.textContent = deathEta === null ? t("dead_label") : format.formatDuration(deathEta);
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
    var unlockStatus;
    var disease;
    if (!selectedCat) {
      return '<section class="quick-card"><div class="empty-state">' + t("no_cat_data") + "</div></section>";
    }
    unlockStatus = game.systems.catSystem.getUnlockStatus(selectedCat);
    disease = game.systems.catSystem.getCatDisease(selectedCat);

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
      : '<div class="empty-state">' + t("notices_empty") + "</div>";

    return (
      '<section class="quick-card">' +
      '<p class="section-eyebrow">' + t("cat_overview") + "</p>" +
      '<div class="cat-portrait"><div class="cat-portrait-icon">' +
      game.systems.catSystem.getCatVisualState(selectedCat).icon +
      '</div><div>' +
      '<h3 class="panel-title">' +
      format.escapeHtml(getText(selectedCat, "name")) +
      "</h3>" +
      '<p class="page-copy">' +
      format.escapeHtml(getText(selectedCat, "breed")) +
      (!selectedCat.unlocked
        ? " · " + t("later_unlock")
        : selectedCat.isAlive === false
        ? " · " + t("dead_label")
        : " · " + t("friendship_health", { intimacy: selectedCat.intimacy, health: selectedCat.health })) +
      "</p><p class=\"helper-text\" style=\"margin-top:8px;\">" +
      (selectedCat.unlocked
        ? t("age_label") + "：" + format.escapeHtml(format.formatAgeYears(game.systems.catSystem.getCatAgeYears(selectedCat))) +
          (disease ? " · " + t("disease_label") + "：" + format.escapeHtml(getText(disease, "name")) : "")
        : t("unlock_gold_condition", { current: unlockStatus.currentGold, target: unlockStatus.requiredGold })) +
      "</p></div></div>" +
      (selectedCat.unlocked
        ? '<div style="margin-top: 14px;">' +
          game.ui.helpers.renderBar(t("hunger_label"), selectedCat.hunger) +
          game.ui.helpers.renderBar(t("clean_label"), selectedCat.clean) +
          game.ui.helpers.renderBar(t("mood_label"), selectedCat.mood) +
          "</div>"
        : "") +
      "</section>" +
      (game.systems.workSystem.hasActiveWork()
        ? '<section class="quick-card"><p class="section-eyebrow">' + t("current_work") + '</p><h3 class="panel-title">' +
          format.escapeHtml(
            getText(
              game.data.jobMap[game.systems.workSystem.getActiveWork().jobId] || game.systems.workSystem.getActiveWork(),
              "name"
            )
          ) +
          '</h3><p class="page-copy">' + t("remaining") + '：<span data-active-work-remaining>' +
          format.formatDuration(game.systems.workSystem.getRemainingMs(game.systems.workSystem.getActiveWork())) +
          "</span></p></section>"
        : "") +
      '<section class="quick-card">' +
      '<p class="section-eyebrow">' + t("quick_log") + "</p>" +
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
      hospital: game.ui.renderHospitalPanel,
      shop: game.ui.renderShopPanel,
      tasks: game.ui.renderTaskPanel,
      settings: game.ui.renderSettingsPanel,
    };
    var renderer = pageRenderers[game.state.currentPage] || game.ui.renderHome;

    dom.header.innerHTML = game.ui.renderHeader(game.state.game);
    dom.main.innerHTML = renderer(game.state.game);
    dom.quick.innerHTML = renderQuickPanel();
    updateShellText();

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
    pushNotice(t("settings_updated"));
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
    pushNotice(t("import_success"));
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
    var readoptButton = event.target.closest("[data-readopt-cat]");
    var treatButton = event.target.closest("[data-treat-cat]");

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

    if (readoptButton) {
      handleActionResult(game.systems.catSystem.readoptCat(readoptButton.dataset.readoptCat));
      return;
    }

    if (treatButton) {
      handleActionResult(game.systems.hospitalSystem.treatCat(treatButton.dataset.treatCat));
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
      pushNotice(t("export_success"));
      render();
      return;
    }

    if (importButton) {
      var importField = document.getElementById("save-import-text");
      if (!importField || !importField.value.trim()) {
        handleActionResult({ ok: false, message: t("import_need_text") });
        return;
      }
      try {
        importFromText(importField.value.trim());
      } catch (error) {
        handleActionResult({ ok: false, message: t("import_invalid") });
      }
      return;
    }

    if (resetButton) {
      if (!window.confirm(t("reset_confirm"))) {
        return;
      }
      game.state.game = game.state.saveSystem.resetGame();
      game.systems.homeSystem.recalculateComfort();
      game.systems.workSystem.refreshJobUnlocks();
      game.systems.taskSystem.refreshAllTasks();
      game.state.selectedCatId = "cat_001";
      pushNotice(t("reset_success"));
      render();
      return;
    }

    if (renameButton) {
      var nameInput = document.getElementById("player-name-input");
      var nextName = nameInput ? nameInput.value.trim() : "";
      game.state.game.player.name = nextName || "玩家";
      game.state.saveSystem.saveGame(game.state.game);
      pushNotice(t("rename_success"));
      render();
      return;
    }

    if (releaseNoteButton) {
      game.state.game.meta.lastSeenVersion = game.config.version;
      persistGame(true);
      pushNotice(t("release_noted"));
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
          handleActionResult({ ok: false, message: t("import_file_invalid") });
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
    window.addEventListener("focus", function () {
      syncRealtime("focus");
    });
    document.addEventListener("visibilitychange", function () {
      if (!document.hidden) {
        syncRealtime("visibility");
      }
    });
    window.addEventListener("beforeunload", function () {
      game.state.saveSystem.saveGame(game.state.game);
    });
    window.addEventListener("pagehide", function () {
      game.state.saveSystem.saveGame(game.state.game);
    });

    syncRealtime("init");
    pushNotice(t("storage_loaded"));
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
