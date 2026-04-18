(function (game) {
  var clamp = game.utils.format.clamp;

  function getJob(jobId) {
    return game.state.game.jobs.find(function (job) {
      return job.id === jobId;
    });
  }

  function refreshJobUnlocks() {
    game.state.game.jobs.forEach(function (job) {
      job.unlocked = game.state.game.player.level >= job.unlockLevel;
    });
  }

  function grantInventoryItem(itemId, amount) {
    var item = game.data.itemMap[itemId];
    var count = amount || 1;

    if (!item) {
      return;
    }

    if (item.type === "furniture") {
      if (game.state.game.inventory.furnitureOwned.indexOf(item.id) === -1) {
        game.state.game.inventory.furnitureOwned.push(item.id);
      }
      if (game.state.game.home.placedFurniture.indexOf(item.id) === -1) {
        game.state.game.home.placedFurniture.push(item.id);
      }
      if (game.systems.homeSystem) {
        game.systems.homeSystem.recalculateComfort();
      }
      return;
    }

    var field = item.inventoryField;
    game.state.game.inventory[field] += count;
  }

  function addExp(amount) {
    var player = game.state.game.player;
    var gained = Math.max(0, amount || 0);
    var messages = [];

    player.exp += gained;

    while (player.exp >= player.level * 100) {
      player.exp -= player.level * 100;
      player.level += 1;
      player.stamina = clamp(player.stamina + 20, 0, 100);
      messages.push("玩家升级到 Lv." + player.level + "，体力恢复了一些。");
    }

    refreshJobUnlocks();
    return messages;
  }

  function getActiveWork() {
    return game.state.game.player.activeWork;
  }

  function hasActiveWork() {
    return Boolean(getActiveWork());
  }

  function getRemainingMs(activeWork, nowDate) {
    if (!activeWork) {
      return 0;
    }
    return Math.max(0, new Date(activeWork.endsAt).getTime() - new Date(nowDate || Date.now()).getTime());
  }

  function startJob(jobId) {
    var state = game.state.game;
    var job = getJob(jobId);
    var event;
    var income;
    var now;
    var endAt;
    var messages = [];

    if (!job) {
      return { ok: false, message: "没有找到这个工作。" };
    }
    if (state.player.activeWork) {
      return { ok: false, message: "已经有一份工作在进行中了，先等它结束吧。" };
    }
    if (!job.unlocked) {
      return { ok: false, message: "玩家等级还不够，暂时无法接这份工作。" };
    }
    if (state.player.stamina < job.staminaCost) {
      return { ok: false, message: "体力不足，先去陪猫或等到第二天恢复吧。" };
    }

    event = game.utils.random.pick(job.eventPool) || { text: "今天平稳收工。", goldDelta: 0 };
    income = Math.max(0, job.goldReward + (event.goldDelta || 0));
    now = game.systems.timeSystem.getNow();
    endAt = new Date(now.getTime() + job.durationMinutes * 60 * 1000);

    state.player.stamina = clamp(state.player.stamina - job.staminaCost, 0, 100);
    state.player.activeWork = {
      jobId: job.id,
      jobName: job.name,
      startedAt: now.toISOString(),
      endsAt: endAt.toISOString(),
      durationMinutes: job.durationMinutes,
      rewardGold: income,
      expReward: job.expReward,
      eventText: event.text,
      itemReward: event.itemReward || null,
      itemAmount: event.itemAmount || 0,
      staminaCost: job.staminaCost,
    };

    messages.push(
      "已开始「" +
        job.name +
        "」，现实时间约 " +
        job.durationMinutes +
        " 分钟后结算，期间退出页面也会继续计时。"
    );
    messages.push("已先扣除 " + job.staminaCost + " 点体力。");

    return {
      ok: true,
      messages: messages,
      forceSave: true,
    };
  }

  function completeStoredWork(activeWork, source) {
    var state = game.state.game;
    var job = getJob(activeWork.jobId);
    var messages = [];

    state.player.gold += activeWork.rewardGold;
    state.player.totalIncome += activeWork.rewardGold;
    state.player.workTimes += 1;
    state.player.workTimesToday += 1;
    state.player.mood = clamp(
      state.player.mood - 3 + Math.max(0, Math.round(activeWork.rewardGold / 100)),
      0,
      100
    );

    if (job) {
      job.workCount += 1;
    }

    if (activeWork.itemReward) {
      grantInventoryItem(activeWork.itemReward, activeWork.itemAmount || 1);
    }

    messages = messages.concat(addExp(activeWork.expReward));

    if (game.systems.taskSystem) {
      game.systems.taskSystem.refreshAllTasks();
    }

    messages.unshift(
      (source === "init" ? "离线期间的打工已完成：" : "打工完成：") +
        "「" +
        activeWork.jobName +
        "」获得 " +
        activeWork.rewardGold +
        " 金币。"
    );
    messages.push(activeWork.eventText);

    if (activeWork.itemReward) {
      messages.push(
        "额外获得：" + game.data.itemMap[activeWork.itemReward].name + " x" + (activeWork.itemAmount || 1) + "。"
      );
    }

    state.player.activeWork = null;

    return messages;
  }

  function syncActiveWork(nowDate, source) {
    var activeWork = getActiveWork();

    if (!activeWork) {
      return { changed: false, messages: [] };
    }

    if (getRemainingMs(activeWork, nowDate) > 0) {
      return { changed: false, messages: [] };
    }

    return {
      changed: true,
      messages: completeStoredWork(activeWork, source),
      forceSave: true,
    };
  }

  game.systems.workSystem = {
    refreshJobUnlocks: refreshJobUnlocks,
    startJob: startJob,
    addExp: addExp,
    grantInventoryItem: grantInventoryItem,
    getActiveWork: getActiveWork,
    hasActiveWork: hasActiveWork,
    getRemainingMs: getRemainingMs,
    syncActiveWork: syncActiveWork,
  };
})(window.CatGame);
