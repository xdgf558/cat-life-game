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

  function clampStat(value, fallback) {
    var min = game.config.playerCondition.min;
    var max = game.config.playerCondition.max;
    var numberValue = typeof value === "number" ? value : fallback;
    return Math.max(min, Math.min(max, numberValue));
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
        stamina: game.config.playerCondition.defaultStamina,
        mood: game.config.playerCondition.defaultMood,
        hunger: game.config.playerCondition.defaultHunger,
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
        arcadeSpins: 0,
        arcadeJackpots: 0,
        arcadeBestWin: 0,
        arcadeTotalSpent: 0,
        arcadeTotalWon: 0,
        staminaUpdatedAt: now.toISOString(),
        hungerUpdatedAt: now.toISOString(),
        lastSleepAt: null,
        lastWorkResult: null,
        activeSleep: null,
        bank: {
          balance: 0,
          hasActiveLoan: false,
          principal: 0,
          accruedInterest: 0,
          totalDebt: 0,
          loanStartDay: null,
          lastInterestAccrualDay: null,
          lastSavingsInterestDay: 1,
          creditTier: 0,
          goodRepaymentCount: 0,
          lateRepaymentCount: 0,
          currentLoanInterestDays: 0,
        },
        activeWork: null,
      },
      cats: createDefaultCats(),
      inventory: {
        food: 3,
        premiumFood: 1,
        litter: 2,
        toys: 0,
        catGrass: 0,
        medicine: 0,
        bread: 0,
        instantNoodles: 0,
        bento: 0,
        dessert: 0,
        bottledWater: 0,
        soda: 0,
        coffee: 0,
        beer: 0,
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
        furnitureLayout: {},
        rooms: ["小客厅"],
        arcadeLastSpin: null,
        roomScene: {
          wall: "sunny",
          floor: "oak",
          decor: "plants",
          layout: "cozy",
        },
      },
      settings: {
        bgmVolume: 60,
        sfxVolume: 70,
        autoSave: true,
        language: "zh-CN",
        bgmEnabled: true,
        customMusicEnabled: false,
        customMusicData: "",
        customMusicName: "",
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

    if (!normalized.home.furnitureLayout || typeof normalized.home.furnitureLayout !== "object") {
      normalized.home.furnitureLayout = {};
    }

    normalized.home.rooms = Array.isArray(normalized.home.rooms)
      ? normalized.home.rooms
      : fresh.home.rooms.slice();

    if (!normalized.home.arcadeLastSpin || typeof normalized.home.arcadeLastSpin !== "object") {
      normalized.home.arcadeLastSpin = fresh.home.arcadeLastSpin;
    }

    if (!normalized.home.roomScene || typeof normalized.home.roomScene !== "object") {
      normalized.home.roomScene = game.state.deepClone(fresh.home.roomScene);
    } else {
      normalized.home.roomScene = Object.assign({}, fresh.home.roomScene, normalized.home.roomScene);
    }

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
    if (!normalized.player.lastSleepAt) {
      normalized.player.lastSleepAt = null;
    }
    if (!normalized.player.activeSleep || typeof normalized.player.activeSleep !== "object") {
      normalized.player.activeSleep = null;
    }
    if (!normalized.player.lastWorkResult || typeof normalized.player.lastWorkResult !== "object") {
      normalized.player.lastWorkResult = null;
    }
    if (!normalized.player.bank || typeof normalized.player.bank !== "object") {
      normalized.player.bank = game.state.deepClone(fresh.player.bank);
    } else {
      normalized.player.bank = Object.assign(
        {},
        game.state.deepClone(fresh.player.bank),
        normalized.player.bank
      );
    }

    if (typeof normalized.player.hospitalVisits !== "number") {
      normalized.player.hospitalVisits = 0;
    }

    if (typeof normalized.player.arcadeSpins !== "number") {
      normalized.player.arcadeSpins = 0;
    }
    if (typeof normalized.player.arcadeJackpots !== "number") {
      normalized.player.arcadeJackpots = 0;
    }
    if (typeof normalized.player.arcadeBestWin !== "number") {
      normalized.player.arcadeBestWin = 0;
    }
    if (typeof normalized.player.arcadeTotalSpent !== "number") {
      normalized.player.arcadeTotalSpent = 0;
    }
    if (typeof normalized.player.arcadeTotalWon !== "number") {
      normalized.player.arcadeTotalWon = 0;
    }

    if (!normalized.player.staminaUpdatedAt) {
      normalized.player.staminaUpdatedAt = normalized.meta.lastSyncAt || fresh.player.staminaUpdatedAt;
    }
    normalized.player.stamina = clampStat(
      normalized.player.stamina,
      game.config.playerCondition.defaultStamina
    );
    normalized.player.mood = clampStat(
      normalized.player.mood,
      game.config.playerCondition.defaultMood
    );
    normalized.player.hunger = clampStat(
      normalized.player.hunger,
      game.config.playerCondition.defaultHunger
    );
    if (!normalized.player.hungerUpdatedAt) {
      normalized.player.hungerUpdatedAt = normalized.meta.lastSyncAt || fresh.player.hungerUpdatedAt;
    }
    normalized.player.bank.balance = Math.max(0, Number(normalized.player.bank.balance || 0));
    normalized.player.bank.hasActiveLoan = Boolean(normalized.player.bank.hasActiveLoan);
    normalized.player.bank.principal = Math.max(0, Number(normalized.player.bank.principal || 0));
    normalized.player.bank.accruedInterest = Math.max(
      0,
      Number(normalized.player.bank.accruedInterest || 0)
    );
    normalized.player.bank.totalDebt = Math.max(
      0,
      Number(
        normalized.player.bank.totalDebt ||
          normalized.player.bank.principal + normalized.player.bank.accruedInterest
      )
    );
    if (normalized.player.bank.loanStartDay !== null) {
      normalized.player.bank.loanStartDay = Number(normalized.player.bank.loanStartDay || 0);
    }
    if (normalized.player.bank.lastInterestAccrualDay !== null) {
      normalized.player.bank.lastInterestAccrualDay = Number(
        normalized.player.bank.lastInterestAccrualDay || 0
      );
    }
    if (normalized.player.bank.lastSavingsInterestDay !== null) {
      normalized.player.bank.lastSavingsInterestDay = Number(
        normalized.player.bank.lastSavingsInterestDay || 0
      );
    }
    normalized.player.bank.creditTier = Math.max(
      game.config.bank.minCreditTier,
      Math.min(
        game.config.bank.maxCreditTier,
        Number(normalized.player.bank.creditTier || 0)
      )
    );
    normalized.player.bank.goodRepaymentCount = Math.max(
      0,
      Number(normalized.player.bank.goodRepaymentCount || 0)
    );
    normalized.player.bank.lateRepaymentCount = Math.max(
      0,
      Number(normalized.player.bank.lateRepaymentCount || 0)
    );
    normalized.player.bank.currentLoanInterestDays = Math.max(
      0,
      Number(normalized.player.bank.currentLoanInterestDays || 0)
    );
    if (normalized.player.bank.principal <= 0 && normalized.player.bank.accruedInterest <= 0) {
      normalized.player.bank.hasActiveLoan = false;
      normalized.player.bank.totalDebt = 0;
      normalized.player.bank.loanStartDay = null;
      normalized.player.bank.lastInterestAccrualDay = null;
      normalized.player.bank.currentLoanInterestDays = 0;
    } else {
      normalized.player.bank.hasActiveLoan = true;
      normalized.player.bank.totalDebt =
        normalized.player.bank.principal + normalized.player.bank.accruedInterest;
      if (normalized.player.bank.loanStartDay === null) {
        normalized.player.bank.loanStartDay = normalized.player.currentDay || 1;
      }
      if (normalized.player.bank.lastInterestAccrualDay === null) {
        normalized.player.bank.lastInterestAccrualDay = normalized.player.currentDay || 1;
      }
    }
    if (normalized.player.bank.lastSavingsInterestDay === null) {
      normalized.player.bank.lastSavingsInterestDay = normalized.player.currentDay || 1;
    }

    if (typeof normalized.inventory.toys !== "number") {
      normalized.inventory.toys = fresh.inventory.toys;
    }
    if (typeof normalized.inventory.catGrass !== "number") {
      normalized.inventory.catGrass = fresh.inventory.catGrass;
    }
    if (typeof normalized.inventory.medicine !== "number") {
      normalized.inventory.medicine = fresh.inventory.medicine;
    }
    if (typeof normalized.inventory.bread !== "number") {
      normalized.inventory.bread = fresh.inventory.bread;
    }
    if (typeof normalized.inventory.instantNoodles !== "number") {
      normalized.inventory.instantNoodles = fresh.inventory.instantNoodles;
    }
    if (typeof normalized.inventory.bento !== "number") {
      normalized.inventory.bento = fresh.inventory.bento;
    }
    if (typeof normalized.inventory.dessert !== "number") {
      normalized.inventory.dessert = fresh.inventory.dessert;
    }
    if (typeof normalized.inventory.bottledWater !== "number") {
      normalized.inventory.bottledWater = fresh.inventory.bottledWater;
    }
    if (typeof normalized.inventory.soda !== "number") {
      normalized.inventory.soda = fresh.inventory.soda;
    }
    if (typeof normalized.inventory.coffee !== "number") {
      normalized.inventory.coffee = fresh.inventory.coffee;
    }
    if (typeof normalized.inventory.beer !== "number") {
      normalized.inventory.beer = fresh.inventory.beer;
    }

    if (typeof normalized.settings.bgmEnabled !== "boolean") {
      normalized.settings.bgmEnabled = fresh.settings.bgmEnabled;
    }
    if (typeof normalized.settings.customMusicEnabled !== "boolean") {
      normalized.settings.customMusicEnabled = fresh.settings.customMusicEnabled;
    }
    if (typeof normalized.settings.customMusicData !== "string") {
      normalized.settings.customMusicData = fresh.settings.customMusicData;
    }
    if (typeof normalized.settings.customMusicName !== "string") {
      normalized.settings.customMusicName = fresh.settings.customMusicName;
    }
    if (!normalized.settings.customMusicData) {
      normalized.settings.customMusicEnabled = false;
      normalized.settings.customMusicName = "";
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
      var defaultTraits = {
        artKey: "orange_tabby",
        furColor: "#f3a64a",
        patchColor: "#fff0be",
        pattern: "tabby",
        eyeColor: "#3f9a4d",
        accessory: "bell",
      };
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
      if (typeof cat.initialAgeYears !== "number") {
        cat.initialAgeYears = typeof baseCat.initialAgeYears === "number" ? baseCat.initialAgeYears : cat.ageYears || 0.2;
      }
      if (!cat.ageUpdatedAt) {
        cat.ageUpdatedAt = fallbackTime;
      }
      if (cat.gender !== "male" && cat.gender !== "female") {
        cat.gender = baseCat.gender || "male";
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
      if (typeof cat.isPregnant !== "boolean") {
        cat.isPregnant = false;
      }
      if (!cat.pregnancyStartedAt) {
        cat.pregnancyStartedAt = null;
      }
      if (!cat.pregnancyDueAt) {
        cat.pregnancyDueAt = null;
      }
      if (!cat.pregnancyMateId) {
        cat.pregnancyMateId = null;
      }
      if (typeof cat.pregnancyLitterSize !== "number") {
        cat.pregnancyLitterSize = 0;
      }
      if (!Array.isArray(cat.parents)) {
        cat.parents = [];
      }
      if (!cat.bornAt) {
        cat.bornAt = null;
      }
      if (!cat.traits || typeof cat.traits !== "object") {
        cat.traits = {};
      }
      cat.traits = Object.assign({}, defaultTraits, baseCat.traits || {}, cat.traits);
      if (!cat.traits.artKey) {
        cat.traits.artKey = game.utils.catArt.inferArtKeyFromTraits(cat.traits);
      }
      if (!cat.iconSet || typeof cat.iconSet !== "object") {
        cat.iconSet = {};
      }
      cat.iconSet = Object.assign({}, baseCat.iconSet || {}, cat.iconSet);
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
