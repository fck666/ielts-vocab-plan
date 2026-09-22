window.IELTSDatabaseReady.then((database) => {
(() => {
  "use strict";

  const words = Array.isArray(window.IELTS_WORDS) ? window.IELTS_WORDS : [];
  const db = database;
  const DAILY_TRAINING_STORAGE_KEY = "ielts-vocabulary-lab-daily-training-v1";
  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => [...document.querySelectorAll(selector)];

  const weeklyOutputPlan = [
    { week: 1, speakingTheme: "教育、学习", writingTheme: "教育政策、学校制度", hints: ["access to education", "academic performance", "from my perspective"], part1: "Do you enjoy learning new things?", part2: "Describe a teacher who influenced you.", part3: "Why should schools develop critical thinking?", task1: "The bar chart shows the percentage of students choosing four types of school activity in 2000 and 2020.", task2: "Some people believe schools should focus mainly on academic subjects, while others think practical skills are equally important. Discuss both views and give your opinion." },
    { week: 2, speakingTheme: "工作、职场", writingTheme: "工作方式、就业与技能", hints: ["transferable skills", "career progression", "work-life balance"], part1: "What kind of work would you like to do in the future?", part2: "Describe a useful skill you learned for work.", part3: "How can employers help people maintain a healthy work-life balance?", task1: "The table compares the average weekly working hours and job satisfaction of five occupations.", task2: "Many people now work from home. Do the advantages outweigh the disadvantages?" },
    { week: 3, speakingTheme: "科技、数字生活", writingTheme: "科技影响、网络与隐私", hints: ["technological innovation", "digital wellbeing", "data privacy"], part1: "How often do you use digital devices?", part2: "Describe a piece of technology that is useful to you.", part3: "Has technology improved the quality of human communication?", task1: "The line graph shows the percentage of households with internet access in three countries from 2005 to 2025.", task2: "Technology makes communication easier, but it can also reduce face-to-face interaction. Discuss both sides and give your opinion." },
    { week: 4, speakingTheme: "环境、能源", writingTheme: "环境政策、气候变化", hints: ["carbon emissions", "renewable energy", "environmental policy"], part1: "What environmental problem concerns you most?", part2: "Describe a place where you noticed environmental change.", part3: "Should individuals or governments take more responsibility for climate change?", task1: "The diagram illustrates how household waste is collected and processed for recycling.", task2: "Governments should prioritise environmental protection even when it slows economic growth. To what extent do you agree or disagree?" },
    { week: 5, speakingTheme: "健康、生活方式", writingTheme: "公共健康、医疗资源", hints: ["preventive medicine", "health literacy", "public health"], part1: "What do you do to stay healthy?", part2: "Describe a healthy habit you would like to develop.", part3: "Why do some people find it difficult to change unhealthy habits?", task1: "The bar chart compares healthcare expenditure per person in six countries in 2000 and 2020.", task2: "Public money should be spent on preventing illness rather than treating people after they become sick. Do you agree or disagree?" },
    { week: 6, speakingTheme: "城市、交通", writingTheme: "城市规划、住房与交通", hints: ["urban planning", "public transport", "affordable housing"], part1: "What do you like about the area where you live?", part2: "Describe a city you would like to visit or live in.", part3: "What is the most effective way to reduce traffic congestion?", task1: "The maps show changes to a town centre before and after a transport redevelopment project.", task2: "Some people think cities should be designed for cars, while others support pedestrian-friendly planning. Discuss both views." },
    { week: 7, speakingTheme: "经济、消费", writingTheme: "消费行为、贫富差距", hints: ["consumer behaviour", "income inequality", "responsible investment"], part1: "Do you prefer to save money or spend it?", part2: "Describe a purchase that was worth the money.", part3: "How can governments reduce the gap between rich and poor?", task1: "The pie charts show how household spending was distributed among six categories in two different years.", task2: "Advertising encourages people to buy things they do not need. Is this a positive or negative development?" },
    { week: 8, speakingTheme: "媒体、社会", writingTheme: "媒体影响、信息可信度", hints: ["public perception", "media coverage", "reliable information"], part1: "What kind of news do you usually follow?", part2: "Describe a news story that attracted your attention.", part3: "How can people decide whether information online is reliable?", task1: "The table gives information about the number of people using four news sources in 2010 and 2020.", task2: "The media has too much influence on how people think. To what extent do you agree or disagree?" },
    { week: 9, speakingTheme: "文化、旅游", writingTheme: "文化保护、全球化", hints: ["cultural heritage", "local identity", "sustainable tourism"], part1: "What kind of cultural events do you enjoy?", part2: "Describe a traditional place or event in your country.", part3: "Should historic buildings be protected even when they limit urban development?", task1: "The line graph shows the number of international visitors to three cultural sites between 2010 and 2020.", task2: "International tourism can damage local culture and the environment. What problems does it cause and how can they be solved?" },
    { week: 10, speakingTheme: "综合复习", writingTheme: "混合题型与完整限时练习", hints: ["a balanced perspective", "evidence-based", "in the long term"], part1: "Which topic have you enjoyed discussing during your English study?", part2: "Describe an issue you would like to understand better.", part3: "When solving a social problem, should policymakers prioritise immediate results or long-term change?", task1: "The chart combines data about education, employment and public spending in a country over a ten-year period.", task2: "Some people believe every major social problem has a technological solution. Discuss this view and give your own opinion." },
  ];

  const practicePlan = {
    speaking: {
      part1: weeklyOutputPlan.map((item) => ({ week: item.week, theme: item.speakingTheme, title: item.part1, body: "请用 20–30 秒自然回答，补充一个具体细节。", hints: item.hints })),
      part2: weeklyOutputPlan.map((item) => ({ week: item.week, theme: item.speakingTheme, title: item.part2, body: "请准备 1 分钟，连续回答 1–2 分钟，覆盖人物、经历、细节和感受。", hints: item.hints })),
      part3: weeklyOutputPlan.map((item) => ({ week: item.week, theme: item.speakingTheme, title: item.part3, body: "请回答 1–2 分钟，先表明观点，再解释原因并给出一个例子或对比。", hints: item.hints })),
    },
    writing: {
      task1: weeklyOutputPlan.map((item) => ({ week: item.week, theme: item.writingTheme, title: item.task1, body: "请用 20 分钟完成 Academic Task 1，概括总体趋势，比较关键数据，不要逐项罗列。建议 150–180 词。", hints: item.hints })),
      task2: weeklyOutputPlan.map((item) => ({ week: item.week, theme: item.writingTheme, title: item.task2, body: "请用 40 分钟完成 Task 2，写出清晰立场、两个主体段和具体例证。建议至少 250 词。", hints: item.hints })),
    },
  };

  const state = {
    questions: [],
    current: 0,
    correct: 0,
    answered: false,
    selectedOption: null,
    results: [],
    config: null,
    practicePromptIndex: { speaking: 0, writing: 0 },
    practiceSelection: { speaking: { type: "part3", week: 1 }, writing: { type: "task2", week: 1 } },
    dailyTraining: { week: 1, day: 1, queue: [], current: 0, correct: 0, wrong: 0, answered: false },
    studyWeek: 1,
    studyDay: 1,
    studyFilter: "all",
  };

  const views = { setup: $("#setupView"), exam: $("#examView"), result: $("#resultView"), speaking: $("#speakingView"), writing: $("#writingView"), study: $("#studyView"), training: $("#trainingView"), stats: $("#statsView") };

  // Speech synthesis is available without a server, but installed voices depend on the browser and OS.
  const speech = window.speechSynthesis || null;
  const SPEECH_RATE = 1;
  let speechVoices = [];
  let activeSpeechButton = null;

  function refreshSpeechVoices() {
    speechVoices = speech ? speech.getVoices() : [];
  }

  if (speech) {
    refreshSpeechVoices();
    speech.addEventListener("voiceschanged", refreshSpeechVoices);
  }

  function voiceForAccent(accent) {
    const locale = accent === "us" ? "en-us" : "en-gb";
    const preferredNames = accent === "us"
      ? [/google us english/i, /microsoft.*(united states|us)/i, /alex/i, /samantha/i]
      : [/google uk english/i, /microsoft.*(united kingdom|uk|great britain)/i, /daniel/i, /serena/i];
    const matchesLocale = (voice) => String(voice.lang || "").toLowerCase().replace(/_/g, "-") === locale;
    const exact = speechVoices.filter(matchesLocale);
    for (const matcher of preferredNames) {
      const match = exact.find((voice) => matcher.test(voice.name));
      if (match) return match;
    }
    return exact[0] || speechVoices.find((voice) => String(voice.lang || "").toLowerCase().startsWith("en-")) || null;
  }

  function hasExactVoice(accent) {
    const locale = accent === "us" ? "en-us" : "en-gb";
    return speechVoices.some((voice) => String(voice.lang || "").toLowerCase().replace(/_/g, "-") === locale);
  }

  function setPronunciationStatus(wordId, message) {
    const escapedId = typeof CSS !== "undefined" && CSS.escape ? CSS.escape(String(wordId)) : String(wordId).replace(/[^a-zA-Z0-9_-]/g, "\\$&");
    $$(`.pronunciation-status[data-word-id="${escapedId}"]`).forEach((element) => {
      element.textContent = message;
    });
  }

  function resetSpeechButton(button) {
    if (!button) return;
    button.dataset.speaking = "false";
    button.setAttribute("aria-pressed", "false");
  }

  function speakWord(wordOrText, accent = "uk", sourceButton = null) {
    const text = typeof wordOrText === "string" ? wordOrText : wordOrText?.term;
    const wordId = typeof wordOrText === "string" ? sourceButton?.dataset.wordId : wordOrText?.id;
    if (!text) return false;
    if (!speech || typeof window.SpeechSynthesisUtterance !== "function") {
      if (wordId) setPronunciationStatus(wordId, "当前浏览器不支持朗读");
      return false;
    }
    refreshSpeechVoices();
    // Cancelling an idle queue can add startup latency in some browsers.
    if (speech.speaking || speech.pending) speech.cancel();
    resetSpeechButton(activeSpeechButton);
    activeSpeechButton = sourceButton;
    if (activeSpeechButton) {
      activeSpeechButton.dataset.speaking = "true";
      activeSpeechButton.setAttribute("aria-pressed", "true");
    }
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = accent === "us" ? "en-US" : "en-GB";
    const voice = voiceForAccent(accent);
    if (voice) utterance.voice = voice;
    if (wordId) setPronunciationStatus(wordId, voice && hasExactVoice(accent) ? (accent === "us" ? "美音朗读中…" : "英音朗读中…") : "未找到指定音色，使用默认英语朗读…");
    utterance.rate = SPEECH_RATE;
    utterance.pitch = 1;
    const finish = () => {
      resetSpeechButton(sourceButton);
      if (activeSpeechButton === sourceButton) activeSpeechButton = null;
      if (wordId) setPronunciationStatus(wordId, "");
    };
    utterance.addEventListener("end", finish);
    utterance.addEventListener("error", () => {
      resetSpeechButton(sourceButton);
      if (activeSpeechButton === sourceButton) activeSpeechButton = null;
      if (wordId) setPronunciationStatus(wordId, "朗读失败，请检查浏览器声音设置");
    });
    speech.speak(utterance);
    return true;
  }

  function pronunciationControls(word) {
    const id = escapeHtml(word.id);
    const term = escapeHtml(word.term);
    return `<div class="pronunciation-controls" data-word-id="${id}" role="group" aria-label="${term} 发音">
      <button class="pronunciation-button" type="button" data-speak-accent="uk" data-word-id="${id}" aria-pressed="false" title="播放英音"><span aria-hidden="true">🔊</span> 英音 <small>UK</small></button>
      <button class="pronunciation-button" type="button" data-speak-accent="us" data-word-id="${id}" aria-pressed="false" title="播放美音"><span aria-hidden="true">🔊</span> 美音 <small>US</small></button>
      <span class="pronunciation-status" data-word-id="${id}" role="status" aria-live="polite"></span>
    </div>`;
  }

  // The study view can reuse these helpers when it renders vocabulary cards.
  window.IELTSVoice = { speak: speakWord, controls: pronunciationControls, supported: () => Boolean(speech && typeof window.SpeechSynthesisUtterance === "function") };

  const viewRoutes = {
    setup: "首页",
    exam: "词汇考试",
    result: "考试结果",
    speaking: "口语练习",
    writing: "写作练习",
    study: "背单词",
    training: "单日输入训练",
    stats: "学习统计",
  };

  function showView(name, { updateUrl = true, route = name } = {}) {
    Object.entries(views).forEach(([key, view]) => view.classList.toggle("active", key === name));
    document.title = `${viewRoutes[name] || "IELTS Vocabulary Lab"} · IELTS Vocabulary Lab`;
    if (updateUrl) {
      const targetHash = name === "setup" ? "" : `#/${route}`;
      if (window.location.hash !== targetHash) window.location.hash = targetHash;
    }
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function routeFromHash() {
    const parts = (window.location.hash.replace(/^#\/?/, "").split("?")[0] || "setup").split("/");
    const route = parts[0];
    if (route === "speaking" || route === "writing") {
      const types = route === "speaking" ? ["part1", "part2", "part3"] : ["task1", "task2"];
      openPractice(route, types.includes(parts[1]) ? parts[1] : types[types.length - 1], { updateUrl: false });
      return;
    }
    if (route === "study" && parts[1] === "training") {
      openTraining({ updateUrl: false });
      return;
    }
    showView(Object.prototype.hasOwnProperty.call(views, route) ? route : "setup", { updateUrl: false });
    if (route === "study") openStudy();
    if (route === "stats") openStats();
  }

  function shuffle(items) {
    const copy = [...items];
    for (let i = copy.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1));
      [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    return copy;
  }

  function normalise(value) {
    return String(value || "")
      .toLowerCase()
      .replace(/[’'`]/g, "")
      .replace(/[–—-]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  function compact(value) {
    return normalise(value).replace(/[^a-z0-9]/g, "");
  }

  function levenshtein(a, b) {
    const previous = Array.from({ length: b.length + 1 }, (_, index) => index);
    for (let i = 1; i <= a.length; i += 1) {
      const current = [i];
      for (let j = 1; j <= b.length; j += 1) {
        current[j] = Math.min(
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
        );
      }
      for (let j = 0; j <= b.length; j += 1) previous[j] = current[j];
    }
    return previous[b.length];
  }

  function loadProgress() {
    return db.getProgressMap();
  }

  function saveProgress(progress) {
    db.saveProgressMap(progress);
  }

  function getWordProgress(id) {
    return loadProgress()[id] || { attempts: 0, correct: 0, wrong: 0, streak: 0, level: 0, lastReviewedAt: null, nextReviewAt: null, history: [] };
  }

  function addDays(date, days) {
    const next = new Date(date);
    next.setDate(next.getDate() + days);
    return next.toISOString();
  }

  function updateWordProgress(word, correct, type, answer) {
    const progress = loadProgress();
    const existing = progress[word.id] || { attempts: 0, correct: 0, wrong: 0, streak: 0, level: 0, lastReviewedAt: null, nextReviewAt: null, history: [] };
    const now = new Date();
    existing.attempts += 1;
    existing.correct += correct ? 1 : 0;
    existing.wrong += correct ? 0 : 1;
    existing.streak = correct ? existing.streak + 1 : 0;
    existing.level = correct ? Math.min(existing.level + 1, 5) : Math.max(existing.level - 1, 0);
    existing.lastReviewedAt = now.toISOString();
    const intervals = [1, 3, 7, 14, 30];
    const intervalIndex = Math.min(Math.max(existing.level - 1, 0), intervals.length - 1);
    existing.nextReviewAt = addDays(now, correct ? intervals[intervalIndex] : 1);
    existing.history = [...(existing.history || []), { type, correct, answer, at: now.toISOString() }].slice(-30);
    progress[word.id] = existing;
    saveProgress(progress);
  }

  function isDue(word, now = new Date()) {
    const record = getWordProgress(word.id);
    return !record.nextReviewAt || new Date(record.nextReviewAt) <= now;
  }

  function priorityForWord(word) {
    const record = getWordProgress(word.id);
    let score = 0;
    if (isDue(word)) score += 100;
    score += Math.max(0, 25 - record.level * 5);
    score += Math.min(record.wrong || 0, 10) * 4;
    if (record.lastReviewedAt) score += Math.max(0, 12 - Math.floor((Date.now() - new Date(record.lastReviewedAt).getTime()) / 86400000));
    return score;
  }

  function prioritizedPool(pool) {
    return pool
      .map((word) => ({ word, score: priorityForWord(word), tie: Math.random() }))
      .sort((a, b) => b.score - a.score || a.tie - b.tie)
      .map(({ word }) => word);
  }

  function getSelectedTypes() {
    return $$('input[name="questionType"]:checked').map((input) => input.value);
  }

  function optionPool(target, field, count = 3) {
    return shuffle(words.filter((word) => word.id !== target.id && word[field])).slice(0, count).map((word) => word[field]);
  }

  function buildQuestion(word, type) {
    if (type === "meaning") {
      return { word, type, prompt: "这个词最接近以下哪个中文意思？", options: shuffle([word.meaningZh, ...optionPool(word, "meaningZh")]), answer: word.meaningZh };
    }
    if (type === "reverse") {
      return { word, type, prompt: "选择与这个中文意思对应的英文词汇。", options: shuffle([word.term, ...optionPool(word, "term")]), answer: word.term };
    }
    if (type === "spell") {
      return { word, type, prompt: "根据释义拼写这个词或词组。", answer: word.term };
    }
    return { word, type, prompt: "根据句意输入被遮住的目标词。", answer: word.term };
  }

  function chooseTypes(count) {
    const types = getSelectedTypes();
    const result = [];
    for (let i = 0; i < count; i += 1) result.push(types[i % types.length]);
    return shuffle(result);
  }

  function createQuestions(config, sourceWords = null) {
    const pool = sourceWords || words.filter((word) => word.week >= config.from && word.week <= config.to);
    const count = config.count === "all" ? pool.length : Math.min(Number(config.count), pool.length);
    const questionTypes = chooseTypes(count);
    return prioritizedPool(pool).slice(0, count).map((word, index) => buildQuestion(word, questionTypes[index]));
  }

  function typeLabel(type) {
    return { meaning: "词义识别", reverse: "主动回忆", spell: "拼写输出", cloze: "语境填空" }[type] || type;
  }

  function renderQuestion() {
    const question = state.questions[state.current];
    if (!question) return finishExam();
    state.answered = false;
    state.selectedOption = null;
    const { word, type } = question;
    $("#progressLabel").textContent = `第 ${state.current + 1} / ${state.questions.length} 题`;
    const percentage = Math.round((state.current / state.questions.length) * 100);
    $("#progressPercent").textContent = `${percentage}%`;
    $("#progressBar").style.width = `${percentage}%`;
    $("#liveScore").textContent = `${state.correct}`;
    $("#questionTypeLabel").textContent = typeLabel(type);
    $("#questionSource").textContent = `Week ${word.week} · Day ${word.day} · ${word.dayTitle}`;
    $("#feedback").innerHTML = "";
    $("#submitAnswer").classList.remove("hidden");
    $("#nextQuestion").classList.add("hidden");

    const content = $("#questionContent");
    const area = $("#answerArea");
    content.innerHTML = "";
    area.innerHTML = "";
    if (type === "meaning") {
      content.innerHTML = `<p class="question-heading">${question.prompt}</p><p class="question-term">${escapeHtml(word.term)}</p>${pronunciationControls(word)}<p class="question-ipa">${escapeHtml(word.ipa)} · ${escapeHtml(word.partOfSpeech)}</p>`;
      area.innerHTML = `<div class="options-grid">${question.options.map((option, index) => `<button class="option-button" data-option-index="${index}" type="button"><span class="option-letter">${String.fromCharCode(65 + index)}</span>${escapeHtml(option)}</button>`).join("")}</div>`;
      $$(".option-button").forEach((button) => button.addEventListener("click", () => selectOption(button)));
    } else if (type === "reverse") {
      content.innerHTML = `<p class="question-heading">${question.prompt}</p><p class="question-term question-term-small">${escapeHtml(word.meaningZh)}</p>${pronunciationControls(word)}`;
      area.innerHTML = `<div class="options-grid">${question.options.map((option, index) => `<button class="option-button" data-option-index="${index}" type="button"><span class="option-letter">${String.fromCharCode(65 + index)}</span>${escapeHtml(option)}</button>`).join("")}</div>`;
      $$(".option-button").forEach((button) => button.addEventListener("click", () => selectOption(button)));
    } else if (type === "spell") {
      content.innerHTML = `<p class="question-heading">${question.prompt}</p><p class="question-term question-term-small">${escapeHtml(word.meaningZh)}</p>${pronunciationControls(word)}<p class="question-ipa">${escapeHtml(word.ipa)} · ${escapeHtml(word.partOfSpeech)}</p>`;
      area.innerHTML = inputTemplate("请输入英文词或词组");
    } else {
      content.innerHTML = `<p class="question-heading">${question.prompt}</p><p class="sentence-prompt">${escapeHtml(word.maskedExample)}</p><p class="question-meaning">中文提示：${escapeHtml(word.exampleZh)}</p>${pronunciationControls(word)}`;
      area.innerHTML = inputTemplate("请根据语境输入目标词");
    }
  }

  function inputTemplate(placeholder) {
    return `<label class="answer-label" for="typedAnswer">你的答案</label><input id="typedAnswer" class="text-input" type="text" autocomplete="off" placeholder="${placeholder}" />`;
  }

  function selectOption(button) {
    if (state.answered) return;
    $$(".option-button").forEach((item) => item.classList.remove("selected"));
    button.classList.add("selected");
    state.selectedOption = Number(button.dataset.optionIndex);
  }

  function getAnswer() {
    const question = state.questions[state.current];
    if (["meaning", "reverse"].includes(question.type)) {
      if (state.selectedOption === null) return "";
      return question.options[state.selectedOption];
    }
    return $("#typedAnswer")?.value.trim() || "";
  }

  function isCorrect(question, answer) {
    const exact = normalise(answer) === normalise(question.answer);
    if (exact || question.type !== "spell") return exact;
    const given = compact(answer);
    const expected = compact(question.answer);
    if (!given || !expected) return false;
    if (given === expected) return true;
    const variants = {
      analyse: "analyze", analysed: "analyzed", analysing: "analyzing",
      organisation: "organization", organisations: "organizations", organisational: "organizational",
      behaviour: "behavior", behaviours: "behaviors", behavioural: "behavioral",
      colour: "color", colours: "colors", favour: "favor", favourite: "favorite", labour: "labor",
      centre: "center", centres: "centers", programme: "program", programmes: "programs",
      practise: "practice", practised: "practiced", practising: "practicing", licence: "license",
      defence: "defense", emphasise: "emphasize", emphasised: "emphasized", realise: "realize",
      specialised: "specialized", specialise: "specialize", prioritise: "prioritize",
      travelling: "traveling", counselling: "counseling", modelling: "modeling", focussed: "focused",
    };
    if (variants[given] === expected || variants[expected] === given) return true;
    return expected.length >= 6 && Math.abs(given.length - expected.length) <= 1 && levenshtein(given, expected) <= 1;
  }

  function submitAnswer() {
    if (state.answered) return;
    const question = state.questions[state.current];
    const answer = getAnswer();
    if (!answer) {
      $("#feedback").innerHTML = `<div class="feedback-box wrong"><div class="feedback-title">先作答再提交</div><p>选择一个选项，或在输入框中写下你的答案。</p></div>`;
      return;
    }
    state.answered = true;
    const correct = isCorrect(question, answer);
    if (correct) state.correct += 1;
    state.results.push({ question, answer, correct });
    updateWordProgress(question.word, correct, question.type, answer);
    $("#liveScore").textContent = `${state.correct}`;
    const boxClass = correct ? "feedback-box" : "feedback-box wrong";
    const title = correct ? "回答正确" : "再巩固一次";
    const answerLine = correct ? "" : `<p>正确答案：<strong>${escapeHtml(question.answer)}</strong></p>`;
    $("#feedback").innerHTML = `<div class="${boxClass}"><div class="feedback-title">${title}</div>${answerLine}${pronunciationControls(question.word)}<p><strong>搭配：</strong>${escapeHtml(question.word.collocations.join(" · "))}</p><p><strong>例句：</strong>${escapeHtml(question.word.exampleEn)}</p><p><strong>译文：</strong>${escapeHtml(question.word.exampleZh)}</p><p><strong>提醒：</strong>${escapeHtml(question.word.note)}</p></div>`;
    $("#submitAnswer").classList.add("hidden");
    $("#nextQuestion").classList.remove("hidden");
  }

  function finishExam() {
    const total = state.questions.length;
    const score = total ? Math.round((state.correct / total) * 100) : 0;
    const record = { score, total, correct: state.correct, results: state.results.map((item) => ({ id: item.question.word.id, type: item.question.type, correct: item.correct })), config: state.config, createdAt: new Date().toISOString() };
    saveRecord(record);
    $("#progressBar").style.width = "100%";
    $("#resultScore").textContent = `${score}%`;
    $("#resultSubtitle").textContent = `本轮答对 ${state.correct} / ${total} 题。${score >= 80 ? "状态很好，可以继续扩大范围。" : "建议先复习错题，再进行下一轮。"}`;
    const breakdown = {};
    state.results.forEach(({ question, correct }) => {
      breakdown[question.type] ||= { total: 0, correct: 0 };
      breakdown[question.type].total += 1;
      if (correct) breakdown[question.type].correct += 1;
    });
    $("#typeBreakdown").innerHTML = Object.entries(breakdown).map(([type, result]) => {
      const pct = Math.round((result.correct / result.total) * 100);
      return `<div class="breakdown-row"><span>${typeLabel(type)}</span><div class="breakdown-track"><div class="breakdown-fill" style="width:${pct}%"></div></div><b>${pct}%</b></div>`;
    }).join("");
    const wrong = state.results.filter((item) => !item.correct);
    $("#wrongCount").textContent = `${wrong.length} 个`;
    $("#wrongWords").innerHTML = wrong.length ? wrong.map(({ question }) => `<div class="wrong-word"><div><strong>${escapeHtml(question.word.term)}</strong><span>${escapeHtml(question.word.meaningZh)} · ${typeLabel(question.type)}</span></div><code>${escapeHtml(question.word.ipa)}</code></div>`).join("") : `<p class="empty-state">全部答对了。可以扩大周范围或选择更长题目。</p>`;
    $("#retryWrong").classList.toggle("hidden", wrong.length === 0);
    renderReviewSummary();
    showView("result");
  }

  function startExam(sourceWords = null) {
    const from = Number($("#weekFrom").value);
    const to = Number($("#weekTo").value);
    const types = getSelectedTypes();
    $("#setupHint").textContent = "";
    if (from > to) { $("#setupHint").textContent = "结束周需要大于或等于起始周。"; return; }
    if (!types.length) { $("#setupHint").textContent = "请至少选择一种题型。"; return; }
    const config = { from, to, count: $("#questionCount").value, types };
    const questions = createQuestions(config, sourceWords);
    if (!questions.length) { $("#setupHint").textContent = "没有找到可用词汇，请调整范围。"; return; }
    state.questions = questions; state.current = 0; state.correct = 0; state.answered = false; state.selectedOption = null; state.results = []; state.config = config;
    showView("exam"); renderQuestion();
  }

  function retryWrong() {
    const wrongIds = new Set(state.results.filter((item) => !item.correct).map((item) => item.question.word.id));
    const wrongWords = words.filter((word) => wrongIds.has(word.id));
    if (wrongWords.length) startExam(wrongWords);
  }

  function saveRecord(record) {
    db.addExamRecord(record);
    renderHistory();
    renderStats();
  }

  function loadRecords() {
    return db.getExamRecords();
  }

  function renderHistory() {
    const records = loadRecords();
    const attempts = records.reduce((sum, record) => sum + record.total, 0);
    const best = records.length ? Math.max(...records.map((record) => record.score)) : null;
    const due = words.filter((word) => isDue(word)).length;
    const mastered = Object.values(loadProgress()).filter((item) => item.level >= 4).length;
    $("#historySummary").textContent = records.length ? `最近一次 ${records[0].score}% · ${new Date(records[0].createdAt).toLocaleDateString("zh-CN")}` : "还没有考试记录";
    $("#dueCount").textContent = due;
    $("#masteredCount").textContent = mastered;
    $("#attemptCount").textContent = attempts;
    $("#bestScore").textContent = best === null ? "—" : `${best}%`;
  }

  function renderStats() {
    const progress = loadProgress();
    const records = loadRecords();
    const practiceRecords = loadPracticeRecords();
    const now = new Date();
    const reviewedWords = words.filter((word) => progress[word.id]?.lastReviewedAt);
    const masteredWords = reviewedWords.filter((word) => Number(progress[word.id]?.level) >= 4);
    const dueWords = words.filter((word) => !progress[word.id]?.nextReviewAt || new Date(progress[word.id].nextReviewAt) <= now);
    const newWords = words.length - reviewedWords.length;
    const averageScore = records.length ? Math.round(records.reduce((sum, record) => sum + Number(record.score || 0), 0) / records.length) : null;
    const bestScore = records.length ? Math.max(...records.map((record) => Number(record.score || 0))) : null;
    const answerCount = records.reduce((sum, record) => sum + Number(record.total || 0), 0);
    const speakingCount = practiceRecords.filter((record) => record.mode === "speaking").length;
    const writingCount = practiceRecords.filter((record) => record.mode === "writing").length;
    const ratedPractice = practiceRecords.filter((record) => Number.isFinite(Number(record.rating)));
    const averageRating = ratedPractice.length ? (ratedPractice.reduce((sum, record) => sum + Number(record.rating), 0) / ratedPractice.length).toFixed(1) : null;

    const setText = (id, value) => { const element = $(id); if (element) element.textContent = value; };
    setText("#statsTotalWords", words.length);
    setText("#statsStudiedWords", reviewedWords.length);
    setText("#statsStudiedHint", `${words.length ? Math.round((reviewedWords.length / words.length) * 100) : 0}% 已有记录`);
    setText("#statsMasteredWords", masteredWords.length);
    setText("#statsMasteredHint", `${reviewedWords.length ? Math.round((masteredWords.length / reviewedWords.length) * 100) : 0}% 的已学习词`);
    setText("#statsDueWords", dueWords.length);
    setText("#statsNewWords", `${newWords} 个尚未学习`);
    setText("#statsExamCount", `${records.length} 次`);
    setText("#statsAverageScore", averageScore === null ? "—" : `${averageScore}%`);
    setText("#statsBestScore", bestScore === null ? "—" : `${bestScore}%`);
    setText("#statsAnswerCount", answerCount);
    setText("#statsPracticeCount", `${practiceRecords.length} 次`);
    setText("#statsSpeakingCount", speakingCount);
    setText("#statsWritingCount", writingCount);
    setText("#statsPracticeRating", averageRating === null ? "—" : `${averageRating}/5`);
    const practiceHint = $("#statsPracticeHint");
    if (practiceHint) practiceHint.textContent = practiceRecords.length ? `最近一次练习：${new Date(practiceRecords[0].createdAt).toLocaleDateString("zh-CN")} · 平均自评分 ${averageRating || "—"}/5` : "保存一次回答后，这里会显示你的输出练习节奏。";

    const recentExams = $("#statsRecentExams");
    if (recentExams) recentExams.innerHTML = records.length
      ? records.slice(0, 5).map((record) => `<div class="stats-recent-item"><span>${new Date(record.createdAt).toLocaleDateString("zh-CN")} · ${record.total || 0} 题</span><strong>${Number(record.score || 0)}%</strong></div>`).join("")
      : `<p class="stats-muted">完成一次考试后，这里会显示最近成绩。</p>`;

    const weekProgress = $("#statsWeekProgress");
    if (!weekProgress) return;
    const weeks = [...new Set(words.map((word) => word.week))].sort((a, b) => a - b);
    weekProgress.innerHTML = weeks.length ? weeks.map((week) => {
      const weekWords = words.filter((word) => word.week === week);
      const studied = weekWords.filter((word) => progress[word.id]?.lastReviewedAt).length;
      const mastered = weekWords.filter((word) => Number(progress[word.id]?.level) >= 4).length;
      const percent = weekWords.length ? Math.round((studied / weekWords.length) * 100) : 0;
      return `<div class="stats-week-row"><div class="stats-week-label"><strong>Week ${week}</strong><span>${weekWords.length} 个词</span></div><div class="stats-week-track" role="progressbar" aria-label="Week ${week} 学习进度" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${percent}"><div class="stats-week-fill" style="width:${percent}%"></div></div><div class="stats-week-meta"><strong>${percent}%</strong> 已学习 · ${mastered} 个稳定掌握</div></div>`;
    }).join("") : `<p class="stats-muted">当前词库还没有 Week 数据。</p>`;
  }

  function renderReviewSummary() {
    const progress = loadProgress();
    const due = words.filter((word) => isDue(word)).length;
    const reviewed = Object.keys(progress).length;
    const mastered = Object.values(progress).filter((item) => item.level >= 4).length;
    const next = words
      .map((word) => ({ word, progress: getWordProgress(word.id) }))
      .filter(({ progress: item }) => item.nextReviewAt && new Date(item.nextReviewAt) > new Date())
      .sort((a, b) => new Date(a.progress.nextReviewAt) - new Date(b.progress.nextReviewAt))[0];
    $("#reviewSummary").innerHTML = `<strong>复习计划</strong><span>已记录 ${reviewed} 个词 · ${due} 个今天到期 · ${mastered} 个达到稳定掌握。</span>${next ? `<span>下一个复习：${escapeHtml(next.word.term)} · ${new Date(next.progress.nextReviewAt).toLocaleDateString("zh-CN")}</span>` : ""}`;
  }

  function loadPracticeRecords() {
    return db.getPracticeRecords();
  }

  function practiceIds(mode) {
    const prefix = mode === "speaking" ? "speaking" : "writing";
    return {
      response: `#${prefix}Response`, rating: `#${prefix}Rating`, hint: `#${prefix}Hint`,
      wordCount: `#${prefix}WordCount`, promptTitle: `#${prefix}PromptTitle`,
      promptBody: `#${prefix}PromptBody`, promptType: `#${prefix}PromptType`,
      promptWeek: `#${prefix}PromptWeek`, hints: `#${prefix}Hints`, week: `#${prefix}Week`, type: `#${prefix}Type`,
      history: `#${prefix}History`, count: `#${prefix}Count`,
    };
  }

  function selectedPracticePrompts(mode) {
    const selection = state.practiceSelection[mode];
    return practicePlan[mode][selection.type] || practicePlan[mode][mode === "speaking" ? "part3" : "task2"];
  }

  function savePracticeRecord(mode) {
    const ids = practiceIds(mode);
    const response = $(ids.response).value.trim();
    if (!response) {
      $(ids.hint).textContent = "请先写下回答，再保存练习。";
      return;
    }
    const prompts = selectedPracticePrompts(mode);
    const weekPrompts = prompts.filter((item) => item.week === Number(state.practiceSelection[mode].week));
    const prompt = weekPrompts[state.practicePromptIndex[mode] % weekPrompts.length] || prompts[0];
    db.addPracticeRecord({ mode, prompt: prompt.title, response, rating: Number($(ids.rating).value), createdAt: new Date().toISOString() });
    $(ids.hint).textContent = "已保存到本机。可以换一个题目继续练习。";
    $(ids.response).value = "";
    updatePracticeWordCount(mode);
    renderPracticeHistory(mode);
    renderStats();
  }

  function renderPracticeHistory(mode) {
    const ids = practiceIds(mode);
    const records = loadPracticeRecords();
    const filtered = records.filter((record) => record.mode === mode);
    $(ids.count).textContent = `${filtered.length} 次`;
    $(ids.history).innerHTML = filtered.length ? filtered.slice(0, 12).map((record) => `<div class="practice-history-item"><strong>${mode === "speaking" ? "口语 Part 3" : "Task 2 写作"} · ${record.rating}/5</strong><p>${escapeHtml(record.response)}</p><small>${new Date(record.createdAt).toLocaleDateString("zh-CN")}</small></div>`).join("") : `<p class="empty-state">还没有${mode === "speaking" ? "口语" : "写作"}练习记录。先完成一次回答吧。</p>`;
  }

  function updatePracticeWordCount(mode) {
    const ids = practiceIds(mode);
    const value = $(ids.response).value.trim();
    const count = value ? value.split(/\s+/).filter(Boolean).length : 0;
    $(ids.wordCount).textContent = `${count} 词`;
  }

  function renderPracticePrompt(mode) {
    const ids = practiceIds(mode);
    const prompts = selectedPracticePrompts(mode);
    const weekPrompts = prompts.filter((item) => item.week === Number(state.practiceSelection[mode].week));
    const prompt = weekPrompts[state.practicePromptIndex[mode] % weekPrompts.length] || prompts[0];
    const type = state.practiceSelection[mode].type;
    const typeLabel = mode === "speaking" ? { part1: "口语 Part 1", part2: "口语 Part 2", part3: "口语 Part 3" }[type] : { task1: "Writing Task 1", task2: "Writing Task 2" }[type];
    $(ids.promptType).textContent = typeLabel;
    $(ids.promptWeek).textContent = `Week ${prompt.week} · ${prompt.theme}`;
    $(ids.promptTitle).textContent = prompt.title;
    $(ids.promptBody).textContent = prompt.body;
    $(ids.hints).innerHTML = prompt.hints.map((hint) => `<span>${escapeHtml(hint)}</span>`).join("");
  }

  function populatePracticeControls(mode) {
    const ids = practiceIds(mode);
    const typeOptions = mode === "speaking"
      ? [["part1", "Part 1 日常问答"], ["part2", "Part 2 个人陈述"], ["part3", "Part 3 深入讨论"]]
      : [["task1", "Task 1 图表写作"], ["task2", "Task 2 议论文"]];
    $(ids.type).innerHTML = typeOptions.map(([value, label]) => `<option value="${value}">${label}</option>`).join("");
    $(ids.type).value = state.practiceSelection[mode].type;
    $(ids.week).innerHTML = weeklyOutputPlan.map((item) => `<option value="${item.week}">Week ${item.week} · ${item[mode === "speaking" ? "speakingTheme" : "writingTheme"]}</option>`).join("");
    $(ids.week).value = String(state.practiceSelection[mode].week);
  }

  function openPractice(mode = "speaking", type = null, { updateUrl = true } = {}) {
    if (type) state.practiceSelection[mode].type = type;
    populatePracticeControls(mode);
    const ids = practiceIds(mode);
    $(ids.hint).textContent = "";
    renderPracticePrompt(mode);
    renderPracticeHistory(mode);
    showView(mode, { updateUrl, route: `${mode}/${state.practiceSelection[mode].type}` });
  }

  function studyRecord(word) {
    return getWordProgress(word.id);
  }

  function studyStatus(record) {
    if (record.level >= 4) return { label: "已稳定掌握", className: "mastered" };
    if (record.attempts === 0 && !record.lastReviewedAt) return { label: "尚未学习", className: "new" };
    if (record.nextReviewAt && new Date(record.nextReviewAt) <= new Date()) return { label: "今天待复习", className: "due" };
    return { label: "需要巩固", className: "needs" };
  }

  function updateStudyLevel(word, level, source = "study") {
    const progress = loadProgress();
    const existing = progress[word.id] || { attempts: 0, correct: 0, wrong: 0, streak: 0, level: 0, lastReviewedAt: null, nextReviewAt: null, history: [] };
    const now = new Date();
    const nextLevel = Math.max(0, Math.min(5, Number(level) || 0));
    const intervals = [1, 1, 3, 7, 14, 30];
    existing.level = nextLevel;
    existing.lastReviewedAt = now.toISOString();
    existing.nextReviewAt = addDays(now, intervals[nextLevel]);
    existing.history = [...(existing.history || []), { type: source, level: nextLevel, at: now.toISOString() }].slice(-30);
    progress[word.id] = existing;
    saveProgress(progress);
    renderHistory();
    renderStudyWords();
  }

  function scheduleStudyReview(word) {
    const progress = loadProgress();
    const existing = progress[word.id] || { attempts: 0, correct: 0, wrong: 0, streak: 0, level: 0, lastReviewedAt: null, nextReviewAt: null, history: [] };
    const now = new Date();
    existing.lastReviewedAt = now.toISOString();
    existing.nextReviewAt = addDays(now, 1);
    existing.history = [...(existing.history || []), { type: "study-review", at: now.toISOString() }].slice(-30);
    progress[word.id] = existing;
    saveProgress(progress);
    renderHistory();
    renderStudyWords();
  }

  function studyWordsForSelection() {
    const week = Number($("#studyWeek").value || state.studyWeek);
    const day = $("#studyDay").value || state.studyDay;
    const filter = $("#studyFilter").value || state.studyFilter;
    state.studyWeek = week;
    state.studyDay = day;
    state.studyFilter = filter;
    let pool = words.filter((word) => word.week === week && (day === "all" || word.day === Number(day)));
    if (filter !== "all") {
      pool = pool.filter((word) => {
        const record = studyRecord(word);
        if (filter === "new") return record.attempts === 0 && !record.lastReviewedAt;
        if (filter === "due") return isDue(word);
        if (filter === "needs") return record.level < 4;
        if (filter === "mastered") return record.level >= 4;
        return true;
      });
    }
    return pool;
  }

  function renderStudyWords() {
    const container = $("#studyWords");
    if (!container || !$("#studyWeek")) return;
    const pool = studyWordsForSelection();
    const week = Number($("#studyWeek").value || state.studyWeek);
    const day = $("#studyDay").value || state.studyDay;
    const label = day === "all" ? `Week ${week} · 全部词汇` : `Week ${week} · Day ${day}`;
    const dueCount = pool.filter((word) => isDue(word)).length;
    $("#studyProgressSummary").textContent = `${label} · ${pool.length} 个词`;
    $("#studyProgressHint").textContent = pool.length ? `${dueCount} 个词今天到期；看完后可直接调整熟练度。` : "当前筛选下没有词汇。可以切换筛选条件。";
    if (!pool.length) {
      container.innerHTML = `<div class="panel study-empty"><strong>没有匹配的词汇</strong><p>换一个学习日或显示条件，继续复习。</p></div>`;
      return;
    }
    container.innerHTML = pool.map((word) => {
      const record = studyRecord(word);
      const status = studyStatus(record);
      const nextReview = record.nextReviewAt ? new Date(record.nextReviewAt).toLocaleDateString("zh-CN") : "尚未安排";
      const levelOptions = [0, 1, 2, 3, 4, 5].map((level) => `<option value="${level}" ${level === record.level ? "selected" : ""}>${level} / 5</option>`).join("");
      return `<article class="study-card panel" data-word-id="${escapeHtml(word.id)}">
        <div class="study-card-head"><div><span class="study-day-label">Day ${word.day} · ${escapeHtml(word.dayTitle)}</span><h3>${escapeHtml(word.term)}</h3><p class="study-pronunciation">${escapeHtml(word.ipa)} <span>·</span> ${escapeHtml(word.partOfSpeech)}</p>${pronunciationControls(word)}</div><span class="study-status ${status.className}">${status.label}</span></div>
        <div class="study-meaning"><strong>${escapeHtml(word.meaningZh)}</strong><span>下次复习：${escapeHtml(nextReview)}</span></div>
        <div class="study-detail-grid"><div><small>常用搭配</small><p>${escapeHtml(word.collocations.join(" · "))}</p></div><div><small>词族</small><p>${escapeHtml(word.wordFamily || "暂无")}</p></div></div>
        <div class="study-example"><small>例句</small><p>${escapeHtml(word.exampleEn)}</p><p class="study-example-zh">${escapeHtml(word.exampleZh)}</p></div>
        <div class="study-note"><strong>使用提醒</strong><span>${escapeHtml(word.note || "")}</span></div>
        <div class="study-card-actions"><label>熟练度 <select class="study-level" aria-label="${escapeHtml(word.term)} 熟练度">${levelOptions}</select></label><button class="study-action-button" data-study-action="mastered" type="button">标记已会</button><button class="study-action-button subtle" data-study-action="review" type="button">安排复习</button></div>
      </article>`;
    }).join("");
  }

  function renderStudyDays() {
    const week = Number($("#studyWeek").value || state.studyWeek);
    const days = [...new Set(words.filter((word) => word.week === week).map((word) => word.day))].sort((a, b) => a - b);
    const select = $("#studyDay");
    const previous = state.studyDay;
    select.innerHTML = `<option value="all">整周（${days.length} 天）</option>${days.map((day) => {
      const title = words.find((word) => word.week === week && word.day === day)?.dayTitle || "";
      return `<option value="${day}">Day ${day} · ${escapeHtml(title)}</option>`;
    }).join("")}`;
    select.value = days.includes(Number(previous)) ? String(previous) : "all";
    state.studyDay = select.value;
  }

  function populateStudyOptions(weeks) {
    const select = $("#studyWeek");
    if (!select || !weeks.length) return;
    select.innerHTML = weeks.map((week) => `<option value="${week}">Week ${week}</option>`).join("");
    select.value = String(weeks[0]);
    state.studyWeek = weeks[0];
    renderStudyDays();
  }

  function openStudy() {
    const weeks = [...new Set(words.map((word) => word.week))].sort((a, b) => a - b);
    const select = $("#studyWeek");
    if (!select.options.length) populateStudyOptions(weeks);
    renderStudyDays();
    renderStudyWords();
    showView("study");
  }

  function trainingWeeks() {
    return [...new Set(words.map((word) => word.week))].sort((a, b) => a - b);
  }

  function renderTrainingDays() {
    const week = Number($("#trainingWeek").value || state.dailyTraining.week);
    const days = [...new Set(words.filter((word) => word.week === week).map((word) => word.day))].sort((a, b) => a - b);
    const daySelect = $("#trainingDay");
    daySelect.innerHTML = days.map((day) => {
      const title = words.find((word) => word.week === week && word.day === day)?.dayTitle || "";
      return `<option value="${day}">Day ${day} · ${escapeHtml(title)}</option>`;
    }).join("");
    const preferred = days.includes(Number(state.dailyTraining.day)) ? Number(state.dailyTraining.day) : days[0];
    daySelect.value = String(preferred || "");
    state.dailyTraining.week = week;
    state.dailyTraining.day = Number(daySelect.value || days[0]);
  }

  function persistDailyTraining() {
    const training = state.dailyTraining;
    if (!training?.queue?.length) return;
    const snapshot = {
      version: 1,
      week: training.week,
      day: training.day,
      current: training.current,
      correct: training.correct,
      wrong: training.wrong,
      answered: training.answered,
      queue: training.queue.map((item) => ({
        wordId: item.word.id,
        retry: Boolean(item.retry),
        answered: Boolean(item.answered),
        answer: item.answer || "",
        draft: item.draft || "",
        correct: item.correct ?? null,
        feedbackHtml: item.feedbackHtml || "",
      })),
    };
    try { localStorage.setItem(DAILY_TRAINING_STORAGE_KEY, JSON.stringify(snapshot)); } catch {}
  }

  function restoreDailyTraining() {
    let snapshot;
    try {
      snapshot = JSON.parse(localStorage.getItem(DAILY_TRAINING_STORAGE_KEY) || "");
    } catch {
      return false;
    }
    if (!snapshot || snapshot.version !== 1 || !Array.isArray(snapshot.queue)) return false;
    const queue = snapshot.queue.map((item) => {
      const word = words.find((candidate) => candidate.id === item.wordId);
      if (!word) return null;
      return {
        word,
        retry: Boolean(item.retry),
        answered: Boolean(item.answered),
        answer: String(item.answer || ""),
        draft: String(item.draft || ""),
        correct: typeof item.correct === "boolean" ? item.correct : null,
        feedbackHtml: String(item.feedbackHtml || ""),
      };
    }).filter(Boolean);
    const current = Number(snapshot.current);
    if (!queue.length || !Number.isInteger(current) || current < 0 || current > queue.length) return false;
    state.dailyTraining = {
      week: Number(snapshot.week) || 1,
      day: Number(snapshot.day) || 1,
      queue,
      current,
      correct: Number(snapshot.correct) || 0,
      wrong: Number(snapshot.wrong) || 0,
      answered: Boolean(snapshot.answered),
    };
    return true;
  }

  function populateTrainingOptions() {
    const weekSelect = $("#trainingWeek");
    weekSelect.innerHTML = trainingWeeks().map((week) => `<option value="${week}">Week ${week}</option>`).join("");
    weekSelect.value = String(state.dailyTraining.week);
    renderTrainingDays();
  }

  function startDailyTraining() {
    const week = Number($("#trainingWeek").value);
    const day = Number($("#trainingDay").value);
    const dayWords = words.filter((word) => word.week === week && word.day === day);
    state.dailyTraining = { week, day, queue: dayWords.map((word) => ({ word, retry: false, answered: false })), current: 0, correct: 0, wrong: 0, answered: false };
    $("#trainingSummary").textContent = `Week ${week} · Day ${day} 共 ${dayWords.length} 个词，答错词会在本轮末尾再出现。`;
    renderDailyTraining();
    persistDailyTraining();
  }

  function renderDailyTraining() {
    const training = state.dailyTraining;
    const item = training.queue[training.current];
    $("#trainingSummary").textContent = `Week ${training.week} · Day ${training.day} 共 ${training.queue.length} 个词，答错词会在本轮末尾再出现。`;
    $("#trainingFeedback").innerHTML = "";
    training.answered = Boolean(item?.answered);
    $("#submitTraining").classList.toggle("hidden", !item || training.answered);
    $("#nextTraining").classList.toggle("hidden", !item || !training.answered);
    if (!item) {
      $("#trainingProgress").textContent = `本日训练完成 · 首次答错 ${training.wrong} 个`;
      $("#trainingPrompt").innerHTML = `<div class="training-complete"><strong>今日训练完成</strong><p>共完成 ${training.queue.length} 次作答，正确 ${training.correct} 次。${training.wrong ? "重复出现的错词已经在本轮末尾处理。" : "本轮没有错词。"}</p><button id="restartTraining" class="secondary-button" type="button">再练一次</button></div>`;
      $("#trainingAnswerArea").innerHTML = "";
      $("#nextTraining").classList.add("hidden");
      $("#submitTraining").classList.add("hidden");
      $("#restartTraining").addEventListener("click", startDailyTraining);
      return;
    }
    const word = item.word;
    $("#trainingProgress").textContent = `Week ${training.week} · Day ${training.day} · 第 ${training.current + 1} / ${training.queue.length} 题${item.retry ? " · 错题重做" : ""}`;
    $("#trainingPrompt").innerHTML = `<div class="training-prompt"><span class="eyebrow accent">中文释义与语境提示</span><div class="training-meaning">${escapeHtml(word.meaningZh)}</div><div class="training-example"><small>例句</small><p>${escapeHtml(word.maskedExample)}</p><p class="training-example-zh">${escapeHtml(word.exampleZh)}</p></div></div>`;
    $("#trainingAnswerArea").innerHTML = `<div class="training-answer"><label class="answer-label" for="trainingInput">输入英文单词或词组</label><input id="trainingInput" class="text-input" type="text" autocomplete="off" placeholder="输入答案后按 Enter 提交" /></div>`;
    if (item.answer || item.draft) $("#trainingInput").value = item.answer || item.draft;
    if (item.feedbackHtml) $("#trainingFeedback").innerHTML = item.feedbackHtml;
    if (!item.answered) $("#trainingInput").focus();
    $("#trainingInput").addEventListener("input", () => {
      item.draft = $("#trainingInput").value;
      persistDailyTraining();
    });
    $("#trainingInput").addEventListener("keydown", (event) => { if (event.key === "Enter") submitDailyTraining(); });
  }

  function submitDailyTraining() {
    const training = state.dailyTraining;
    const item = training.queue[training.current];
    if (!item || training.answered) return;
    const input = $("#trainingInput")?.value.trim() || "";
    if (!input) {
      $("#trainingFeedback").innerHTML = `<div class="feedback-box wrong"><div class="feedback-title">先输入答案</div><p>请根据中文释义和例句写出英文单词或词组。</p></div>`;
      return;
    }
    $("#trainingInput")?.blur();
    const correct = isCorrect({ type: "spell", answer: item.word.term }, input);
    training.answered = true;
    item.answered = true;
    item.answer = input;
    item.draft = "";
    item.correct = correct;
    if (correct) training.correct += 1;
    else {
      training.wrong += item.retry ? 0 : 1;
      if (!item.retry) training.queue.push({ word: item.word, retry: true });
    }
    updateWordProgress(item.word, correct, "daily-training", input);
    item.feedbackHtml = `<div class="feedback-box ${correct ? "" : "wrong"}"><div class="feedback-title">${correct ? "回答正确" : "需要再巩固"}</div>${correct ? "" : `<p>正确答案：<strong>${escapeHtml(item.word.term)}</strong></p>`}<p><strong>词族：</strong>${escapeHtml(item.word.wordFamily || "暂无")}</p><p><strong>提醒：</strong>${escapeHtml(item.word.note || "")}</p></div>`;
    $("#trainingFeedback").innerHTML = item.feedbackHtml;
    $("#submitTraining").classList.add("hidden");
    $("#nextTraining").classList.remove("hidden");
    persistDailyTraining();
  }

  function previousDailyTraining() {
    const training = state.dailyTraining;
    if (!training || training.current <= 0) return;
    training.current -= 1;
    persistDailyTraining();
    renderDailyTraining();
  }

  function nextDailyTraining() {
    const training = state.dailyTraining;
    if (!training || !training.queue[training.current]?.answered) return;
    training.current += 1;
    training.answered = false;
    persistDailyTraining();
    renderDailyTraining();
  }

  function openTraining({ updateUrl = true } = {}) {
    if (!$("#trainingWeek").options.length) populateTrainingOptions();
    renderTrainingDays();
    if (!state.dailyTraining.queue.length || state.dailyTraining.week !== Number($("#trainingWeek").value) || state.dailyTraining.day !== Number($("#trainingDay").value)) startDailyTraining();
    else renderDailyTraining();
    showView("training", { updateUrl, route: "study/training" });
  }

  function openStats() {
    renderStats();
    showView("stats");
  }

  function populateWeekOptions() {
    const weeks = [...new Set(words.map((word) => word.week))].sort((a, b) => a - b);
    const from = $("#weekFrom");
    const to = $("#weekTo");
    if (!weeks.length) return;
    const options = weeks.map((week) => `<option value="${week}">Week ${week}</option>`).join("");
    from.innerHTML = options;
    to.innerHTML = options;
    from.value = String(weeks[0]);
    to.value = String(weeks[weeks.length - 1]);
    $("#headerStat").textContent = `${words.length} 个词汇单位`;
    populateStudyOptions(weeks);
  }

  function escapeHtml(value) {
    return String(value ?? "").replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[char]));
  }

  $("#setupForm").addEventListener("submit", (event) => { event.preventDefault(); startExam(); });
  $("#submitAnswer").addEventListener("click", submitAnswer);
  $("#nextQuestion").addEventListener("click", () => { state.current += 1; renderQuestion(); });
  $("#quitExam").addEventListener("click", () => showView("setup"));
  $("#newExam").addEventListener("click", () => showView("setup"));
  $("#retryWrong").addEventListener("click", retryWrong);
  $("#openSpeaking").addEventListener("click", () => openPractice("speaking"));
  $("#openWriting").addEventListener("click", () => openPractice("writing"));
  $("#backFromSpeaking").addEventListener("click", () => showView("setup"));
  $("#backFromWriting").addEventListener("click", () => showView("setup"));
  ["speaking", "writing"].forEach((mode) => {
    const ids = practiceIds(mode);
    const prefix = mode === "speaking" ? "Speaking" : "Writing";
    $(`#save${prefix}`).addEventListener("click", () => savePracticeRecord(mode));
    $(`#new${prefix}Prompt`).addEventListener("click", () => {
      const weeks = weeklyOutputPlan.map((item) => item.week);
      const currentIndex = weeks.indexOf(Number(state.practiceSelection[mode].week));
      state.practiceSelection[mode].week = weeks[(currentIndex + 1) % weeks.length];
      state.practicePromptIndex[mode] = 0;
      $(ids.hint).textContent = "";
      $(ids.response).value = "";
      updatePracticeWordCount(mode);
      populatePracticeControls(mode);
      renderPracticePrompt(mode);
    });
    $(ids.response).addEventListener("input", () => updatePracticeWordCount(mode));
    $(ids.type).addEventListener("change", () => {
      state.practiceSelection[mode].type = $(ids.type).value;
      state.practicePromptIndex[mode] = 0;
      renderPracticePrompt(mode);
      const route = `${mode}/${state.practiceSelection[mode].type}`;
      if (window.location.hash !== `#/${route}`) window.location.hash = `#/${route}`;
    });
    $(ids.week).addEventListener("change", () => {
      state.practiceSelection[mode].week = Number($(ids.week).value);
      state.practicePromptIndex[mode] = 0;
      renderPracticePrompt(mode);
    });
  });
  $("#openStudy").addEventListener("click", openStudy);
  $("#openTraining").addEventListener("click", openTraining);
  $("#backFromTraining").addEventListener("click", () => showView("setup"));
  $("#startTraining").addEventListener("click", startDailyTraining);
  $("#submitTraining").addEventListener("click", submitDailyTraining);
  $("#nextTraining").addEventListener("click", nextDailyTraining);
  $("#trainingWeek").addEventListener("change", () => { state.dailyTraining.week = Number($("#trainingWeek").value); renderTrainingDays(); });
  $("#trainingDay").addEventListener("change", () => { state.dailyTraining.day = Number($("#trainingDay").value); });
  $("#backFromStudy").addEventListener("click", () => showView("setup"));
  $("#openStats").addEventListener("click", openStats);
  $("#backFromStats").addEventListener("click", () => showView("setup"));
  $("#exportData").addEventListener("click", () => {
    const exported = typeof db.download === "function" && db.download();
    $("#statsDataHint").textContent = exported ? "已开始下载 SQLite 学习数据文件。" : "当前浏览器无法导出数据库文件。";
  });
  $("#importData").addEventListener("click", () => $("#importDataFile").click());
  $("#importDataFile").addEventListener("change", async (event) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file || typeof db.importBytes !== "function") return;
    if (!window.confirm("导入会替换当前本机学习数据，确定继续吗？")) return;
    try {
      await db.importBytes(new Uint8Array(await file.arrayBuffer()));
      $("#statsDataHint").textContent = "导入成功，正在刷新统计数据。";
      renderStats();
      renderHistory();
    } catch (error) {
      console.error("Failed to import learning data", error);
      $("#statsDataHint").textContent = "导入失败，请选择有效的 SQLite 数据库文件。";
    }
  });
  $("#studyWeek").addEventListener("change", () => {
    state.studyWeek = Number($("#studyWeek").value);
    state.studyDay = 1;
    renderStudyDays();
    renderStudyWords();
  });
  $("#studyDay").addEventListener("change", () => {
    state.studyDay = $("#studyDay").value;
    renderStudyWords();
  });
  $("#studyFilter").addEventListener("change", () => {
    state.studyFilter = $("#studyFilter").value;
    renderStudyWords();
  });
  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-speak-accent]");
    if (!button) return;
    event.preventDefault();
    const word = words.find((item) => item.id === button.dataset.wordId);
    if (word) speakWord(word, button.dataset.speakAccent, button);
  });
  $("#studyWords").addEventListener("click", (event) => {
    const button = event.target.closest("[data-study-action]");
    if (!button) return;
    const card = button.closest("[data-word-id]");
    const word = words.find((item) => item.id === card?.dataset.wordId);
    if (!word) return;
    if (button.dataset.studyAction === "mastered") updateStudyLevel(word, 5, "study-mastered");
    else scheduleStudyReview(word);
  });
  $("#studyWords").addEventListener("change", (event) => {
    if (!event.target.matches(".study-level")) return;
    const card = event.target.closest("[data-word-id]");
    const word = words.find((item) => item.id === card?.dataset.wordId);
    if (word) updateStudyLevel(word, Number(event.target.value), "study-level");
  });
  document.addEventListener("keydown", (event) => {
    if (views.training.classList.contains("active") && !event.target.closest("input, textarea, select, [contenteditable='true']")) {
      if (event.key === "ArrowLeft") {
        event.preventDefault();
        previousDailyTraining();
        return;
      }
      if (event.key === "ArrowRight") {
        event.preventDefault();
        if (state.dailyTraining?.answered) nextDailyTraining();
        else submitDailyTraining();
        return;
      }
    }
    if (event.key === "Enter" && views.exam.classList.contains("active")) {
      if (!state.answered) submitAnswer(); else { state.current += 1; renderQuestion(); }
    }
  });
  window.IELTSStats = { render: renderStats };
  window.addEventListener("hashchange", routeFromHash);
  populateWeekOptions();
  renderHistory();
  restoreDailyTraining();
  routeFromHash();
})();
});
