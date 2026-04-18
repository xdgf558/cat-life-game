(function (game) {
  function deepClone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function mergeById(baseList, savedList) {
    var savedMap = {};
    var extraItems = [];

    (savedList || []).forEach(function (item) {
      if (item && item.id) {
        savedMap[item.id] = item;
      } else if (item) {
        extraItems.push(item);
      }
    });

    return baseList
      .map(function (baseItem) {
        return Object.assign({}, deepClone(baseItem), savedMap[baseItem.id] || {});
      })
      .concat(extraItems);
  }

  function createTaskState(list) {
    return deepClone(list).map(function (task) {
      return Object.assign({}, task, {
        progress: 0,
        claimed: false,
      });
    });
  }

  function createDefaultJobs() {
    return deepClone(game.data.jobs).map(function (job) {
      return Object.assign({}, job, {
        workCount: 0,
        unlocked: job.unlockLevel <= 1,
      });
    });
  }

  function createDefaultCats() {
    return deepClone(game.data.cats);
  }

  function createNewGame() {
    var now = new Date();
    return {
      version: game.config.version,
      meta: {
        createdAt: now.toISOString(),
        lastSavedAt: null,
        lastPlayedDate: game.utils.format.formatDateKey(now),
        lastSyncAt: now.toISOString(),
        lastSeenVersion: null,
      },
      player: {
        name: "玩家",
        level: 1,
        exp: 0,
        gold: 200,
        stamina: 100,
        mood: 80,
        currentDay: 1,
        currentHour: 8,
        totalIncome: 0,
        totalSpend: 0,
        workTimes: 0,
        workTimesToday: 0,
        feedTimes: 0,
        feedTimesToday: 0,
        cleanTimes: 0,
        playTimes: 0,
        playTimesToday: 0,
        furniturePurchaseCount: 0,
        activeWork: null,
      },
      cats: createDefaultCats(),
      inventory: {
        food: 3,
        premiumFood: 1,
        litter: 2,
        toys: 1,
        medicine: 0,
        furnitureOwned: game.config.startingFurniture.slice(),
      },
      jobs: createDefaultJobs(),
      tasks: {
        tutorial: createTaskState(game.data.tasks.tutorial),
        daily: createTaskState(game.data.tasks.daily),
        achievements: createTaskState(game.data.tasks.achievements),
        lastResetDay: 1,
        lastResetDate: game.utils.format.formatDateKey(now),
        _dailySpendOffset: 0,
      },
      home: {
        roomLevel: 1,
        comfortScore: 30,
        placedFurniture: game.config.startingFurniture.slice(),
        rooms: ["小客厅"],
      },
      settings: {
        bgmVolume: 60,
        sfxVolume: 70,
        autoSave: true,
        language: "zh-CN",
      },
      flags: {
        tutorialFinished: false,
      },
    };
  }

  function normalizeTaskBlock(savedTasks, baseTasks) {
    return {
      tutorial: mergeById(baseTasks.tutorial, savedTasks && savedTasks.tutorial),
      daily: mergeById(baseTasks.daily, savedTasks && savedTasks.daily),
      achievements: mergeById(baseTasks.achievements, savedTasks && savedTasks.achievements),
      lastResetDay: (savedTasks && savedTasks.lastResetDay) || 1,
      _dailySpendOffset:
        savedTasks && typeof savedTasks._dailySpendOffset === "number"
          ? savedTasks._dailySpendOffset
          : 0,
    };
  }

  function normalizeGameData(saveData) {
    var fresh = createNewGame();
    var normalized = {
      version: saveData.version || fresh.version,
      meta: Object.assign({}, fresh.meta, saveData.meta || {}),
      player: Object.assign({}, fresh.player, saveData.player || {}),
      cats:
        Array.isArray(saveData.cats) && saveData.cats.length
          ? mergeById(fresh.cats, saveData.cats)
          : fresh.cats,
      inventory: Object.assign({}, fresh.inventory, saveData.inventory || {}),
      jobs:
        Array.isArray(saveData.jobs) && saveData.jobs.length
          ? mergeById(fresh.jobs, saveData.jobs)
          : fresh.jobs,
      tasks: normalizeTaskBlock(saveData.tasks || {}, fresh.tasks),
      home: Object.assign({}, fresh.home, saveData.home || {}),
      settings: Object.assign({}, fresh.settings, saveData.settings || {}),
      flags: Object.assign({}, fresh.flags, saveData.flags || {}),
    };

    if (!Array.isArray(normalized.inventory.furnitureOwned)) {
      normalized.inventory.furnitureOwned = fresh.inventory.furnitureOwned.slice();
    }

    if (!Array.isArray(normalized.home.placedFurniture)) {
      normalized.home.placedFurniture = fresh.home.placedFurniture.slice();
    }

    normalized.home.rooms = Array.isArray(normalized.home.rooms)
      ? normalized.home.rooms
      : fresh.home.rooms.slice();

    if (!normalized.meta.lastSyncAt) {
      normalized.meta.lastSyncAt = fresh.meta.lastSyncAt;
    }

    if (typeof normalized.meta.lastSeenVersion !== "string" && normalized.meta.lastSeenVersion !== null) {
      normalized.meta.lastSeenVersion = null;
    }

    if (!normalized.tasks.lastResetDate) {
      normalized.tasks.lastResetDate = fresh.tasks.lastResetDate;
    }

    if (!normalized.player.activeWork) {
      normalized.player.activeWork = null;
    }

    return normalized;
  }

  game.state.deepClone = deepClone;
  game.state.createNewGame = createNewGame;
  game.state.normalizeGameData = normalizeGameData;
})(window.CatGame);
