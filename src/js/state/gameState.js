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
    var nowIso = new Date().toISOString();
    return deepClone(game.data.cats).map(function (cat) {
      return Object.assign({}, cat, {
        isAlive: true,
        diedAt: null,
        deathReason: null,
        ageYears: typeof cat.initialAgeYears === "number" ? cat.initialAgeYears : 0.2,
        ageUpdatedAt: nowIso,
        diseaseId: null,
        diseaseStartedAt: null,
        diseaseProgressAt: nowIso,
        diseaseCheckAt: nowIso,
        diseaseHistory: [],
        adoptionCount: 0,
        decayTracker: {
          hunger: nowIso,
          clean: nowIso,
          mood: nowIso,
          health: nowIso,
          energy: nowIso,
        },
      });
    });
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
        hospitalVisits: 0,
        staminaUpdatedAt: now.toISOString(),
        activeWork: null,
      },
      cats: createDefaultCats(),
      inventory: {
        food: 3,
        premiumFood: 1,
        litter: 2,
        toys: 0,
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
        toyUsesMigrated: true,
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

    if (typeof normalized.player.hospitalVisits !== "number") {
      normalized.player.hospitalVisits = 0;
    }

    if (!normalized.player.staminaUpdatedAt) {
      normalized.player.staminaUpdatedAt = normalized.meta.lastSyncAt || fresh.player.staminaUpdatedAt;
    }

    if (typeof normalized.inventory.toys !== "number") {
      normalized.inventory.toys = fresh.inventory.toys;
    }

    if (normalized.flags.toyUsesMigrated !== true) {
      if (normalized.inventory.toys > 0) {
        normalized.inventory.toys = normalized.inventory.toys * game.config.toyWandUsesPerPurchase;
      }
      normalized.flags.toyUsesMigrated = true;
    }

    normalized.cats = normalized.cats.map(function (cat) {
      var fallbackTime = normalized.meta.lastSyncAt || fresh.meta.lastSyncAt;
      var baseCat = game.data.cats.find(function (entry) {
        return entry.id === cat.id;
      }) || {};
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
      if (typeof cat.ageYears !== "number") {
        cat.ageYears = typeof baseCat.initialAgeYears === "number" ? baseCat.initialAgeYears : 0.2;
      }
      if (!cat.ageUpdatedAt) {
        cat.ageUpdatedAt = fallbackTime;
      }
      if (!cat.diseaseId) {
        cat.diseaseId = null;
      }
      if (!cat.diseaseStartedAt) {
        cat.diseaseStartedAt = null;
      }
      if (!cat.diseaseProgressAt) {
        cat.diseaseProgressAt = fallbackTime;
      }
      if (!cat.diseaseCheckAt) {
        cat.diseaseCheckAt = fallbackTime;
      }
      if (!Array.isArray(cat.diseaseHistory)) {
        cat.diseaseHistory = [];
      }
      if (!cat.decayTracker) {
        cat.decayTracker = {};
      }
      ["hunger", "clean", "mood", "health", "energy"].forEach(function (key) {
        if (!cat.decayTracker[key]) {
          cat.decayTracker[key] = fallbackTime;
        }
      });
      return cat;
    });

    return normalized;
  }

  game.state.deepClone = deepClone;
  game.state.createNewGame = createNewGame;
  game.state.normalizeGameData = normalizeGameData;
})(window.CatGame);
