(function (game) {
  var clamp = game.utils.format.clamp;
  var decayRules = game.config.catDecayRules;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;

  function getNowIso() {
    return game.systems.timeSystem.getNow().toISOString();
  }

  function getBaseCat(catId) {
    return game.data.cats.find(function (cat) {
      return cat.id === catId;
    });
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
    if (typeof cat.adoptionCount !== "number") {
      cat.adoptionCount = 0;
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
      source === "init"
        ? game.utils.i18n.getLanguage() === "en"
          ? getText(cat, "name") + "'s hunger reached zero while you were away, and the cat died."
          : "离线期间，" + getText(cat, "name") + "的饱腹感归零，已经死亡。"
        : game.utils.i18n.getLanguage() === "en"
          ? getText(cat, "name") + "'s hunger reached zero and the cat died."
          : getText(cat, "name") + "的饱腹感归零，已经死亡。"
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

  function getCatVisualState(cat) {
    ensureCatRuntimeFields(cat, getNowIso());

    if (!cat.isAlive) {
      return { icon: "☠️", labelKey: "dead_state" };
    }
    if (cat.health <= 25) {
      return { icon: "😵", labelKey: "sick_state" };
    }
    if (cat.hunger <= 25) {
      return { icon: "😿", labelKey: "hungry_state" };
    }
    if (cat.mood >= 75) {
      return { icon: "😻", labelKey: "happy_state" };
    }
    if (cat.mood <= 35) {
      return { icon: "😾", labelKey: "sad_state" };
    }
    return { icon: "😺", labelKey: "calm_state" };
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
      return {
        ok: false,
        message: game.utils.i18n.getLanguage() === "en" ? "This cat has not been unlocked yet." : "这只猫咪还没有解锁。",
      };
    }
    ensureCatRuntimeFields(cat, nowIso);
    if (!cat.isAlive) {
      return {
        ok: false,
        message:
          getText(cat, "name") +
          (game.utils.i18n.getLanguage() === "en" ? " has died and can no longer interact." : "已经死亡，无法继续互动。"),
      };
    }

    if (actionKey === "feedBasic") {
      if (state.inventory.food <= 0) {
        return {
          ok: false,
          message: game.utils.i18n.getLanguage() === "en" ? "You're out of basic food. Buy more in the shop." : "普通猫粮不够了，去商店补货吧。",
        };
      }
      state.inventory.food -= 1;
      cat.hunger = clamp(cat.hunger + 25, 0, 100);
      cat.mood = clamp(cat.mood + 4, 0, 100);
      resetDecayTracker(cat, ["hunger", "mood"], nowIso);
      state.player.feedTimes += 1;
      state.player.feedTimesToday += 1;
      messages.push(
        getText(cat, "name") +
          (game.utils.i18n.getLanguage() === "en" ? " ate happily and hunger recovered nicely." : "吃得很认真，饱腹值明显回升。")
      );
    } else if (actionKey === "feedPremium") {
      if (state.inventory.premiumFood <= 0) {
        return { ok: false, message: game.utils.i18n.getLanguage() === "en" ? "You're out of premium food." : "高级猫粮用完了。" };
      }
      state.inventory.premiumFood -= 1;
      cat.hunger = clamp(cat.hunger + 45, 0, 100);
      cat.intimacy = clamp(cat.intimacy + 2, 0, 100);
      cat.mood = clamp(cat.mood + 6, 0, 100);
      resetDecayTracker(cat, ["hunger", "mood"], nowIso);
      state.player.feedTimes += 1;
      state.player.feedTimesToday += 1;
      messages.push(
        getText(cat, "name") +
          (game.utils.i18n.getLanguage() === "en" ? " enjoyed the premium food and rubbed against you happily." : "吃到了高级猫粮，开心得蹭了蹭你。")
      );
    } else if (actionKey === "clean") {
      if (state.inventory.litter <= 0) {
        return { ok: false, message: game.utils.i18n.getLanguage() === "en" ? "You're out of litter. Buy more from the shop." : "猫砂不够了，先去商店买一些。" };
      }
      state.inventory.litter -= 1;
      cat.clean = clamp(cat.clean + 30, 0, 100);
      cat.health = clamp(cat.health + 4, 0, 100);
      resetDecayTracker(cat, ["clean", "health"], nowIso);
      state.player.cleanTimes += 1;
      messages.push(
        game.utils.i18n.getLanguage() === "en"
          ? "You cleaned up for " + getText(cat, "name") + " and cleanliness improved."
          : "你帮" + getText(cat, "name") + "整理了环境，清洁值提升了。"
      );
    } else if (actionKey === "play") {
      cat.mood = clamp(cat.mood + 18 + comfortBonus, 0, 100);
      cat.intimacy = clamp(cat.intimacy + 8 + Math.min(4, state.inventory.toys * 2), 0, 100);
      cat.energy = clamp(cat.energy - 10, 0, 100);
      resetDecayTracker(cat, ["mood", "energy"], nowIso);
      state.player.playTimes += 1;
      state.player.playTimesToday += 1;
      state.player.mood = clamp(state.player.mood + 4, 0, 100);
      messages.push(
        game.utils.i18n.getLanguage() === "en"
          ? "You played with " + getText(cat, "name") + " for a while, and the mood lightened up."
          : "你陪" + getText(cat, "name") + "玩了好一会儿，气氛变得轻松很多。"
      );
      if (state.inventory.toys > 0) {
        messages.push(game.utils.i18n.getLanguage() === "en" ? "Your toy wand made playtime even more effective." : "家里的逗猫棒让这次陪玩更有效率。");
      }
    } else if (actionKey === "rest") {
      cat.energy = clamp(cat.energy + 20 + comfortBonus, 0, 100);
      cat.health = clamp(cat.health + 5, 0, 100);
      cat.mood = clamp(cat.mood + 3, 0, 100);
      resetDecayTracker(cat, ["energy", "health", "mood"], nowIso);
      messages.push(
        getText(cat, "name") +
          (game.utils.i18n.getLanguage() === "en" ? " took a comfortable rest in the cat bed." : "在猫窝里舒舒服服地休息了一会儿。")
      );
    } else {
      return { ok: false, message: game.utils.i18n.getLanguage() === "en" ? "Unknown cat interaction." : "未知的猫咪互动。" };
    }

    if (game.systems.taskSystem) {
      game.systems.taskSystem.refreshAllTasks();
    }

    return {
      ok: true,
      messages: messages,
    };
  }

  function readoptCat(catId) {
    var state = game.state.game;
    var cat = getCat(catId);
    var baseCat = getBaseCat(catId);
    var nowIso = getNowIso();
    var adoptionCount = 0;

    if (!cat || !baseCat || !cat.unlocked) {
      return {
        ok: false,
        message: game.utils.i18n.getLanguage() === "en" ? "This cat cannot be adopted right now." : "这只猫咪当前无法重新领养。",
      };
    }

    ensureCatRuntimeFields(cat, nowIso);
    if (cat.isAlive) {
      return { ok: false, message: t("readopt_unavailable") };
    }
    if (state.player.gold < game.config.readoptCost) {
      return { ok: false, message: t("readopt_failed_gold", { cost: game.config.readoptCost }) };
    }

    adoptionCount = (cat.adoptionCount || 0) + 1;
    state.player.gold -= game.config.readoptCost;
    state.player.totalSpend += game.config.readoptCost;

    Object.assign(cat, game.state.deepClone(baseCat), {
      unlocked: true,
      isAlive: true,
      diedAt: null,
      deathReason: null,
      adoptionCount: adoptionCount,
      decayTracker: {
        hunger: nowIso,
        clean: nowIso,
        mood: nowIso,
        health: nowIso,
        energy: nowIso,
      },
    });

    return {
      ok: true,
      forceSave: true,
      messages: [
        t("readopt_success", { name: getText(cat, "name") }),
        t("readopt_cost", { cost: game.config.readoptCost }),
      ],
    };
  }

  game.systems.catSystem = {
    getCat: getCat,
    performAction: performAction,
    syncCatDecay: syncCatDecay,
    getStatCountdown: getStatCountdown,
    getHungerDeathEta: getHungerDeathEta,
    ensureCatRuntimeFields: ensureCatRuntimeFields,
    getCatVisualState: getCatVisualState,
    readoptCat: readoptCat,
  };
})(window.CatGame);
