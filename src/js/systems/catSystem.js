(function (game) {
  var clamp = game.utils.format.clamp;
  var decayRules = game.config.catDecayRules;

  function getNowIso() {
    return game.systems.timeSystem.getNow().toISOString();
  }

  function ensureCatRuntimeFields(cat, fallbackIso) {
    var seedTime = fallbackIso || getNowIso();

    if (typeof cat.isAlive !== "boolean") {
      cat.isAlive = true;
    }
    if (!cat.diedAt) {
      cat.diedAt = null;
    }
    if (!cat.deathReason) {
      cat.deathReason = null;
    }
    if (!cat.decayTracker) {
      cat.decayTracker = {};
    }

    Object.keys(decayRules).forEach(function (key) {
      if (!cat.decayTracker[key]) {
        cat.decayTracker[key] = seedTime;
      }
    });
  }

  function resetDecayTracker(cat, statKeys, isoTime) {
    var timestamp = isoTime || getNowIso();
    ensureCatRuntimeFields(cat, timestamp);
    statKeys.forEach(function (key) {
      cat.decayTracker[key] = timestamp;
    });
  }

  function markCatDead(cat, nowIso, source, messages) {
    if (!cat.isAlive) {
      return;
    }

    cat.isAlive = false;
    cat.hunger = 0;
    cat.diedAt = nowIso;
    cat.deathReason = "hunger_zero";
    cat.mood = 0;
    cat.energy = 0;

    messages.push(
      (source === "init" ? "离线期间，" : "") +
        cat.name +
        "的饱腹感归零，已经死亡。"
    );
  }

  function applyDecaySteps(cat, statKey, nowDate, source, messages) {
    var rule = decayRules[statKey];
    var trackerTime = new Date(cat.decayTracker[statKey]).getTime();
    var nowTime = nowDate.getTime();
    var elapsed = nowTime - trackerTime;
    var steps = Math.floor(elapsed / rule.intervalMs);
    var nextTrackerTime = trackerTime;

    if (steps <= 0 || !cat.isAlive) {
      return false;
    }

    cat[statKey] = clamp((cat[statKey] || 0) - steps, 0, 100);
    nextTrackerTime += steps * rule.intervalMs;
    cat.decayTracker[statKey] = new Date(nextTrackerTime).toISOString();

    if (statKey === "hunger" && cat.hunger <= 0) {
      markCatDead(cat, nowDate.toISOString(), source, messages);
    }

    return true;
  }

  function syncCatDecay(nowDate, source) {
    var fallbackIso = nowDate.toISOString();
    var messages = [];
    var changed = false;

    game.state.game.cats.forEach(function (cat) {
      if (!cat.unlocked) {
        return;
      }

      ensureCatRuntimeFields(cat, fallbackIso);

      if (!cat.isAlive) {
        return;
      }

      Object.keys(decayRules).forEach(function (statKey) {
        var didChange = applyDecaySteps(cat, statKey, nowDate, source, messages);
        changed = changed || didChange;
      });
    });

    return {
      changed: changed,
      messages: messages,
    };
  }

  function getStatCountdown(cat, statKey, nowDate) {
    var rule = decayRules[statKey];
    var now = nowDate || game.systems.timeSystem.getNow();
    var trackerTime;
    var elapsed;

    if (!rule) {
      return 0;
    }

    ensureCatRuntimeFields(cat, now.toISOString());

    if (!cat.isAlive) {
      return null;
    }

    trackerTime = new Date(cat.decayTracker[statKey]).getTime();
    elapsed = Math.max(0, now.getTime() - trackerTime);

    return rule.intervalMs - (elapsed % rule.intervalMs || 0);
  }

  function getHungerDeathEta(cat, nowDate) {
    var countdown = getStatCountdown(cat, "hunger", nowDate);

    if (!cat || !cat.isAlive || cat.hunger <= 0 || countdown === null) {
      return null;
    }

    return countdown + Math.max(0, cat.hunger - 1) * decayRules.hunger.intervalMs;
  }

  function getCat(catId) {
    return game.state.game.cats.find(function (cat) {
      return cat.id === catId;
    });
  }

  function performAction(catId, actionKey) {
    var state = game.state.game;
    var cat = getCat(catId);
    var messages = [];
    var comfortBonus = Math.floor(state.home.comfortScore / 20);
    var nowIso = getNowIso();

    if (!cat || !cat.unlocked) {
      return { ok: false, message: "这只猫咪还没有解锁。" };
    }
    ensureCatRuntimeFields(cat, nowIso);
    if (!cat.isAlive) {
      return { ok: false, message: cat.name + "已经死亡，无法继续互动。" };
    }

    if (actionKey === "feedBasic") {
      if (state.inventory.food <= 0) {
        return { ok: false, message: "普通猫粮不够了，去商店补货吧。" };
      }
      state.inventory.food -= 1;
      cat.hunger = clamp(cat.hunger + 25, 0, 100);
      cat.mood = clamp(cat.mood + 4, 0, 100);
      resetDecayTracker(cat, ["hunger", "mood"], nowIso);
      state.player.feedTimes += 1;
      state.player.feedTimesToday += 1;
      messages.push(cat.name + "吃得很认真，饱腹值明显回升。");
    } else if (actionKey === "feedPremium") {
      if (state.inventory.premiumFood <= 0) {
        return { ok: false, message: "高级猫粮用完了。" };
      }
      state.inventory.premiumFood -= 1;
      cat.hunger = clamp(cat.hunger + 45, 0, 100);
      cat.intimacy = clamp(cat.intimacy + 2, 0, 100);
      cat.mood = clamp(cat.mood + 6, 0, 100);
      resetDecayTracker(cat, ["hunger", "mood"], nowIso);
      state.player.feedTimes += 1;
      state.player.feedTimesToday += 1;
      messages.push(cat.name + "吃到了高级猫粮，开心得蹭了蹭你。");
    } else if (actionKey === "clean") {
      if (state.inventory.litter <= 0) {
        return { ok: false, message: "猫砂不够了，先去商店买一些。" };
      }
      state.inventory.litter -= 1;
      cat.clean = clamp(cat.clean + 30, 0, 100);
      cat.health = clamp(cat.health + 4, 0, 100);
      resetDecayTracker(cat, ["clean", "health"], nowIso);
      state.player.cleanTimes += 1;
      messages.push("你帮" + cat.name + "整理了环境，清洁值提升了。");
    } else if (actionKey === "play") {
      cat.mood = clamp(cat.mood + 18 + comfortBonus, 0, 100);
      cat.intimacy = clamp(cat.intimacy + 8 + Math.min(4, state.inventory.toys * 2), 0, 100);
      cat.energy = clamp(cat.energy - 10, 0, 100);
      resetDecayTracker(cat, ["mood", "energy"], nowIso);
      state.player.playTimes += 1;
      state.player.playTimesToday += 1;
      state.player.mood = clamp(state.player.mood + 4, 0, 100);
      messages.push("你陪" + cat.name + "玩了好一会儿，气氛变得轻松很多。");
      if (state.inventory.toys > 0) {
        messages.push("家里的逗猫棒让这次陪玩更有效率。");
      }
    } else if (actionKey === "rest") {
      cat.energy = clamp(cat.energy + 20 + comfortBonus, 0, 100);
      cat.health = clamp(cat.health + 5, 0, 100);
      cat.mood = clamp(cat.mood + 3, 0, 100);
      resetDecayTracker(cat, ["energy", "health", "mood"], nowIso);
      messages.push(cat.name + "在猫窝里舒舒服服地休息了一会儿。");
    } else {
      return { ok: false, message: "未知的猫咪互动。" };
    }

    if (game.systems.taskSystem) {
      game.systems.taskSystem.refreshAllTasks();
    }

    return {
      ok: true,
      messages: messages,
    };
  }

  game.systems.catSystem = {
    getCat: getCat,
    performAction: performAction,
    syncCatDecay: syncCatDecay,
    getStatCountdown: getStatCountdown,
    getHungerDeathEta: getHungerDeathEta,
    ensureCatRuntimeFields: ensureCatRuntimeFields,
  };
})(window.CatGame);
