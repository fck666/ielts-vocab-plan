(() => {
  "use strict";

  const words = Array.isArray(window.IELTS_WORDS) ? window.IELTS_WORDS : [];
  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => [...document.querySelectorAll(selector)];
  const storageKey = "ielts-vocabulary-lab-records-v1";
  const progressKey = "ielts-vocabulary-lab-progress-v1";
  const practiceKey = "ielts-vocabulary-lab-practice-v1";

  const practicePrompts = {
    speaking: [
      { title: "为什么学校应该培养批判性思维？", body: "请回答 1–2 分钟，尽量使用本周词汇，并给出一个具体例子。", hints: ["critical thinking", "academic performance", "from my perspective"] },
      { title: "科技是否让人与人之间的交流变得更好？", body: "先给出立场，再讨论一个优点和一个潜在问题。", hints: ["face-to-face interaction", "online platform", "to some extent"] },
      { title: "年轻人应该如何应对工作压力？", body: "结合个人经历或观察，说明至少两种可行办法。", hints: ["cope with stress", "work-life balance", "maintain a balance"] },
      { title: "城市政府应该优先解决哪一个问题？", body: "选择一个城市问题，解释原因并提出解决方案。", hints: ["urban planning", "public transport", "take effective measures"] },
    ],
    writing: [
      { title: "Some people think governments should spend more money on public services than on the arts.", body: "写一个 Task 2 主体段或完整提纲，明确你的立场并给出具体理由。", hints: ["public funding", "allocate resources", "on balance"] },
      { title: "Technology has changed the way people communicate. Is this a positive or negative development?", body: "写一个包含让步和反驳的主体段，避免只罗列观点。", hints: ["technological advancement", "social interaction", "nevertheless"] },
      { title: "More people are moving from rural areas to cities. What problems can this cause?", body: "写问题—原因—结果链，并提出一个可行的解决方向。", hints: ["rural-urban migration", "urban sprawl", "address the issue"] },
      { title: "Should schools make physical education compulsory?", body: "写一个 120–180 词的论证段，注意使用准确搭配。", hints: ["compulsory", "physical activity", "well-being"] },
    ],
  };

  const state = {
    questions: [],
    current: 0,
    correct: 0,
    answered: false,
    selectedOption: null,
    results: [],
    config: null,
    practiceMode: "speaking",
    practicePromptIndex: 0,
    studyWeek: 1,
    studyDay: 1,
    studyFilter: "all",
  };

  const views = { setup: $("#setupView"), exam: $("#examView"), result: $("#resultView"), practice: $("#practiceView"), study: $("#studyView") };

  // Speech synthesis is available without a server, but installed voices depend on the browser and OS.
  const speech = window.speechSynthesis || null;
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
    speech.cancel();
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
    utterance.rate = 0.88;
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

  function showView(name) {
    Object.entries(views).forEach(([key, view]) => view.classList.toggle("active", key === name));
    window.scrollTo({ top: 0, behavior: "smooth" });
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
    try { return JSON.parse(localStorage.getItem(progressKey) || "{}"); } catch { return {}; }
  }

  function saveProgress(progress) {
    localStorage.setItem(progressKey, JSON.stringify(progress));
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
    const records = loadRecords();
    records.unshift(record);
    localStorage.setItem(storageKey, JSON.stringify(records.slice(0, 20)));
    renderHistory();
  }

  function loadRecords() {
    try { return JSON.parse(localStorage.getItem(storageKey) || "[]"); } catch { return []; }
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
    try { return JSON.parse(localStorage.getItem(practiceKey) || "[]"); } catch { return []; }
  }

  function savePracticeRecord() {
    const response = $("#practiceResponse").value.trim();
    if (!response) {
      $("#practiceHint").textContent = "请先写下回答，再保存练习。";
      return;
    }
    const prompts = practicePrompts[state.practiceMode];
    const prompt = prompts[state.practicePromptIndex];
    const records = loadPracticeRecords();
    records.unshift({ mode: state.practiceMode, prompt: prompt.title, response, rating: Number($("#practiceRating").value), createdAt: new Date().toISOString() });
    localStorage.setItem(practiceKey, JSON.stringify(records.slice(0, 50)));
    $("#practiceHint").textContent = "已保存到本机。可以换一个题目继续练习。";
    $("#practiceResponse").value = "";
    updatePracticeWordCount();
    renderPracticeHistory();
  }

  function renderPracticeHistory() {
    const records = loadPracticeRecords();
    $("#practiceCount").textContent = `${records.length} 次`;
    $("#practiceHistory").innerHTML = records.length ? records.slice(0, 12).map((record) => `<div class="practice-history-item"><strong>${record.mode === "speaking" ? "口语 Part 3" : "Task 2 写作"} · ${record.rating}/5</strong><p>${escapeHtml(record.response)}</p><small>${new Date(record.createdAt).toLocaleDateString("zh-CN")}</small></div>`).join("") : `<p class="empty-state">还没有练习记录。先完成一次回答吧。</p>`;
  }

  function updatePracticeWordCount() {
    const value = $("#practiceResponse").value.trim();
    const count = value ? value.split(/\s+/).filter(Boolean).length : 0;
    $("#practiceWordCount").textContent = `${count} 词`;
  }

  function renderPracticePrompt() {
    const prompts = practicePrompts[state.practiceMode];
    const prompt = prompts[state.practicePromptIndex % prompts.length];
    $("#practicePromptType").textContent = state.practiceMode === "speaking" ? "口语 Part 3" : "Task 2 写作";
    $("#practicePromptWeek").textContent = state.practiceMode === "speaking" ? "观点 · 理由 · 例子" : "立场 · 论证 · 搭配";
    $("#practicePromptTitle").textContent = prompt.title;
    $("#practicePromptBody").textContent = prompt.body;
    $("#practiceHints").innerHTML = prompt.hints.map((hint) => `<span>${escapeHtml(hint)}</span>`).join("");
  }

  function openPractice(mode = "speaking") {
    state.practiceMode = mode;
    state.practicePromptIndex = 0;
    $$(".practice-tab").forEach((tab) => tab.classList.toggle("active", tab.dataset.practiceMode === mode));
    $("#practiceHint").textContent = "";
    renderPracticePrompt();
    renderPracticeHistory();
    showView("practice");
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
  $("#openPractice").addEventListener("click", () => openPractice());
  $("#backToSetup").addEventListener("click", () => showView("setup"));
  $("#savePractice").addEventListener("click", savePracticeRecord);
  $("#newPrompt").addEventListener("click", () => {
    const prompts = practicePrompts[state.practiceMode];
    state.practicePromptIndex = (state.practicePromptIndex + 1) % prompts.length;
    $("#practiceHint").textContent = "";
    $("#practiceResponse").value = "";
    updatePracticeWordCount();
    renderPracticePrompt();
  });
  $("#practiceResponse").addEventListener("input", updatePracticeWordCount);
  $$(".practice-tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      state.practiceMode = tab.dataset.practiceMode;
      state.practicePromptIndex = 0;
      $$(".practice-tab").forEach((item) => {
        item.classList.toggle("active", item === tab);
      });
      $("#practiceHint").textContent = "";
      $("#practiceResponse").value = "";
      updatePracticeWordCount();
      renderPracticePrompt();
    });
  });
  $("#openStudy").addEventListener("click", openStudy);
  $("#backFromStudy").addEventListener("click", () => showView("setup"));
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
    if (event.key === "Enter" && views.exam.classList.contains("active")) {
      if (!state.answered) submitAnswer(); else { state.current += 1; renderQuestion(); }
    }
  });
  populateWeekOptions();
  renderHistory();
})();
