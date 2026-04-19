(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;

  function renderCollectionCard(cat) {
    var pregnancyCountdown = game.systems.collectionSystem.getPregnancyCountdown(cat);

    return (
      '<article class="cat-card">' +
      '<div class="item-title"><img class="cat-illustration" src="' +
      game.utils.catArt.buildCatSvg(cat, 120) +
      '" alt="' +
      format.escapeHtml(getText(cat, "name")) +
      '" /><div><p class="section-eyebrow">' + t("cat_collection_entry") + '</p><h3 class="panel-title">' +
      format.escapeHtml(getText(cat, "name")) +
      "</h3><p class=\"page-copy\">" +
      format.escapeHtml(getText(cat, "breed")) +
      " · " +
      format.escapeHtml(format.formatAgeYears(game.systems.catSystem.getCatAgeYears(cat))) +
      '</p><p class="helper-text" style="margin-top: 6px;">' +
      t("gender_label") +
      "：" +
      t(cat.gender === "female" ? "gender_female" : "gender_male") +
      (pregnancyCountdown !== null ? " · " + t("pregnancy_due") + " " + format.formatDuration(pregnancyCountdown) : "") +
      "</p></div></div></article>"
    );
  }

  function renderCollectionPanel(state) {
    var stats = game.systems.collectionSystem.getCollectionStats();
    var breedableCats = game.systems.collectionSystem.getBreedableCats();
    var unlockedCats = game.systems.collectionSystem.getUnlockedCats();
    var pregnantCats = game.systems.collectionSystem.getPregnantCats();
    var breedOptions = breedableCats.length
      ? breedableCats
          .map(function (cat) {
            return (
              '<option value="' +
              cat.id +
              '">' +
              format.escapeHtml(getText(cat, "name")) +
              " · " +
              t(cat.gender === "female" ? "gender_female" : "gender_male") +
              "</option>"
            );
          })
          .join("")
      : '<option value="">' + t("breed_pick_two") + "</option>";
    var galleryMarkup = unlockedCats.length
      ? unlockedCats.map(renderCollectionCard).join("")
      : '<div class="empty-state">' + t("no_cat_data") + "</div>";
    var pregnantMarkup = pregnantCats.length
      ? pregnantCats
          .map(function (cat) {
            return (
              '<div class="notice-item"><p><strong>' +
              format.escapeHtml(getText(cat, "name")) +
              "</strong></p><p>" +
              t("pregnancy_active") +
              " · " +
              t("pregnancy_due") +
              " " +
              format.formatDuration(game.systems.collectionSystem.getPregnancyCountdown(cat)) +
              "</p></div>"
            );
          })
          .join("")
      : '<div class="notice-item"><p><strong>' + t("pregnancy_status") + "</strong></p><p>" + t("pregnancy_none") + "</p></div>";

    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("page_collection") + "</p>" +
      '<h2 class="page-title">' + t("collection_panel_title") + "</h2>" +
      '<p class="page-copy">' + t("collection_panel_copy") + "</p>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("collection_stats") + "</p>" +
      '<div class="notice-list" style="margin-top: 12px;">' +
      '<div class="notice-item"><p><strong>' + t("collection_total_cats") + "</strong></p><p>" + stats.totalCats + "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("collection_unique_looks") + "</strong></p><p>" + stats.uniqueLooks + "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("collection_kittens") + "</strong></p><p>" + stats.kittens + "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("pregnancy_status") + "</strong></p><p>" + pregnantCats.length + "</p></div>" +
      "</div></div></section>" +
      '<section class="home-grid">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("breed_panel_title") + '</p><h3 class="panel-title">' + t("breed_panel_title") + "</h3>" +
      '<p class="page-copy" style="margin-top: 8px;">' + t("breed_panel_copy") + "</p>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      '<div class="notice-item"><p><strong>' + t("breed_parent_a") + '</strong></p><select id="breed-parent-a" class="field">' +
      breedOptions +
      "</select></div>" +
      '<div class="notice-item"><p><strong>' + t("breed_parent_b") + '</strong></p><select id="breed-parent-b" class="field">' +
      breedOptions +
      "</select></div>" +
      '<button class="primary-button" style="margin-top: 16px;" data-breed-cats ' +
      (breedableCats.length < 2 ? "disabled" : "") +
      ">" + t("breed_action") + "</button>" +
      '<p class="helper-text" style="margin-top: 10px;">' + t("breed_hint") + "</p>" +
      '<div class="notice-list" style="margin-top: 14px;">' + pregnantMarkup + "</div>" +
      "</div></div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("collection_gallery") + '</p><h3 class="panel-title">' + t("collection_gallery") + "</h3>" +
      '<p class="page-copy" style="margin-top: 8px;">' + t("collection_gallery_copy") + "</p>" +
      '<div class="card-grid" style="margin-top: 16px;">' +
      galleryMarkup +
      "</div></div></section>"
    );
  }

  game.ui.renderCollectionPanel = renderCollectionPanel;
})(window.CatGame);
