(function (game) {
  var t = game.utils.i18n.t;
  var STAMINA_INTERVAL = game.config.staminaRecoveryIntervalMs;
  var STAMINA_PER_INTERVAL = game.config.staminaRecoveryAmount;

  function getNow() {
    return new Date();
  }

  function getTodayKey() {
    return game.utils.format.formatDateKey(getNow());
  }

  function syncPlayerRecovery(now, source) {
    var player = game.state.game.player;
    var lastTime;
    var elapsed;
    var steps;
    var gained;

    if (!player.staminaUpdatedAt) {
      player.staminaUpdatedAt = now.toISOString();
      return {
        changed: false,
        messages: [],
      };
    }

    if (player.stamina >= 100) {
      player.stamina = 100;
      player.staminaUpdatedAt = now.toISOString();
      return {
        changed: false,
        messages: [],
      };
    }

    lastTime = new Date(player.staminaUpdatedAt).getTime();
    elapsed = now.getTime() - lastTime;
    steps = Math.floor(elapsed / STAMINA_INTERVAL);

    if (steps <= 0) {
      return {
        changed: false,
        messages: [],
      };
    }

    gained = Math.min(100 - player.stamina, steps * STAMINA_PER_INTERVAL);
    player.stamina = Math.min(100, player.stamina + gained);
    player.staminaUpdatedAt = player.stamina >= 100
      ? now.toISOString()
      : new Date(lastTime + steps * STAMINA_INTERVAL).toISOString();

    return {
      changed: gained > 0,
      messages: gained > 0 && source !== "timer" ? [t("stamina_recovered", { points: gained })] : [],
    };
  }

  function getStaminaRecoveryCountdown(nowDate) {
    var player = game.state.game.player;
    var now = nowDate || getNow();
    var elapsed;

    if (!player.staminaUpdatedAt || player.stamina >= 100) {
      return null;
    }

    elapsed = Math.max(0, now.getTime() - new Date(player.staminaUpdatedAt).getTime());
    return STAMINA_INTERVAL - (elapsed % STAMINA_INTERVAL || 0);
  }

  function syncRealtimeState(source) {
    var state = game.state.game;
    var now = getNow();
    var todayKey = game.utils.format.formatDateKey(now);
    var messages = [];
    var changed = false;

    if (game.systems.taskSystem && state.tasks.lastResetDate !== todayKey) {
      game.systems.taskSystem.resetDailyTasks(todayKey);
      changed = true;
      if (source !== "init") {
        messages.push(t("daily_reset_notice"));
      }
    }

    var recoveryResult = syncPlayerRecovery(now, source);
    if (recoveryResult.changed) {
      changed = true;
      messages = messages.concat(recoveryResult.messages || []);
    }

    if (game.systems.workSystem) {
      var workSyncResult = game.systems.workSystem.syncActiveWork(now, source);
      if (workSyncResult.changed) {
        changed = true;
        messages = messages.concat(workSyncResult.messages || []);
      }
    }

    if (game.systems.catSystem) {
      var catSyncResult = game.systems.catSystem.syncCatState(now, source);
      if (catSyncResult.changed) {
        changed = true;
        messages = messages.concat(catSyncResult.messages || []);
      }
    }

    if (game.systems.collectionSystem) {
      var pregnancySyncResult = game.systems.collectionSystem.syncPregnancies(now, source);
      if (pregnancySyncResult.changed) {
        changed = true;
        messages = messages.concat(pregnancySyncResult.messages || []);
      }
    }

    state.meta.lastSyncAt = now.toISOString();

    return {
      changed: changed,
      messages: messages,
    };
  }

  game.systems.timeSystem = {
    getNow: getNow,
    getTodayKey: getTodayKey,
    getStaminaRecoveryCountdown: getStaminaRecoveryCountdown,
    syncRealtimeState: syncRealtimeState,
  };
})(window.CatGame);
