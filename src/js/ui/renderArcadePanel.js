(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;

  function renderPaytable() {
    return game.systems.arcadeSystem.symbols
      .map(function (symbol) {
        return (
          '<div class="notice-item"><p><strong>' +
          symbol.icon +
          " " +
          t(symbol.nameKey) +
          '</strong></p><p>' +
          t("slot_three_match", { value: symbol.multiplier }) +
          "</p></div>"
        );
      })
      .join("");
  }

  function renderArcadePanel(state) {
    var lastSpin = state.home.arcadeLastSpin;
    var bets = game.config.slotBets
      .map(function (bet) {
        return (
          '<button class="primary-button" data-slot-bet="' +
          bet +
          '">' +
          t("slot_spin_bet", { amount: bet }) +
          "</button>"
        );
      })
      .join("");

    return (
      '<section class="page-header">' +
      '<div class="page-card arcade-hero-card">' +
      '<p class="section-eyebrow">' + t("page_arcade") + "</p>" +
      '<h2 class="page-title">' + t("arcade_panel_title") + "</h2>" +
      '<p class="page-copy">' + t("arcade_panel_copy") + "</p>" +
      '<div class="inline-row" style="margin-top:18px; flex-wrap: wrap;">' +
      bets +
      "</div></div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("arcade_stats") + "</p>" +
      '<div class="notice-list" style="margin-top: 12px;">' +
      '<div class="notice-item"><p><strong>' + t("arcade_spins") + "</strong></p><p>" + state.player.arcadeSpins + "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("arcade_jackpots") + "</strong></p><p>" + state.player.arcadeJackpots + "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("arcade_best_win") + "</strong></p><p>" + state.player.arcadeBestWin + " " + t("gold_unit") + "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("arcade_profit") + "</strong></p><p>" +
      (state.player.arcadeTotalWon - state.player.arcadeTotalSpent) +
      " " +
      t("gold_unit") +
      "</p></div></div></div></section>" +
      '<section class="home-grid">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("slot_machine") + '</p><h3 class="panel-title">' + t("slot_machine_title") + "</h3>" +
      '<div class="slot-machine" style="margin-top: 16px;">' +
      '<div class="slot-window">' +
      (lastSpin ? lastSpin.reels[0] : "⭐") +
      '</div><div class="slot-window">' +
      (lastSpin ? lastSpin.reels[1] : "🐱") +
      '</div><div class="slot-window">' +
      (lastSpin ? lastSpin.reels[2] : "7️⃣") +
      "</div></div>" +
      '<p class="helper-text" style="margin-top: 14px;">' +
      (lastSpin
        ? t(lastSpin.resultKey, { payout: lastSpin.payout, bet: lastSpin.bet })
        : t("slot_intro")) +
      "</p>" +
      (lastSpin
        ? '<p class="helper-text" style="margin-top: 8px;">' + t("last_played_at", { time: format.formatRealDateTime(lastSpin.playedAt) }) + "</p>"
        : "") +
      '<div class="inline-row" style="margin-top: 16px; flex-wrap: wrap;">' + bets + "</div></div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("slot_paytable") + '</p><h3 class="panel-title">' + t("slot_rules_title") + "</h3>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      renderPaytable() +
      '<div class="notice-item"><p><strong>' + t("slot_special_bonus") + '</strong></p><p>' + t("slot_special_bonus_copy") + "</p></div>" +
      "</div></div></section>"
    );
  }

  game.ui.renderArcadePanel = renderArcadePanel;
})(window.CatGame);
