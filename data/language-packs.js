(() => {
  "use strict";

  const sourceLocale = "zh-CN";
  const localeStorageKey = "ielts-vocabulary-lab-locale-v1";
  const locales = window.IELTS_LANGUAGE_MANIFEST?.locales || [];
  const packs = window.IELTS_LANGUAGE_PACKS || {};

  function isAvailable(locale) {
    const item = locales.find((candidate) => candidate.locale === locale);
    return Boolean(item && ["source", "ready"].includes(item.status) && packs[locale]);
  }

  function currentLocale() {
    try {
      const saved = localStorage.getItem(localeStorageKey);
      if (saved && isAvailable(saved)) return saved;
    } catch {}
    return sourceLocale;
  }

  function setLocale(locale) {
    if (!isAvailable(locale)) return false;
    try { localStorage.setItem(localeStorageKey, locale); } catch { return false; }
    return true;
  }

  function localizeWord(word, locale = currentLocale()) {
    const entry = packs[locale]?.words?.[word.id];
    if (!entry) return { ...word };
    return {
      ...word,
      dayTitle: entry.dayTitle,
      meaningZh: entry.meaning,
      exampleZh: entry.exampleTranslation,
      note: entry.note,
      wordFamily: entry.wordFamily,
    };
  }

  function localeInfo(locale = currentLocale()) {
    return locales.find((item) => item.locale === locale) || locales[0];
  }

  window.IELTSLocale = Object.freeze({
    locales: locales.map((item) => ({ ...item })),
    availableLocales: () => locales.filter((item) => isAvailable(item.locale)).map((item) => ({ ...item })),
    currentLocale,
    currentPack: (locale = currentLocale()) => packs[locale] || null,
    isAvailable,
    localeInfo,
    localizeWord,
    setLocale,
  });
})();
