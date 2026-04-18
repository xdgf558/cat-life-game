(function (game) {
  function getNow() {
    return new Date();
  }

  function getTodayKey() {
    return game.utils.format.formatDateKey(getNow());
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
        messages.push("已按电脑日期刷新今日任务。");
      }
    }

    if (game.systems.workSystem) {
      var workSyncResult = game.systems.workSystem.syncActiveWork(now, source);
      if (workSyncResult.changed) {
        changed = true;
        messages = messages.concat(workSyncResult.messages || []);
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
    syncRealtimeState: syncRealtimeState,
  };
})(window.CatGame);
