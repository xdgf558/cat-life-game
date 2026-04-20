(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.10.0",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "新增日语语言选项，界面文案会优先显示日语，不足部分自动回退到英文。",
          "三只主猫现在改用你提供的贴图资源，并按页面与房间场景自动缩放显示。",
          "后续出生的小猫会在橘猫、奶牛猫、蓝猫这三种贴图毛色中随机变化。",
        ],
        en: [
          "Added Japanese as a new language option, with English fallback for untranslated dynamic text.",
          "The three main cats now use the provided art sprites and scale automatically for each game scene.",
          "Future kittens now randomize their coat art between the orange tabby, cow cat, and blue cat variants.",
        ],
        ja: [
          "日本語を追加し、未翻訳の動的テキストは英語へ自動フォールバックします。",
          "3匹のメイン猫は提供された画像スプライトに差し替え、各画面に合わせて自動縮尺します。",
          "これから生まれる子猫は茶トラ、ハチワレ、ブルーの3種類の毛色画像からランダムに変化します。",
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
      slotBets: [20, 50, 100],
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
