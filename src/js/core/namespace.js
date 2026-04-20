(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.12.0",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "睡觉改为按真实时间持续进行，现在可以开始睡觉并随时醒来，恢复量会根据实际睡眠时长结算。",
          "新增玩家饥饿属性，食物改为降低饥饿感；饥饿会随现实时间逐步上升并显示倒计时。",
          "玩家饥饿过高时将无法开始打工，必须先吃东西把状态降下来。",
        ],
        en: [
          "Sleep now runs in real time. You can start sleeping and wake up whenever you want, with recovery based on actual sleep duration.",
          "Added a player hunger stat. Food now reduces hunger, and hunger rises over real time with visible countdowns.",
          "Work is blocked when player hunger gets too high, so you need to eat before starting another shift.",
        ],
        ja: [
          "睡眠が現実時間で進行するようになり、いつでも起きられるようになりました。",
          "プレイヤーに空腹ステータスを追加し、食べ物は空腹を下げる用途に変更されました。",
          "空腹が高すぎると仕事を始められず、先に食事が必要になります。",
        ],
      },
      readoptCost: 80,
      toyWandUsesPerPurchase: 6,
      catUnlockRequirements: {
        gold: 5000,
        baseCatId: "cat_001",
        baseAgeYears: 1,
      },
      catAgeAcceleration: 10,
      pregnancyDurationMs: 30 * 60 * 1000,
      pregnancyFoodMultiplier: 2,
      roomUpgradeSteps: [
        { level: 1, capacity: 3, width: 620, height: 360, upgradeCost: 450 },
        { level: 2, capacity: 4, width: 760, height: 420, upgradeCost: 900 },
        { level: 3, capacity: 5, width: 900, height: 500, upgradeCost: 1600 },
        { level: 4, capacity: 6, width: 1020, height: 580, upgradeCost: null },
      ],
      diseaseCheckIntervalMs: 15 * 60 * 1000,
      staminaRecoveryIntervalMs: 60 * 60 * 1000,
      staminaRecoveryAmount: 5,
      customMusicMaxBytes: 2 * 1024 * 1024,
      slotBets: [20, 50, 100],
      playerCondition: {
        min: 0,
        max: 100,
        defaultStamina: 100,
        defaultMood: 80,
        defaultHunger: 20,
        hungerBlockThreshold: 80,
        hungerIncreaseIntervalMs: 15 * 60 * 1000,
        hungerIncreaseAmount: 4,
        sleepRecoveryPerHour: {
          stamina: 20,
          mood: 20,
        },
        workMoodThresholds: {
          normal: 60,
          tired: 30,
        },
        workMoodModifiers: {
          normal: {
            durationMultiplier: 1,
            penaltyChance: 0,
            penaltyRange: [0, 0],
          },
          tired: {
            durationMultiplier: 1.25,
            penaltyChance: 0,
            penaltyRange: [0, 0],
          },
          burnedOut: {
            durationMultiplier: 1.5,
            penaltyChance: 0.2,
            penaltyRange: [0.1, 0.2],
          },
        },
        moodLevels: [
          { min: 80, key: "player_mood_very_good", tone: "is-good" },
          { min: 60, key: "player_mood_good", tone: "is-success" },
          { min: 30, key: "player_mood_tired", tone: "is-warning" },
          { min: 0, key: "player_mood_burned_out", tone: "is-danger" },
        ],
      },
      catDecayRules: {
        hunger: { intervalMs: 12 * 60 * 1000, label: "饱腹" },
        clean: { intervalMs: 8 * 60 * 1000, label: "清洁" },
        mood: { intervalMs: 6 * 60 * 1000, label: "心情" },
        health: { intervalMs: 10 * 60 * 1000, label: "健康" },
        energy: { intervalMs: 5 * 60 * 1000, label: "活力" },
      },
    },
    data: {},
    utils: {},
    state: {
      game: null,
      currentPage: "home",
      selectedCatId: "cat_001",
      notifications: [],
      arcadeSpin: null,
      roomDrag: null,
      collectionInspectCatId: null,
    },
    systems: {},
    ui: {},
  };
})();
