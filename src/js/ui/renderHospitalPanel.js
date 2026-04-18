(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;

  function renderSickCard(cat) {
    var disease = game.systems.catSystem.getCatDisease(cat);
    var visual = game.systems.catSystem.getCatVisualState(cat);
    var countdown = game.systems.catSystem.getDiseaseProgressCountdown(cat);

    return (
      '<article class="page-card">' +
      '<div class="inline-row"><div class="item-title"><span class="cat-portrait-icon hospital-cat-icon">' +
      visual.icon +
      '</span><div><p class="section-eyebrow">' + t("current_cat") + '</p><h3 class="panel-title">' +
      format.escapeHtml(getText(cat, "name")) +
      "</h3></div></div><span class=\"status-pill is-danger\">" +
      format.escapeHtml(getText(disease, "name")) +
      "</span></div>" +
      '<p class="page-copy" style="margin-top: 12px;">' +
      format.escapeHtml(getText(disease, "description")) +
      "</p>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      '<div class="notice-item"><p><strong>' + t("age_label") + "</strong></p><p>" +
      format.escapeHtml(format.formatAgeYears(game.systems.catSystem.getCatAgeYears(cat))) +
      '</p></div><div class="notice-item"><p><strong>' + t("disease_cost") + "</strong></p><p>" +
      disease.treatmentCost +
      " " +
      t("gold_unit") +
      '</p></div><div class="notice-item"><p><strong>' + t("next_worsen") + "</strong></p><p>" +
      (countdown === null ? t("stopped") : format.formatDuration(countdown)) +
      '</p></div><div class="notice-item"><p><strong>' + t("contagious_label") + "</strong></p><p>" +
      (disease.contagious ? t("contagious_yes") : t("contagious_no")) +
      "</p></div></div>" +
      '<div style="margin-top: 16px;">' +
      game.ui.helpers.renderBar(t("health_label"), cat.health) +
      game.ui.helpers.renderBar(t("mood_label"), cat.mood) +
      "</div>" +
      '<div class="inline-row" style="margin-top: 16px; flex-wrap: wrap;">' +
      '<button class="primary-button" data-treat-cat="' +
      cat.id +
      '">' +
      t("treat_now") +
      "</button>" +
      '<span class="helper-text">' + t("treatment_copy") + "</span>" +
      "</div></article>"
    );
  }

  function renderHospitalPanel(state) {
    var sickCats = state.cats.filter(function (cat) {
      return cat.unlocked && cat.isAlive !== false && !!cat.diseaseId;
    });
    var healthyCats = state.cats.filter(function (cat) {
      return cat.unlocked && cat.isAlive !== false && !cat.diseaseId;
    });

    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("page_hospital") + "</p>" +
      '<h2 class="page-title">' + t("hospital_panel_title") + "</h2>" +
      '<p class="page-copy">' + t("hospital_panel_copy") + "</p>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("hospital_alert") + "</p>" +
      '<p class="page-copy">' +
      (sickCats.length ? t("hospital_alert_copy", { count: sickCats.length }) : t("hospital_empty_copy")) +
      "</p></div></section>" +
      '<section class="home-grid">' +
      '<div class="page-card">' +
      '<div class="inline-row"><div><p class="section-eyebrow">' + t("hospital_alert") + '</p><h3 class="panel-title">' +
      t("treat_now") +
      '</h3></div><span class="pill">' + sickCats.length + "</span></div>" +
      (sickCats.length
        ? sickCats.map(renderSickCard).join("")
        : '<div class="empty-state">' + t("hospital_empty") + "</div>") +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("healthy_cats") + '</p><h3 class="panel-title">' + t("disease_manual") + "</h3>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      healthyCats
        .map(function (cat) {
          return '<div class="notice-item"><p><strong>' +
            format.escapeHtml(getText(cat, "name")) +
            '</strong></p><p>' +
            format.escapeHtml(format.formatAgeYears(game.systems.catSystem.getCatAgeYears(cat))) +
            " · " +
            t("disease_none") +
            "</p></div>";
        })
        .join("") +
      game.data.diseases
        .map(function (disease) {
          return '<div class="notice-item"><p><strong>' +
            disease.icon +
            " " +
            format.escapeHtml(getText(disease, "name")) +
            '</strong></p><p>' +
            format.escapeHtml(getText(disease, "description")) +
            "<br />" +
            t("disease_cost") +
            "：" +
            disease.treatmentCost +
            " " +
            t("gold_unit") +
            " · " +
            t("contagious_label") +
            "：" +
            (disease.contagious ? t("contagious_yes") : t("contagious_no")) +
            "</p></div>";
        })
        .join("") +
      "</div></div></section>"
    );
  }

  game.ui.renderHospitalPanel = renderHospitalPanel;
})(window.CatGame);
