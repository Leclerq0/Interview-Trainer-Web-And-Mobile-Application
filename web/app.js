/**
 * AI Interview Trainer - Web Client (Vanilla JS)
 * API: FastAPI Backend + Google Gemini 3.6 Flash
 */

(() => {
  'use strict';

  const API_BASE = `${window.location.origin}/api/v1/interview`;

  const AVAILABLE_TOPICS = [
    'Memory Management (ARC)',
    'Swift Concurrency & Actors',
    'LLVM & Architecture',
    'Data Structures & Algorithms',
    'Multi-threading & Mutexes',
    'Clean Architecture & VIPER'
  ];

  const state = {
    sessionId: null,
    currentTurn: 1,
    maxTurns: 4,
    selectedRole: 'iOS Developer (Swift)',
    selectedSeniority: 'Senior',
    selectedTopics: new Set([
      'Memory Management (ARC)',
      'Swift Concurrency & Actors',
      'LLVM & Architecture'
    ]),
    
    isRecording: false,
    mediaRecorder: null,
    audioChunks: [],
    audioStream: null,
    audioContext: null,
    analyser: null,
    animFrameId: null,
    recordStartTime: null,
    recordTimerId: null,

    isTextMode: false
  };

  const setupView = document.getElementById('setupView');
  const interviewView = document.getElementById('interviewView');
  const reportView = document.getElementById('reportView');
  const evalModal = document.getElementById('evaluatingModal');

  const roleInput = document.getElementById('roleInput');
  const roleChips = document.getElementById('roleChips');
  const seniorityControl = document.getElementById('seniorityControl');
  const topicsGrid = document.getElementById('topicsGrid');
  const maxTurnsInput = document.getElementById('maxTurnsInput');
  const turnsDisplay = document.getElementById('turnsDisplay');
  const turnsHint = document.getElementById('turnsHint');
  const startInterviewBtn = document.getElementById('startInterviewBtn');

  const turnIndicator = document.getElementById('turnIndicator');
  const progressBarFill = document.getElementById('progressBarFill');
  const finishEarlyBtn = document.getElementById('finishEarlyBtn');
  const questionText = document.getElementById('questionText');
  const feedbackCard = document.getElementById('feedbackCard');
  const feedbackBody = document.getElementById('feedbackBody');
  const lastAnswerCard = document.getElementById('lastAnswerCard');
  const lastAnswerText = document.getElementById('lastAnswerText');
  
  const toggleModeBtn = document.getElementById('toggleModeBtn');
  const modeIcon = document.getElementById('modeIcon');
  const modeLabel = document.getElementById('modeLabel');
  const voiceModeContainer = document.getElementById('voiceModeContainer');
  const textModeContainer = document.getElementById('textModeContainer');
  const recordBtn = document.getElementById('recordBtn');
  const micAura = document.getElementById('micAura');
  const micIcon = document.getElementById('micIcon');
  const stopIcon = document.getElementById('stopIcon');
  const recordingTimer = document.getElementById('recordingTimer');
  const recordInstruction = document.getElementById('recordInstruction');
  const waveformCanvas = document.getElementById('waveformCanvas');
  const textAnswerInput = document.getElementById('textAnswerInput');
  const submitTextBtn = document.getElementById('submitTextBtn');

  const scoreCircle = document.getElementById('scoreCircle');
  const reportScore = document.getElementById('reportScore');
  const reportLevel = document.getElementById('reportLevel');
  const reportSummary = document.getElementById('reportSummary');
  const reportStrengths = document.getElementById('reportStrengths');
  const reportWeaknesses = document.getElementById('reportWeaknesses');
  const reportTopics = document.getElementById('reportTopics');
  const reportTurnsList = document.getElementById('reportTurnsList');
  const restartBtn = document.getElementById('restartBtn');

  const toastContainer = document.getElementById('toastContainer');

  function showToast(message, isError = false) {
    const toast = document.createElement('div');
    toast.className = `toast ${isError ? 'error' : ''}`;
    toast.textContent = message;
    toastContainer.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      setTimeout(() => toast.remove(), 300);
    }, 4000);
  }

  function switchView(viewName) {
    [setupView, interviewView, reportView].forEach(v => v.classList.remove('active'));
    if (viewName === 'setup') setupView.classList.add('active');
    else if (viewName === 'interview') interviewView.classList.add('active');
    else if (viewName === 'report') reportView.classList.add('active');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function setEvaluating(isLoading) {
    if (isLoading) {
      evalModal.classList.remove('hidden');
    } else {
      evalModal.classList.add('hidden');
    }
  }

  function initSetupView() {
    topicsGrid.innerHTML = '';
    AVAILABLE_TOPICS.forEach(topic => {
      const isSelected = state.selectedTopics.has(topic);
      const item = document.createElement('div');
      item.className = `topic-item ${isSelected ? 'active' : ''}`;
      item.innerHTML = `
        <div class="topic-checkbox">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>
        </div>
        <span class="topic-title">${topic}</span>
      `;
      item.addEventListener('click', () => {
        if (state.selectedTopics.has(topic)) {
          state.selectedTopics.delete(topic);
          item.classList.remove('active');
        } else {
          state.selectedTopics.add(topic);
          item.classList.add('active');
        }
      });
      topicsGrid.appendChild(item);
    });

    roleChips.querySelectorAll('.chip').forEach(chip => {
      chip.addEventListener('click', () => {
        roleChips.querySelectorAll('.chip').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        roleInput.value = chip.dataset.role;
        state.selectedRole = chip.dataset.role;
      });
    });

    roleInput.addEventListener('input', e => {
      state.selectedRole = e.target.value;
    });

    seniorityControl.querySelectorAll('.segment-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        seniorityControl.querySelectorAll('.segment-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        state.selectedSeniority = btn.dataset.level;
      });
    });

    maxTurnsInput.addEventListener('input', e => {
      const val = parseInt(e.target.value, 10);
      state.maxTurns = val;
      turnsDisplay.textContent = val;
      turnsHint.textContent = `${val} Soru (~${val * 5} dk)`;
    });

    startInterviewBtn.addEventListener('click', startInterview);
  }

  async function startInterview() {
    const role = roleInput.value.trim() || 'Software Engineer';
    const payload = {
      role: role,
      seniority_level: state.selectedSeniority,
      focus_topics: Array.from(state.selectedTopics),
      max_turns: state.maxTurns
    };

    setEvaluating(true);

    try {
      const res = await fetch(`${API_BASE}/start`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        const errText = await res.text();
        throw new Error(`Sunucu Hatası (${res.status}): ${errText}`);
      }

      const data = await res.json();
      state.sessionId = data.session_id;
      state.currentTurn = data.turn_number;
      state.maxTurns = data.max_turns;

      renderInterviewTurn({
        question: data.first_question,
        turnNumber: data.turn_number,
        feedback: null,
        lastAnswer: null
      });

      switchView('interview');
    } catch (err) {
      console.error(err);
      showToast(`Mülakat başlatılamadı: ${err.message}`, true);
    } finally {
      setEvaluating(false);
    }
  }

  function renderInterviewTurn({ question, turnNumber, feedback, lastAnswer }) {
    turnIndicator.textContent = `SORU ${turnNumber} / ${state.maxTurns}`;
    const pct = Math.round((turnNumber / state.maxTurns) * 100);
    progressBarFill.style.width = `${pct}%`;

    questionText.textContent = question;

    if (feedback) {
      feedbackBody.textContent = feedback;
      feedbackCard.classList.remove('hidden');
    } else {
      feedbackCard.classList.add('hidden');
    }

    if (lastAnswer) {
      lastAnswerText.textContent = lastAnswer;
      lastAnswerCard.classList.remove('hidden');
    } else {
      lastAnswerCard.classList.add('hidden');
    }

    textAnswerInput.value = '';
    resetRecordingUI();
  }

  const canvasCtx = waveformCanvas.getContext('2d');

  function drawEmptyWaveform() {
    canvasCtx.clearRect(0, 0, waveformCanvas.width, waveformCanvas.height);
    canvasCtx.fillStyle = 'rgba(255, 255, 255, 0.08)';
    const barCount = 36;
    const barWidth = 6;
    const gap = 6;
    const totalW = barCount * (barWidth + gap);
    const startX = (waveformCanvas.width - totalW) / 2;

    for (let i = 0; i < barCount; i++) {
      const x = startX + i * (barWidth + gap);
      const h = 4;
      const y = (waveformCanvas.height - h) / 2;
      canvasCtx.fillRect(x, y, barWidth, h);
    }
  }
  drawEmptyWaveform();

  function startWaveformVisualizer(stream) {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      state.audioContext = new AudioCtx();
      const source = state.audioContext.createMediaStreamSource(stream);
      state.analyser = state.audioContext.createAnalyser();
      state.analyser.fftSize = 64;
      source.connect(state.analyser);

      const bufferLength = state.analyser.frequencyBinCount;
      const dataArray = new Uint8Array(bufferLength);

      function renderFrame() {
        if (!state.isRecording) return;
        state.animFrameId = requestAnimationFrame(renderFrame);
        state.analyser.getByteFrequencyData(dataArray);

        canvasCtx.clearRect(0, 0, waveformCanvas.width, waveformCanvas.height);

        const barCount = 28;
        const barWidth = 6;
        const gap = 6;
        const totalW = barCount * (barWidth + gap);
        const startX = (waveformCanvas.width - totalW) / 2;

        const grad = canvasCtx.createLinearGradient(0, waveformCanvas.height, 0, 0);
        grad.addColorStop(0, '#06b6d4');
        grad.addColorStop(1, '#a855f7');
        canvasCtx.fillStyle = grad;

        for (let i = 0; i < barCount; i++) {
          const val = dataArray[i % bufferLength] || 0;
          const pct = val / 255;
          const h = Math.max(4, pct * (waveformCanvas.height - 10));
          const x = startX + i * (barWidth + gap);
          const y = (waveformCanvas.height - h) / 2;
          canvasCtx.beginPath();
          canvasCtx.roundRect(x, y, barWidth, h, 3);
          canvasCtx.fill();
        }
      }

      renderFrame();
    } catch (e) {
      console.warn('AudioContext görselleştirici başlatılamadı:', e);
    }
  }

  function stopWaveformVisualizer() {
    if (state.animFrameId) cancelAnimationFrame(state.animFrameId);
    if (state.audioContext && state.audioContext.state !== 'closed') {
      state.audioContext.close();
    }
    drawEmptyWaveform();
  }

  async function startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      state.audioStream = stream;
      state.audioChunks = [];

      const mimeTypes = [
        'audio/webm;codecs=opus',
        'audio/webm',
        'audio/ogg;codecs=opus',
        'audio/mp4'
      ];
      let supportedType = mimeTypes.find(type => MediaRecorder.isTypeSupported(type)) || '';

      const recorder = new MediaRecorder(stream, supportedType ? { mimeType: supportedType } : undefined);
      state.mediaRecorder = recorder;

      recorder.ondataavailable = e => {
        if (e.data && e.data.size > 0) {
          state.audioChunks.push(e.data);
        }
      };

      recorder.onstop = async () => {
        stopWaveformVisualizer();
        stopTimer();
        const mime = state.mediaRecorder.mimeType || 'audio/webm';
        const blob = new Blob(state.audioChunks, { type: mime });
        await submitAudioAnswer(blob);
      };

      recorder.start(100);
      state.isRecording = true;

      recordBtn.classList.add('recording');
      micAura.classList.add('recording');
      micIcon.classList.add('hidden');
      stopIcon.classList.remove('hidden');
      recordInstruction.innerHTML = '<strong>Kaydediliyor...</strong> Bitirmek için butona tekrar dokunun.';

      startTimer();
      startWaveformVisualizer(stream);
    } catch (err) {
      console.error(err);
      showToast(`Mikrofon erişimi sağlanamadı: ${err.message}`, true);
      resetRecordingUI();
    }
  }

  function stopRecording() {
    if (!state.isRecording || !state.mediaRecorder) return;
    state.isRecording = false;

    if (state.mediaRecorder.state !== 'inactive') {
      state.mediaRecorder.stop();
    }

    if (state.audioStream) {
      state.audioStream.getTracks().forEach(track => track.stop());
    }

    resetRecordingUI();
  }

  function resetRecordingUI() {
    state.isRecording = false;
    recordBtn.classList.remove('recording');
    micAura.classList.remove('recording');
    micIcon.classList.remove('hidden');
    stopIcon.classList.add('hidden');
    recordInstruction.innerHTML = '<strong>Konuşmak için Dokun</strong> veya <strong>Boşluk (Space)</strong> tuşuna bas';
    recordingTimer.textContent = '00:00';
    stopWaveformVisualizer();
  }

  function startTimer() {
    state.recordStartTime = Date.now();
    recordingTimer.textContent = '00:00';
    state.recordTimerId = setInterval(() => {
      const elapsed = Math.floor((Date.now() - state.recordStartTime) / 1000);
      const m = String(Math.floor(elapsed / 60)).padStart(2, '0');
      const s = String(elapsed % 60).padStart(2, '0');
      recordingTimer.textContent = `${m}:${s}`;
    }, 500);
  }

  function stopTimer() {
    if (state.recordTimerId) clearInterval(state.recordTimerId);
  }

  async function submitAudioAnswer(audioBlob) {
    if (audioBlob.size < 500) {
      showToast('Ses kaydı çok kısa veya algılanamadı. Lütfen tekrar deneyin.', true);
      return;
    }

    setEvaluating(true);

    const formData = new FormData();
    formData.append('session_id', state.sessionId);
    formData.append('audio_file', audioBlob, 'candidate_answer.webm');

    try {
      const res = await fetch(`${API_BASE}/answer-audio`, {
        method: 'POST',
        body: formData
      });

      if (!res.ok) {
        const errText = await res.text();
        throw new Error(`Hata (${res.status}): ${errText}`);
      }

      const data = await res.json();
      handleTurnResponse(data);
    } catch (err) {
      console.error(err);
      showToast(`Sesli cevap iletilemedi: ${err.message}`, true);
    } finally {
      setEvaluating(false);
    }
  }

  async function submitTextAnswer() {
    const text = textAnswerInput.value.trim();
    if (!text) {
      showToast('Lütfen teknik cevabınızı yazın.', true);
      return;
    }

    setEvaluating(true);

    const payload = {
      session_id: state.sessionId,
      candidate_answer: text
    };

    try {
      const res = await fetch(`${API_BASE}/answer`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        const errText = await res.text();
        throw new Error(`Hata (${res.status}): ${errText}`);
      }

      const data = await res.json();
      handleTurnResponse(data, text);
    } catch (err) {
      console.error(err);
      showToast(`Cevap iletilemedi: ${err.message}`, true);
    } finally {
      setEvaluating(false);
    }
  }

  function handleTurnResponse(data, rawTextAnswer = null) {
    const candidateAnswer = data.transcribed_text || rawTextAnswer || '';

    if (data.is_finished || !data.next_question) {
      finishInterview();
    } else {
      state.currentTurn = data.current_turn;
      renderInterviewTurn({
        question: data.next_question,
        turnNumber: data.current_turn,
        feedback: data.feedback,
        lastAnswer: candidateAnswer
      });
    }
  }

  async function finishInterview() {
    setEvaluating(true);

    try {
      const res = await fetch(`${API_BASE}/${state.sessionId}/finish`, {
        method: 'POST'
      });

      if (!res.ok) {
        const errText = await res.text();
        throw new Error(`Rapor alınamadı (${res.status}): ${errText}`);
      }

      const data = await res.json();
      renderReport(data);
      switchView('report');
    } catch (err) {
      console.error(err);
      showToast(`Rapor yüklenirken hata oluştu: ${err.message}`, true);
    } finally {
      setEvaluating(false);
    }
  }

  function renderReport(data) {
    const report = data.report;
    const score = report.overall_score || 0;

    reportScore.textContent = score;
    const circumference = 2 * Math.PI * 50; // r=50 -> ~314.16
    const offset = circumference - (score / 100) * circumference;
    scoreCircle.style.strokeDashoffset = offset;

    if (score >= 75) scoreCircle.style.stroke = '#10b981';
    else if (score >= 50) scoreCircle.style.stroke = '#f59e0b';
    else scoreCircle.style.stroke = '#ef4444';

    reportLevel.textContent = report.performance_level || 'Değerlendirildi';
    reportSummary.textContent = report.summary || 'Özet bilgi mevcut değil.';

    reportStrengths.innerHTML = '';
    (report.strengths || []).forEach(item => {
      const li = document.createElement('li');
      li.textContent = item;
      reportStrengths.appendChild(li);
    });

    reportWeaknesses.innerHTML = '';
    (report.critical_weaknesses || []).forEach(item => {
      const li = document.createElement('li');
      li.textContent = item;
      reportWeaknesses.appendChild(li);
    });

    reportTopics.innerHTML = '';
    (report.recommended_topics || []).forEach(topic => {
      const tag = document.createElement('span');
      tag.className = 'rec-tag';
      tag.textContent = topic;
      reportTopics.appendChild(tag);
    });

    reportTurnsList.innerHTML = '';
    const turns = data.turns || [];
    turns.forEach(turn => {
      const card = document.createElement('div');
      card.className = 'turn-card';
      card.innerHTML = `
        <div class="turn-card-header">Soru ${turn.turn_number}</div>
        <div class="turn-q"><strong>Soru:</strong> ${turn.question}</div>
        <div class="turn-a"><strong>Cevabınız:</strong> ${turn.candidate_answer}</div>
        <div class="turn-f"><strong>Profesör Eleştirisi:</strong> ${turn.feedback}</div>
      `;
      reportTurnsList.appendChild(card);
    });
  }

  function initEventListeners() {
    toggleModeBtn.addEventListener('click', () => {
      state.isTextMode = !state.isTextMode;
      if (state.isTextMode) {
        voiceModeContainer.classList.add('hidden');
        textModeContainer.classList.remove('hidden');
        modeIcon.textContent = '🎙️';
        modeLabel.textContent = 'Sesli Yanıta Geç';
        textAnswerInput.focus();
      } else {
        voiceModeContainer.classList.remove('hidden');
        textModeContainer.classList.add('hidden');
        modeIcon.textContent = '⌨️';
        modeLabel.textContent = 'Metinle Yanıtla';
      }
    });

    recordBtn.addEventListener('click', () => {
      if (state.isRecording) {
        stopRecording();
      } else {
        startRecording();
      }
    });

    submitTextBtn.addEventListener('click', submitTextAnswer);
    textAnswerInput.addEventListener('keydown', e => {
      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        submitTextAnswer();
      }
    });

    let spacePressed = false;
    window.addEventListener('keydown', e => {
      if (e.code === 'Space' && !state.isTextMode && document.activeElement !== textAnswerInput) {
        if (!spacePressed && !state.isRecording) {
          e.preventDefault();
          spacePressed = true;
          startRecording();
        }
      }
    });

    window.addEventListener('keyup', e => {
      if (e.code === 'Space' && spacePressed && state.isRecording) {
        e.preventDefault();
        spacePressed = false;
        stopRecording();
      }
    });

    finishEarlyBtn.addEventListener('click', () => {
      if (confirm('Mülakatı şu anki durumla bitirip karne raporunu almak istiyor musunuz?')) {
        finishInterview();
      }
    });

    restartBtn.addEventListener('click', () => {
      state.sessionId = null;
      state.currentTurn = 1;
      switchView('setup');
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    initSetupView();
    initEventListeners();
  });

})();
