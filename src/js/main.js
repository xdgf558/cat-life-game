(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;
  var dom = {};
  var liveTickId = null;
  var arcadeSpinTimerId = null;

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

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
    var brandTitle = document.querySelector(".shell-brand h1");
    var brandCopy = document.querySelector(".shell-brand .brand-copy");
    var sidebarTitle = document.querySelector(".shell-note .section-eyebrow");
    var sidebarCopy = document.querySelector(".shell-note p:last-child");

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

  function scheduleLotteryResolve(source) {
    if (!game.systems.lotterySystem) {
      return;
    }

    game.systems.lotterySystem.resolvePendingDraws(source).then(function (result) {
      if (!result) {
        return;
      }

      if (result.messages && result.messages.length) {
        result.messages.forEach(pushNotice);
      }

      if (result.changed) {
        persistGame(true);
        render();
      } else if (game.state.currentPage === "arcade") {
        render();
      }
    });
  }

  function refreshLiveBindings() {
    var activeWork = game.systems.workSystem.getActiveWork();
    var displayStats = game.systems.playerSystem.getDisplayStats();
    var activeSleep = game.systems.playerSystem.getActiveSleep();
    var sleepRecovery = game.systems.playerSystem.getSleepRecovery();
    var hungerCountdown = game.systems.playerSystem.getHungerCountdown();
    var hungerEta = game.systems.playerSystem.getHungerBlockEta();
    var moodStatus = game.systems.playerSystem.getMoodStatus(displayStats.mood);
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

    Array.prototype.forEach.call(document.querySelectorAll("[data-player-stamina-live]"), function (node) {
      node.textContent = Math.round(displayStats.stamina);
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-player-mood-live]"), function (node) {
      node.textContent = Math.round(displayStats.mood);
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-player-hunger-live]"), function (node) {
      node.textContent = Math.round(game.systems.playerSystem.getCurrentHunger());
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-player-mood-status]"), function (node) {
      node.textContent = t(moodStatus.key);
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-player-hunger-countdown]"), function (node) {
      node.textContent = hungerCountdown === null ? t("stopped") : format.formatDuration(hungerCountdown);
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-player-hunger-eta]"), function (node) {
      node.textContent = hungerEta === null ? t("work_hunger_blocked") : format.formatDuration(hungerEta);
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-player-sleep-duration]"), function (node) {
      node.textContent = activeSleep ? format.formatDuration(sleepRecovery.elapsedMs) : t("sleep_not_active");
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-player-sleep-stamina]"), function (node) {
      node.textContent = activeSleep ? sleepRecovery.staminaGain : "0";
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-player-sleep-mood]"), function (node) {
      node.textContent = activeSleep ? sleepRecovery.moodGain : "0";
    });

    Array.prototype.forEach.call(document.querySelectorAll("[data-lottery-next-draw-countdown]"), function (node) {
      node.textContent = game.systems.lotterySystem
        ? format.formatDuration(game.systems.lotterySystem.getNextDrawInfo().countdownMs)
        : t("stopped");
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
    } else {
      refreshLiveBindings();
    }

    if (result.lotteryNeedsResolve || source === "init" || source === "focus" || source === "visibility") {
      scheduleLotteryResolve(source);
    }
  }

  function renderQuickPanel() {
    var selectedCat = getSelectedCat();
    var unlockStatus;
    var disease;
    var bank = game.systems.bankSystem ? game.systems.bankSystem.getBank() : null;
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
      '<div class="cat-portrait"><img class="cat-illustration-small" src="' +
      game.utils.catArt.buildCatSvg(selectedCat, 88) +
      '" alt="' +
      format.escapeHtml(getText(selectedCat, "name")) +
      '" /><div>' +
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
      (bank
        ? '<section class="quick-card"><p class="section-eyebrow">' + t("nav_bank") + '</p><h3 class="panel-title">' +
          t(game.systems.bankSystem.getLoanStatusKey()) +
          '</h3><p class="page-copy">' + t("bank_balance") + "：" + format.formatNumber(bank.balance) +
          " " + t("gold_unit") + '</p><p class="helper-text" style="margin-top:8px;">' +
          t("bank_total_debt") + "：" + format.formatNumber(bank.totalDebt) + " " + t("gold_unit") +
          "</p></section>"
        : "") +
      '<section class="quick-card">' +
      '<p class="section-eyebrow">' + t("quick_log") + "</p>" +
      '<div class="notice-list">' +
      notices +
      "</div></section>"
    );
  }

  function buildArcadeSpinColumns() {
    var symbolIcons = game.systems.arcadeSystem.symbols.map(function (symbol) {
      return symbol.icon;
    });

    return [0, 1, 2].map(function () {
      var column = [];
      var i;
      for (i = 0; i < 12; i += 1) {
        column.push(symbolIcons[Math.floor(Math.random() * symbolIcons.length)]);
      }
      return column;
    });
  }

  function startArcadeSpin(betValue) {
    var validation = game.systems.arcadeSystem.validateSpin(betValue);

    if (!validation.ok) {
      handleActionResult(validation);
      return;
    }

    if (game.state.arcadeSpin) {
      return;
    }

    game.state.arcadeSpin = {
      bet: Number(betValue),
      columns: buildArcadeSpinColumns(),
    };
    render();

    if (arcadeSpinTimerId) {
      window.clearTimeout(arcadeSpinTimerId);
    }

    arcadeSpinTimerId = window.setTimeout(function () {
      var result = game.systems.arcadeSystem.spinSlot(betValue);
      game.state.arcadeSpin = null;
      arcadeSpinTimerId = null;
      handleActionResult(result);
    }, 1300);
  }

  function render() {
    var pageRenderers = {
      home: game.ui.renderHome,
      room: game.ui.renderRoomPanel,
      work: game.ui.renderWorkPanel,
      bank: game.ui.renderBankPanel,
      cats: game.ui.renderCatPanel,
      collection: game.ui.renderCollectionPanel,
      arcade: game.ui.renderArcadePanel,
      hospital: game.ui.renderHospitalPanel,
      shop: game.ui.renderShopPanel,
      tasks: game.ui.renderTaskPanel,
      version: game.ui.renderVersionPanel,
      save: game.ui.renderSavePanel,
      settings: game.ui.renderSettingsPanel,
    };
    var renderer = pageRenderers[game.state.currentPage] || game.ui.renderHome;

    dom.header.innerHTML = game.ui.renderHeader(game.state.game);
    dom.main.innerHTML = renderer(game.state.game);
    dom.quick.innerHTML = renderQuickPanel();
    updateShellText();
    if (game.systems.musicSystem) {
      game.systems.musicSystem.syncForState(game.state.currentPage);
    }

    Array.prototype.forEach.call(document.querySelectorAll(".nav-button[data-page-target]"), function (button) {
      button.classList.toggle("is-active", button.dataset.pageTarget === game.state.currentPage);
    });
  }

  function updateSetting(target) {
    var key = target.dataset.settingKey;
    if (!key) {
      return;
    }

    if (key === "customMusicEnabled" && !game.state.game.settings.customMusicData) {
      target.checked = false;
      pushNotice(t("custom_music_missing"));
      render();
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
    if (game.systems.musicSystem) {
      game.systems.musicSystem.applyVolume();
      game.systems.musicSystem.syncForState(game.state.currentPage);
    }
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
    var manualSaveButton = event.target.closest("[data-manual-save]");
    var resetButton = event.target.closest("[data-reset-save]");
    var renameButton = event.target.closest("[data-rename-player]");
    var renameCatButton = event.target.closest("[data-rename-cat]");
    var releaseNoteButton = event.target.closest("[data-dismiss-release-note]");
    var readoptButton = event.target.closest("[data-readopt-cat]");
    var treatButton = event.target.closest("[data-treat-cat]");
    var sleepButton = event.target.closest("[data-player-sleep]");
    var usePlayerItemButton = event.target.closest("[data-use-player-item]");
    var bankActionButton = event.target.closest("[data-bank-action]");
    var lotteryActionButton = event.target.closest("[data-lottery-action]");
    var slotButton = event.target.closest("[data-slot-bet]");
    var breedButton = event.target.closest("[data-breed-cats]");
    var inspectCollectionButton = event.target.closest("[data-inspect-collection-cat]");
    var resetRoomLayoutButton = event.target.closest("[data-reset-room-layout]");
    var upgradeRoomButton = event.target.closest("[data-upgrade-room]");
    var clearCustomMusicButton = event.target.closest("[data-clear-custom-music]");

    if (game.systems.musicSystem) {
      game.systems.musicSystem.unlock();
    }

    if (pageButton) {
      game.state.currentPage = pageButton.dataset.pageTarget;
      render();
      if (pageButton.dataset.pageTarget === "arcade") {
        scheduleLotteryResolve("arcade-page");
      }
      return;
    }

    if (catSelectButton) {
      game.state.selectedCatId = catSelectButton.dataset.selectCat;
      render();
      return;
    }

    if (inspectCollectionButton) {
      game.state.collectionInspectCatId = inspectCollectionButton.dataset.inspectCollectionCat;
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

    if (sleepButton) {
      handleActionResult(game.systems.playerSystem.sleep());
      return;
    }

    if (usePlayerItemButton) {
      handleActionResult(game.systems.playerSystem.consumeItem(usePlayerItemButton.dataset.usePlayerItem));
      return;
    }

    if (bankActionButton) {
      var inputId = bankActionButton.dataset.bankInput;
      var amountInput = inputId ? document.getElementById(inputId) : null;
      var presetAmount = bankActionButton.dataset.bankAmount;
      var rawValue = presetAmount !== undefined && presetAmount !== ""
        ? presetAmount
        : amountInput
        ? amountInput.value
        : "";
      var actionKey = bankActionButton.dataset.bankAction;
      var result = null;

      if (actionKey === "deposit") {
        result = game.systems.bankSystem.deposit(rawValue);
      } else if (actionKey === "withdraw") {
        result = game.systems.bankSystem.withdraw(rawValue);
      } else if (actionKey === "loan") {
        result = game.systems.bankSystem.takeLoan(rawValue);
      } else if (actionKey === "repay") {
        result = game.systems.bankSystem.repay(rawValue);
      } else if (actionKey === "repay-full") {
        result = game.systems.bankSystem.payOffLoan();
      }

      if (amountInput && presetAmount !== undefined && presetAmount !== "") {
        amountInput.value = presetAmount;
      }

      handleActionResult(result);
      return;
    }

    if (lotteryActionButton) {
      var lotteryAction = lotteryActionButton.dataset.lotteryAction;

      if (lotteryAction === "randomize") {
        game.systems.lotterySystem.randomizeDraft();
        render();
        return;
      }
      if (lotteryAction === "buy-current") {
        handleActionResult(game.systems.lotterySystem.purchaseTicket(game.systems.lotterySystem.getDraftNumber()));
        return;
      }
      if (lotteryAction === "buy-random") {
        handleActionResult(
          game.systems.lotterySystem.purchaseRandomTickets(
            Number(lotteryActionButton.dataset.lotteryCount || 1)
          )
        );
        return;
      }
      if (lotteryAction === "retry") {
        scheduleLotteryResolve("lottery-retry");
        return;
      }
    }

    if (slotButton) {
      startArcadeSpin(slotButton.dataset.slotBet);
      return;
    }

    if (breedButton) {
      handleActionResult(
        game.systems.collectionSystem.breedCats(
          document.getElementById("breed-parent-a") ? document.getElementById("breed-parent-a").value : "",
          document.getElementById("breed-parent-b") ? document.getElementById("breed-parent-b").value : ""
        )
      );
      return;
    }

    if (resetRoomLayoutButton) {
      game.systems.homeSystem.resetFurnitureLayout();
      pushNotice(t("room_layout_reset_done"));
      persistGame(true);
      render();
      return;
    }

    if (upgradeRoomButton) {
      handleActionResult(game.systems.homeSystem.upgradeRoom());
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

    if (manualSaveButton) {
      game.state.saveSystem.saveGame(game.state.game);
      pushNotice(t("manual_save_done"));
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

    if (renameCatButton) {
      var catNameInput = document.getElementById("cat-name-input");
      handleActionResult(
        game.systems.catSystem.renameCat(
          renameCatButton.dataset.renameCat,
          catNameInput ? catNameInput.value : ""
        )
      );
      return;
    }

    if (clearCustomMusicButton) {
      game.systems.musicSystem.clearCustomMusic();
      game.state.saveSystem.saveGame(game.state.game);
      pushNotice(t("custom_music_cleared"));
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

    if (target.matches("[data-room-setting]")) {
      game.state.game.home.roomScene[target.dataset.roomSetting] = target.value;
      if (target.dataset.roomSetting === "layout") {
        game.systems.homeSystem.resetFurnitureLayout();
      }
      game.state.saveSystem.saveGame(game.state.game);
      render();
      return;
    }

    if (target.matches("[data-lottery-digit-index]")) {
      game.systems.lotterySystem.setDraftDigit(target.dataset.lotteryDigitIndex, target.value);
      render();
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
      return;
    }

    if (target.id === "custom-music-file" && target.files && target.files[0]) {
      var musicFile = target.files[0];
      var musicReader;
      var maxBytes = game.config.customMusicMaxBytes || (2 * 1024 * 1024);

      if (musicFile.size > maxBytes) {
        pushNotice(t("custom_music_size_error", { size: (maxBytes / (1024 * 1024)).toFixed(0) }));
        target.value = "";
        render();
        return;
      }

      musicReader = new FileReader();
      musicReader.onload = function () {
        try {
          game.state.game.settings.customMusicData = String(musicReader.result || "");
          game.state.game.settings.customMusicName = musicFile.name;
          game.state.game.settings.customMusicEnabled = true;
          game.state.saveSystem.saveGame(game.state.game);
          pushNotice(t("custom_music_imported", { name: musicFile.name }));
          if (game.systems.musicSystem) {
            game.systems.musicSystem.syncForState(game.state.currentPage);
          }
          render();
        } catch (error) {
          pushNotice(t("custom_music_size_error", { size: (maxBytes / (1024 * 1024)).toFixed(0) }));
        }
      };
      musicReader.readAsDataURL(musicFile);
      target.value = "";
    }
  }

  function updateDraggedFurniture(clientX, clientY) {
    var drag = game.state.roomDrag;
    var xPercent;
    var yPercent;

    if (!drag || !drag.sceneRect) {
      return;
    }

    xPercent = clamp(((clientX - drag.sceneRect.left) / drag.sceneRect.width) * 100, 8, 92);
    yPercent = clamp(((clientY - drag.sceneRect.top) / drag.sceneRect.height) * 100, 34, 82);

    game.systems.homeSystem.setFurniturePosition(drag.furnitureId, xPercent.toFixed(2) + "%", yPercent.toFixed(2) + "%");

    if (drag.element) {
      drag.element.style.left = xPercent.toFixed(2) + "%";
      drag.element.style.top = yPercent.toFixed(2) + "%";
    }
  }

  function handlePointerDown(event) {
    var furniture = event.target.closest(".room-furniture[data-furniture-id]");
    var scene;

    if (!furniture || game.state.currentPage !== "room") {
      return;
    }

    scene = furniture.closest(".room-scene");
    if (!scene) {
      return;
    }

    game.state.roomDrag = {
      furnitureId: furniture.dataset.furnitureId,
      element: furniture,
      sceneRect: scene.getBoundingClientRect(),
      pointerId: event.pointerId,
    };

    furniture.classList.add("is-dragging");
    if (furniture.setPointerCapture) {
      furniture.setPointerCapture(event.pointerId);
    }
    updateDraggedFurniture(event.clientX, event.clientY);
    event.preventDefault();
  }

  function handlePointerMove(event) {
    if (!game.state.roomDrag || game.state.roomDrag.pointerId !== event.pointerId) {
      return;
    }

    updateDraggedFurniture(event.clientX, event.clientY);
    event.preventDefault();
  }

  function finishRoomDrag(event) {
    var drag = game.state.roomDrag;

    if (!drag || (event && drag.pointerId !== event.pointerId)) {
      return;
    }

    if (drag.element) {
      drag.element.classList.remove("is-dragging");
      if (event && drag.element.releasePointerCapture) {
        try {
          drag.element.releasePointerCapture(event.pointerId);
        } catch (error) {
        }
      }
    }

    game.state.roomDrag = null;
    persistGame(true);
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
    if (game.systems.musicSystem) {
      game.systems.musicSystem.init();
    }
    getSelectedCat();

    document.addEventListener("click", handleClick);
    document.addEventListener("change", handleChange);
    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("pointermove", handlePointerMove);
    document.addEventListener("pointerup", finishRoomDrag);
    document.addEventListener("pointercancel", finishRoomDrag);
    window.addEventListener("focus", function () {
      syncRealtime("focus");
      if (game.systems.musicSystem) {
        game.systems.musicSystem.syncForState(game.state.currentPage);
      }
    });
    document.addEventListener("visibilitychange", function () {
      if (!document.hidden) {
        syncRealtime("visibility");
        if (game.systems.musicSystem) {
          game.systems.musicSystem.syncForState(game.state.currentPage);
        }
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
    scheduleLotteryResolve("init");
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
