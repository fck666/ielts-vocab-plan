(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  const $$ = selector => [...document.querySelectorAll(selector)];
  const esc = value => String(value).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[c]);
  const weeks = [
    {theme:"教育、学习",focus:"把学习经历讲具体",hints:["pick up a skill","a hands-on approach","keep me motivated"],
      p1:[["Do you enjoy learning new things?","你喜欢学习新事物吗？"],["What was your favourite subject at school?","你在学校最喜欢什么科目？"],["Do you prefer studying alone or with other people?","你喜欢独自学习还是和别人一起学习？"]],
      p2:{title:"Describe a teacher who had a positive influence on you.",zh:"描述一位对你有积极影响的老师。",cues:["who this teacher was","when and where you studied with them","what they did that helped you"],explain:"and explain why their influence was important to you."},
      p3:[["How can schools help students become more independent learners?","学校如何帮助学生成为更独立的学习者？"],["Is practical experience as valuable as classroom learning?","实践经验是否与课堂学习同样有价值？"],["Why do some adults find it difficult to return to education?","为什么一些成年人觉得重返校园很困难？"]]},
    {theme:"工作、职场",focus:"用一次经历说明能力",hints:["transferable skills","work-life balance","learn on the job"],
      p1:[["What do you enjoy most about your work or studies?","你最喜欢工作或学习的哪一点？"],["Would you prefer to work in a team or on your own?","你更喜欢团队工作还是独自工作？"],["What kind of work would you like to do in the future?","你将来想从事什么工作？"]],
      p2:{title:"Describe a useful skill you learned for work or study.",zh:"描述一项对工作或学习有用的技能。",cues:["what the skill was","how you learned it","when you used it"],explain:"and explain how this skill helped you."},
      p3:[["What skills are becoming more important in the workplace?","哪些技能在职场上变得更重要？"],["How can employers help staff maintain a healthy work-life balance?","雇主如何帮助员工平衡工作与生活？"],["Should companies invest more in training existing employees?","企业是否应该更多投资于现有员工培训？"]]},
    {theme:"科技、数字生活",focus:"比较改变前后的生活",hints:["stay connected","digital distractions","protect personal data"],
      p1:[["Which digital device do you use most often?","你最常用哪种数字设备？"],["Do you ever take a break from using your phone?","你会暂时放下手机休息吗？"],["Has technology changed the way you study?","科技改变了你的学习方式吗？"]],
      p2:{title:"Describe a piece of technology that is useful in your daily life.",zh:"描述一件对你日常生活有用的科技产品。",cues:["what it is","how you use it","when you started using it"],explain:"and explain how it has changed your daily routine."},
      p3:[["Has technology improved the quality of communication?","科技是否提升了沟通的质量？"],["Who should be responsible for protecting personal information online?","谁应负责保护网络上的个人信息？"],["Why might some people struggle to adapt to new technology?","为什么有些人难以适应新技术？"]]},
    {theme:"环境、能源",focus:"从具体行动谈到更大影响",hints:["reduce waste","renewable energy","make a small difference"],
      p1:[["Do you try to save electricity at home?","你在家会注意节电吗？"],["Is there a park or green space near your home?","你家附近有公园或绿地吗？"],["What do you usually do with things you no longer need?","你通常怎样处理不再需要的东西？"]],
      p2:{title:"Describe a time when you did something to help the environment.",zh:"描述一次你为保护环境做事的经历。",cues:["what you did","where and when you did it","who was involved"],explain:"and explain how you felt about the experience."},
      p3:[["How can cities encourage people to use less energy?","城市如何鼓励人们减少能源消耗？"],["Should governments or individuals take greater responsibility for environmental protection?","政府和个人谁应承担更大的环保责任？"],["What makes it difficult for businesses to reduce waste?","是什么让企业难以减少废弃物？"]]},
    {theme:"健康、生活方式",focus:"解释习惯形成的原因",hints:["a balanced routine","stay physically active","build a healthy habit"],
      p1:[["What do you do to stay healthy?","你会做什么来保持健康？"],["Do you prefer exercising indoors or outdoors?","你更喜欢室内还是户外运动？"],["Has your daily routine changed in recent years?","你的日常作息近年有变化吗？"]],
      p2:{title:"Describe a healthy habit you would like to develop.",zh:"描述一个你想养成的健康习惯。",cues:["what the habit is","why you want to develop it","what you would need to change"],explain:"and explain what might help you keep this habit."},
      p3:[["Why do some people find it hard to change unhealthy habits?","为什么有些人难以改变不健康的习惯？"],["How can schools encourage children to lead healthier lives?","学校如何鼓励孩子过更健康的生活？"],["Should public health services focus more on prevention?","公共卫生服务是否应该更重视预防？"]]},
    {theme:"城市、交通",focus:"描述地点，比较不同选择",hints:["within walking distance","public transport","a sense of community"],
      p1:[["What do you like about the area where you live?","你喜欢居住地区的哪些方面？"],["How do you usually travel around your city?","你通常在城市里怎样出行？"],["Would you like to live somewhere quieter?","你想住在更安静的地方吗？"]],
      p2:{title:"Describe a place in a city that you enjoy visiting.",zh:"描述一个你喜欢去的城市地点。",cues:["where it is","what it is like","what you do there"],explain:"and explain why you enjoy spending time there."},
      p3:[["What is an effective way to reduce traffic congestion?","什么方式能有效缓解交通拥堵？"],["How can cities become more suitable for families?","城市如何变得更适合家庭居住？"],["Should city centres give more space to pedestrians?","城市中心是否应该给行人更多空间？"]]},
    {theme:"经济、消费",focus:"说明选择，不只给结论",hints:["value for money","an impulse purchase","make an informed choice"],
      p1:[["Do you prefer saving money or spending it?","你更喜欢存钱还是花钱？"],["Do you compare prices before buying something?","你购买东西前会比较价格吗？"],["Do you enjoy shopping online?","你喜欢网购吗？"]],
      p2:{title:"Describe something you bought that was worth the money.",zh:"描述一件你认为买得很值的东西。",cues:["what it was","when you bought it","how you have used it"],explain:"and explain why you think it was worth the money."},
      p3:[["Why do people sometimes buy things they do not need?","为什么人们有时会买不需要的东西？"],["How does advertising influence young consumers?","广告如何影响年轻消费者？"],["What can governments do to reduce income inequality?","政府能做些什么来缩小收入差距？"]]},
    {theme:"媒体、社会",focus:"区分事实、看法和例证",hints:["a reliable source","check the facts","shape public opinion"],
      p1:[["How do you usually find out about the news?","你通常如何了解新闻？"],["Do you prefer reading news or watching it?","你更喜欢看文字新闻还是视频新闻？"],["What kinds of online content interest you?","什么类型的网络内容让你感兴趣？"]],
      p2:{title:"Describe a news story that attracted your attention.",zh:"描述一则引起你注意的新闻。",cues:["what the story was about","where you heard or read about it","what you did after learning about it"],explain:"and explain why it interested you."},
      p3:[["How can people judge whether online information is reliable?","人们如何判断网络信息是否可靠？"],["Why do negative news stories often attract attention?","为什么负面新闻常常引起注意？"],["What responsibilities do people have when sharing news online?","人们在网络分享新闻时应承担什么责任？"]]},
    {theme:"文化、旅游",focus:"用细节表现体验与差异",hints:["cultural heritage","local traditions","a memorable experience"],
      p1:[["What kinds of places do you like visiting on holiday?","假期你喜欢去什么地方？"],["Is there a local tradition that you particularly enjoy?","你特别喜欢哪项当地传统？"],["Do you prefer travelling alone or with other people?","你喜欢独自旅行还是结伴出游？"]],
      p2:{title:"Describe a traditional place or event you have experienced.",zh:"描述一个你去过的传统场所或参与过的传统活动。",cues:["what it was","where and when you experienced it","what you saw or did there"],explain:"and explain what made it memorable."},
      p3:[["Why is it important to preserve historic buildings?","为什么保护历史建筑很重要？"],["How can tourism benefit local communities?","旅游如何为当地社区带来好处？"],["Do you think globalisation makes cultures more similar?","你认为全球化会使文化变得更相似吗？"]]},
    {theme:"综合复习",focus:"串联熟悉话题，减少模板感",hints:["what I learned from this","to some extent","in the longer term"],
      p1:[["Which part of your daily routine would you most like to change?","你最想改变日常作息的哪一部分？"],["What is something new you would like to learn?","你想学什么新东西？"],["Where would you like to spend more time in the future?","你将来希望在什么地方多待一些时间？"]],
      p2:{title:"Describe a change you made that improved your daily life.",zh:"描述一个改善了你日常生活的改变。",cues:["what the change was","why you decided to make it","how you made it happen"],explain:"and explain what difference it has made to your life."},
      p3:[["Why are some people more willing to accept change than others?","为什么有些人比其他人更愿意接受改变？"],["How should governments balance short-term needs with long-term goals?","政府应如何平衡短期需求与长期目标？"],["Can technology solve most of the problems facing society?","科技能解决社会面临的大部分问题吗？"]]}
  ];
  const parts = {
    1:{eyebrow:"FAMILIAR TOPICS",title:"先回答，再补一个细节。",description:"围绕日常经历自然回答，不追求每题说满。先说明你的看法，再补原因或具体细节。",official:"考试：整个 Part 1 为 4–5 分钟",practice:"本页训练参考：每题 45 秒，可继续",target:45,focus:"直接回答问题，再补充一个你自己的细节。"},
    2:{eyebrow:"YOUR LONG TURN",title:"一个故事，讲清楚就好。",description:"用一分钟写下关键词，再连续讲述一到两分钟。题卡留在身边，帮助你组织经历与感受。",official:"考试：准备 1 分钟 · 陈述 1–2 分钟",practice:"整个 Part 2 约 3–4 分钟，含后续简短提问",target:120,focus:"把人物、具体经历和感受连起来，避免只逐条回答提纲。"},
    3:{eyebrow:"IDEAS & DISCUSSION",title:"给出观点，也说明为什么。",description:"从个人经历走向社会层面，用原因、对比和例证展开。承认例外，也是一种清晰的表达。",official:"考试：整个 Part 3 为 4–5 分钟",practice:"本页训练参考：每题 90 秒，可继续",target:90,focus:"先给观点，再解释原因或比较不同情况，用一个例子支撑。"}
  };
  const criteria = [
    {key:"fluency",name:"流利度与连贯性",hint:"想法是否连贯？是否出现较多无意义的重复？"},
    {key:"vocabulary",name:"词汇运用",hint:"用词是否自然、准确？遇到生词能否换个说法？"},
    {key:"grammar",name:"语法多样性与准确性",hint:"能否使用不同句式？错误是否影响理解？"},
    {key:"pronunciation",name:"发音",hint:"是否容易听懂？注意重音、语调与意群。"}
  ];
  let selectedWeek=1,selectedPart=1,page="practice",queue=[],queueIndex=0,phase="ready",active=false;
  let elapsed=0,anchor=0,paused=false,ticker=null,demoAdvanced=false,pendingNavigation=null,resumeAfterDialog=false;
  let sessionNotes="",ratings={},improvement="",records=[],recordSequence=0,viewingRecord=null,currentSavedId=null;
  let playbackElapsed=0,playbackDuration=0,playbackRate=1,playbackTimer=null,playbackAnchor=0,playbackBase=0;
  const descriptor=()=>queue[queueIndex];
  function question(d){const w=weeks[d.week-1];return d.part===2?w.p2:{title:w["p"+d.part][d.index][0],zh:w["p"+d.part][d.index][1]};}
  function time(seconds){seconds=Math.max(0,Math.floor(seconds));return String(Math.floor(seconds/60)).padStart(2,"0")+":"+String(seconds%60).padStart(2,"0");}
  function toast(message){$("#toast").textContent=message;$("#toast").classList.add("show");clearTimeout(toast.timer);toast.timer=setTimeout(()=>$("#toast").classList.remove("show"),2400);}
  function showPage(next){stopPlayback();page=next;$$('.page').forEach(el=>el.classList.toggle('active',el.id===next+'Page'));$$('[data-nav]').forEach(el=>{if(el.dataset.nav===next)el.setAttribute('aria-current','page');else el.removeAttribute('aria-current');});if(next==='practice')renderPractice();if(next==='plan')renderPlan();if(next==='history')renderHistory();document.querySelector('main').scrollTop=0;window.scrollTo(0,0);}
  function navigate(next){if(page===next)return;requestNavigation(()=>{active=false;stopClock();showPage(next);});}
  function requestNavigation(action){if(active){pendingNavigation=action;resumeAfterDialog=(phase==='preparing'||phase==='answering')&&!paused;if(resumeAfterDialog)pauseClock();$("#leaveDialog").showModal();}else action();}
  function resolveLeave(leave){$("#leaveDialog").close();const action=pendingNavigation;pendingNavigation=null;if(leave){active=false;stopClock();if(action)action();}else if(resumeAfterDialog)resumeClock();resumeAfterDialog=false;}
  function renderPractice(){
    const w=weeks[selectedWeek-1],p=parts[selectedPart];$("#weekSelect").value=String(selectedWeek);
    $$('[data-part]').forEach(b=>b.setAttribute('aria-pressed',String(Number(b.dataset.part)===selectedPart)));
    $("#partEyebrow").textContent=p.eyebrow;$("#partTitle").textContent=p.title;$("#partDescription").textContent=p.description;
    $("#officialTiming").textContent=p.official;$("#practiceTiming").textContent=p.practice;$("#questionListTitle").textContent='Week '+selectedWeek+' · '+w.theme;
    const questions=selectedPart===2?[w.p2]:w['p'+selectedPart].map(q=>({title:q[0],zh:q[1]}));
    $("#questionCount").textContent=questions.length+(selectedPart===2?' 张题卡':' 道练习题');
    $("#questionList").innerHTML=questions.map((q,i)=>'<article class="question-row"><span class="question-index">'+String(i+1).padStart(2,'0')+'</span><div class="question-main"><h3 lang="en">'+esc(q.title)+'</h3><p>'+esc(q.zh)+'</p><span class="row-meta">'+(selectedPart===2?'1 分钟准备 · 最多 2 分钟陈述':selectedPart===1?'熟悉话题 · 直接作答':'观点展开 · 原因与例证')+'</span></div><button class="button secondary" data-question="'+i+'">'+(selectedPart===2?'打开题卡':'练这一题')+'</button></article>').join('');
    $$('[data-question]').forEach(b=>b.addEventListener('click',()=>startSession([{week:selectedWeek,part:selectedPart,index:Number(b.dataset.question)}])));
    $("#startGroup").textContent=selectedPart===2?'开始题卡练习 →':'开始这 '+questions.length+' 题 →';
  }
  function renderPlan(){
    $("#planList").innerHTML=weeks.map((w,i)=>'<article class="plan-row '+(i+1===selectedWeek?'active-week':'')+'"><span class="week-number">W'+String(i+1).padStart(2,'0')+'</span><strong>'+esc(w.theme)+'</strong><p>'+esc(w.focus)+'</p><button class="button secondary" data-plan-week="'+(i+1)+'">去练习 →</button></article>').join('');
    $$('[data-plan-week]').forEach(b=>b.addEventListener('click',()=>{selectedWeek=Number(b.dataset.planWeek);showPage('practice');}));
  }
  function startSession(items){queue=items.map(d=>({...d}));queueIndex=0;viewingRecord=null;beginQuestion();}
  function beginQuestion(){
    stopClock();active=true;phase='ready';elapsed=0;paused=false;demoAdvanced=false;sessionNotes='';ratings={};improvement='';currentSavedId=null;viewingRecord=null;
    const d=descriptor(),q=question(d),w=weeks[d.week-1];
    $("#sessionLocation").textContent='Week '+d.week+' · '+w.theme;$("#sessionNumber").textContent=(queueIndex+1)+' / '+queue.length+' 题';
    $("#sessionPart").textContent='PART '+d.part+' · '+({1:'日常问答',2:'个人陈述',3:'深入讨论'})[d.part];$("#sessionQuestion").textContent=q.title;
    $("#cueContent").className=d.part===2?'cue-content':'';$("#cueContent").innerHTML=d.part===2?'<p>You should say:</p><ul>'+q.cues.map(c=>'<li>'+esc(c)+'</li>').join('')+'</ul><p>'+esc(q.explain)+'</p>':'';
    $("#questionTranslation").textContent=q.zh;$("#questionTranslation").hidden=true;$("#translationToggle").textContent='显示中文题意';$("#translationToggle").setAttribute('aria-expanded','false');
    $("#notesLabel").textContent=d.part===2?'准备便笺 · 关键词即可':'思路便笺 · 训练辅助';$("#prepNotes").value='';$("#hintDetails").open=false;$("#focusTip").textContent=parts[d.part].focus;
    $("#expressionHints").innerHTML=w.hints.map(h=>'<span class="expression" lang="en">'+esc(h)+'</span>').join('');
    $("#stepPrepare").hidden=d.part!==2;$("#stepAnswer").textContent=(d.part===2?'2':'1')+' 回答';$("#stepReflect").textContent=(d.part===2?'3':'2')+' 回听与自评';
    showPage('session');renderRecorder();
  }
  function currentElapsed(){return elapsed+((!paused&&(phase==='preparing'||phase==='answering'))?(Date.now()-anchor)/1000:0);}
  function stopClock(){if(ticker)clearInterval(ticker);ticker=null;}
  function runClock(){stopClock();anchor=Date.now();paused=false;ticker=setInterval(tick,200);}
  function pauseClock(){if(paused)return;elapsed=currentElapsed();paused=true;stopClock();renderRecorder();}
  function resumeClock(){if(!paused)return;runClock();renderRecorder();}
  function startPreparation(){phase='preparing';elapsed=0;runClock();renderRecorder();}
  function startAnswer(){stopClock();phase='answering';elapsed=0;sessionNotes=$("#prepNotes").value;runClock();renderRecorder();}
  function tick(){const d=descriptor(),seconds=currentElapsed();if(phase==='preparing'&&seconds>=60){startAnswer();toast('准备时间到，进入回答演示。');return;}if(phase==='answering'&&d.part===2&&seconds>=120){elapsed=120;stopClock();phase='review';paused=false;openReview();return;}renderTimer();}
  function renderTimer(){const d=descriptor();if(!d)return;const seconds=currentElapsed(),target=phase==='preparing'?60:parts[d.part].target;
    $("#timerText").textContent=(phase==='preparing'||(phase==='ready'&&d.part===2))?time(60-(phase==='ready'?0:seconds)):time(seconds);
    $("#timerText").setAttribute('aria-label',(phase==='preparing'?'准备剩余':'回答用时')+$("#timerText").textContent);
    $("#timerFill").style.width=Math.min(100,seconds/target*100)+'%';
    if(phase==='answering'&&d.part!==2&&seconds>=target)$("#timerHelp").textContent='已达到训练参考时间，可以继续或结束回答。';
  }
  function renderRecorder(){
    const d=descriptor(),preparing=phase==='preparing',answering=phase==='answering',running=preparing||answering;
    $("#phaseLabel").textContent=phase==='ready'?(d.part===2?'准备开始':'准备回答'):(preparing?'准备中':'回答中')+(paused?' · 已暂停':'');
    $("#timerHelp").textContent=phase==='ready'?(d.part===2?'先准备 60 秒，再进行最多 120 秒陈述。':'准备好后直接开口，计时只作训练参考。'):preparing?'写下几个关键词；准备好了可提前开始。':d.part===2?'陈述最多 2 分钟，也可以提前结束。':'参考 '+parts[d.part].target+' 秒，不是正式考试单题限时。';
    $("#mainAction").textContent=phase==='ready'?(d.part===2?'开始 1 分钟准备':'开始回答'):preparing?'准备好了，开始回答':'结束回答，去自评';
    $("#pauseAction").hidden=!running;$("#pauseAction").textContent=paused?'继续':'暂停';$("#skipPreparation").hidden=true;$("#demoForward").hidden=!running;
    $("#recordingStatus").textContent=answering?(paused?'回答演示已暂停 · 无录音':'正在演示回答状态 · 无录音'):preparing?'准备阶段 · 未调用麦克风':'未调用麦克风';
    $("#voiceStrip").className='voice-strip'+(answering?' recording':'')+(paused?' paused':'');
    $("#stepPrepare").className=preparing||phase==='ready'?'current':'done';$("#stepAnswer").className=answering||(d.part!==2&&phase==='ready')?'current':'';$("#stepReflect").className='';renderTimer();
  }
  function endAnswer(){if(phase!=='answering')return;elapsed=Math.max(1,currentElapsed());stopClock();paused=false;phase='review';openReview();}
  function openReview(record=null){
    stopClock();stopPlayback();viewingRecord=record;const d=record||descriptor(),q=question(d);
    if(record){active=false;sessionNotes=record.prepNotes;ratings={...record.ratings};improvement=record.improvement;elapsed=record.duration;demoAdvanced=record.demoAdvanced;currentSavedId=record.id;}
    else{active=true;sessionNotes=$("#prepNotes").value;}
    playbackDuration=Math.max(1,Math.round(elapsed));playbackElapsed=0;playbackRate=1;
    $("#reviewPart").textContent='WEEK '+d.week+' · PART '+d.part;$("#reviewQuestion").textContent=q.title;
    $("#reviewSubtitle").textContent=(record?'已保存的演示记录':'本次回答流程演示')+' · '+time(playbackDuration)+(demoAdvanced?' · 使用过演示快进':'');
    $("#reviewNotes").textContent=sessionNotes||'本题没有填写便笺。';$("#improvementNote").value=improvement;
    $("#saveReview").textContent=record?'保存修改':queueIndex<queue.length-1?'保存，下一题 →':'保存，查看记录 →';
    $("#reviewSaveHint").textContent='仅保存到当前页面；不含真实音频';renderAssessment();updatePlayback();showPage('review');
  }
  function renderAssessment(){
    $("#assessmentList").innerHTML=criteria.map(c=>'<section class="criterion"><strong>'+c.name+'</strong><p>'+c.hint+'</p><div class="rating-options" role="group" aria-label="'+c.name+'自评">'+['待加强','基本做到','较稳定'].map(label=>'<button data-rating="'+c.key+'" data-value="'+label+'" aria-pressed="'+(ratings[c.key]===label)+'">'+label+'</button>').join('')+'</div></section>').join('');
    $$('[data-rating]').forEach(b=>b.addEventListener('click',()=>{ratings[b.dataset.rating]=ratings[b.dataset.rating]===b.dataset.value?null:b.dataset.value;renderAssessment();}));
  }
  function stopPlayback(){if(playbackTimer)clearInterval(playbackTimer);playbackTimer=null;if($("#playButton")){$("#playButton").textContent='▶';$("#playButton").setAttribute('aria-label','演示播放状态');}}
  function updatePlayback(){$("#playbackTime").textContent=time(playbackElapsed)+' / '+time(playbackDuration);$("#playbackProgress").value=playbackDuration?Math.round(playbackElapsed/playbackDuration*100):0;$("#speedButton").textContent=playbackRate+'×';}
  function startPlayback(){if(playbackElapsed>=playbackDuration)playbackElapsed=0;playbackBase=playbackElapsed;playbackAnchor=Date.now();$("#playButton").textContent='Ⅱ';$("#playButton").setAttribute('aria-label','暂停演示播放');playbackTimer=setInterval(()=>{playbackElapsed=Math.min(playbackDuration,playbackBase+(Date.now()-playbackAnchor)/1000*playbackRate);updatePlayback();if(playbackElapsed>=playbackDuration)stopPlayback();},150);}
  function storeReview(){
    const d=viewingRecord||descriptor(),existing=records.find(r=>r.id===currentSavedId);
    const record={id:currentSavedId||++recordSequence,week:d.week,part:d.part,index:d.index,duration:Math.round(elapsed),prepNotes:sessionNotes,ratings:{...ratings},improvement:$("#improvementNote").value.trim(),demoAdvanced,createdAt:existing?.createdAt||new Date().toISOString()};
    if(existing)Object.assign(existing,record);else records.unshift(record);currentSavedId=record.id;$("#historyCount").textContent=records.length;return record;
  }
  function saveAndContinue(){storeReview();stopPlayback();active=false;if(viewingRecord){viewingRecord=null;showPage('history');toast('演示记录已更新。');}else if(queueIndex<queue.length-1){queueIndex++;beginQuestion();toast('已保留自评，继续下一题。');}else{showPage('history');toast('本组练习完成，挑一题再练也可以。');}}
  function retryCurrent(){const d={...(viewingRecord||descriptor())};if(!viewingRecord){storeReview();beginQuestion();toast('已保留这次自评，开始重练同一题。');}else startSession([{week:d.week,part:d.part,index:d.index}]);}
  function renderHistory(){
    $("#historyCount").textContent=records.length;
    if(!records.length){$("#historyList").innerHTML='<div class="empty-state"><h2>先留下第一次开口</h2><p>完成一题并保存自评后，会在这里显示。</p><button class="button primary" id="emptyStart">从本周话题开始</button></div>';$("#emptyStart").addEventListener('click',()=>showPage('practice'));return;}
    $("#historyList").innerHTML=records.map(r=>'<article class="history-row"><div class="history-top"><span>WEEK '+r.week+' · PART '+r.part+'</span><span>'+time(r.duration)+' · '+new Date(r.createdAt).toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'})+'</span><span class="demo-tag">演示记录</span></div><h2 lang="en">'+esc(question(r).title)+'</h2><p>'+esc(r.improvement||'还没有填写改进笔记，可以回到自评补充。')+'</p><div class="history-ratings">'+criteria.map(c=>'<span>'+c.name+' · '+(r.ratings[c.key]||'未评价')+'</span>').join('')+'</div><div class="history-actions"><button class="text-button" data-view-record="'+r.id+'">查看自评与回听演示</button><button class="text-button" data-retry-record="'+r.id+'">重练同题 →</button></div></article>').join('');
    $$('[data-view-record]').forEach(b=>b.addEventListener('click',()=>openReview(records.find(r=>r.id===Number(b.dataset.viewRecord)))));
    $$('[data-retry-record]').forEach(b=>b.addEventListener('click',()=>{const r=records.find(r=>r.id===Number(b.dataset.retryRecord));startSession([{week:r.week,part:r.part,index:r.index}]);}));
  }
  $("#weekSelect").innerHTML=weeks.map((w,i)=>'<option value="'+(i+1)+'">Week '+(i+1)+' · '+w.theme+'</option>').join('');
  $$('[data-nav]').forEach(b=>b.addEventListener('click',()=>navigate(b.dataset.nav)));
  $$('[data-part]').forEach(b=>b.addEventListener('click',()=>{selectedPart=Number(b.dataset.part);renderPractice();}));
  $("#weekSelect").addEventListener('change',()=>{selectedWeek=Number($("#weekSelect").value);renderPractice();});
  $("#startGroup").addEventListener('click',()=>{const count=selectedPart===2?1:3;startSession(Array.from({length:count},(_,index)=>({week:selectedWeek,part:selectedPart,index})));});
  $("#mainAction").addEventListener('click',()=>{if(phase==='ready'){if(descriptor().part===2)startPreparation();else startAnswer();}else if(phase==='preparing')startAnswer();else if(phase==='answering')endAnswer();});
  $("#pauseAction").addEventListener('click',()=>paused?resumeClock():pauseClock());
  $("#demoForward").addEventListener('click',()=>{demoAdvanced=true;if(phase==='preparing')startAnswer();else if(phase==='answering'){elapsed=parts[descriptor().part].target;anchor=Date.now();endAnswer();}});
  $("#exitSession").addEventListener('click',()=>navigate('practice'));
  $("#translationToggle").addEventListener('click',()=>{const hidden=!$("#questionTranslation").hidden;$("#questionTranslation").hidden=hidden;$("#translationToggle").setAttribute('aria-expanded',String(!hidden));$("#translationToggle").textContent=hidden?'显示中文题意':'隐藏中文题意';});
  $("#prepNotes").addEventListener('input',()=>sessionNotes=$("#prepNotes").value);
  $("#playButton").addEventListener('click',()=>playbackTimer?stopPlayback():startPlayback());
  $("#playbackProgress").addEventListener('input',()=>{const playing=!!playbackTimer;stopPlayback();playbackElapsed=Number($("#playbackProgress").value)/100*playbackDuration;updatePlayback();if(playing)startPlayback();});
  $("#speedButton").addEventListener('click',()=>{const playing=!!playbackTimer;stopPlayback();playbackRate=playbackRate===1?1.25:playbackRate===1.25?1.5:1;updatePlayback();if(playing)startPlayback();});
  $$('[data-suggestion]').forEach(b=>b.addEventListener('click',()=>{$("#improvementNote").value=b.dataset.suggestion;$("#improvementNote").focus();}));
  $("#saveReview").addEventListener('click',saveAndContinue);$("#retryQuestion").addEventListener('click',retryCurrent);
  $("#aboutButton").addEventListener('click',()=>$("#aboutDialog").showModal());$$('[data-close]').forEach(b=>b.addEventListener('click',()=>$('#'+b.dataset.close).close()));
  $("#keepPracticing").addEventListener('click',()=>resolveLeave(false));$("#confirmLeave").addEventListener('click',()=>resolveLeave(true));$("#leaveDialog").addEventListener('cancel',e=>{e.preventDefault();resolveLeave(false);});
  document.addEventListener('keydown',e=>{if(e.isComposing||e.keyCode===229||e.target.matches('input,textarea,select,button,a,summary')||document.querySelector('dialog[open]'))return;if(page==='session'&&e.code==='Space'){e.preventDefault();if(phase==='ready')$("#mainAction").click();else $("#pauseAction").click();}if(page==='session'&&e.key==='Escape'){e.preventDefault();navigate('practice');}});
  $("#voiceStrip").innerHTML=Array.from({length:38},(_,i)=>'<i style="--height:'+(8+(i*13%28))+'px;--delay:'+(-(i*17%10)/10)+'s"></i>').join('');
  renderPractice();renderPlan();renderHistory();
})();
