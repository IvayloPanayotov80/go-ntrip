(function(){
  const CHANNEL_COUNT = 8;
  const STORAGE_KEY = 'thermoConfig.v1';

  const defaultColors = [
    '#ef4444', '#f59e0b', '#22c55e', '#3b82f6',
    '#a855f7', '#06b6d4', '#eab308', '#f472b6'
  ];

  function createDefaultConfig(){
    const now = Date.now();
    return {
      channels: Array.from({length: CHANNEL_COUNT}, (_, i) => ({
        id: i,
        name: `Канал ${i+1}`,
        color: defaultColors[i % defaultColors.length],
        levelOn: 25,
        levelOff: 20,
        sensorAddress: '',
        forcedOn: false,
        // placeholders for future features
        lastUpdated: now
      })),
      wifi: [
        {ssid: '', pass: ''},
        {ssid: '', pass: ''},
        {ssid: '', pass: ''},
      ],
      settingsPassword: '',
    };
  }

  function loadConfig(){
    try{
      const raw = localStorage.getItem(STORAGE_KEY);
      if(!raw){
        const cfg = createDefaultConfig();
        localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
        return cfg;
      }
      const parsed = JSON.parse(raw);
      // ensure shape
      if(!Array.isArray(parsed.channels) || parsed.channels.length !== CHANNEL_COUNT){
        const fresh = createDefaultConfig();
        parsed.channels = fresh.channels;
      }
      if(!Array.isArray(parsed.wifi) || parsed.wifi.length !== 3){
        parsed.wifi = createDefaultConfig().wifi;
      }
      if(typeof parsed.settingsPassword !== 'string') parsed.settingsPassword = '';
      return parsed;
    }catch(e){
      console.warn('Failed to load config, resetting', e);
      const cfg = createDefaultConfig();
      localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
      return cfg;
    }
  }
  function saveConfig(cfg){
    localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
  }

  // DOM elements
  const channelsList = document.getElementById('channelsList');
  const settingsBtn = document.getElementById('settingsBtn');
  const resetZoomBtn = document.getElementById('resetZoomBtn');

  const passwordModal = document.getElementById('passwordModal');
  const pwdInput = document.getElementById('pwdInput');
  const pwdConfirm = document.getElementById('pwdConfirm');
  const pwdCancel = document.getElementById('pwdCancel');
  const pwdError = document.getElementById('pwdError');

  let config = loadConfig();

  // Render channel list
  function renderChannels(){
    channelsList.innerHTML = '';
    config.channels.forEach((ch, idx) => {
      const row = document.createElement('div');
      row.className = 'channel-row';

      const colorDot = document.createElement('div');
      colorDot.className = 'color-dot';
      colorDot.style.background = ch.color;

      const nameWrap = document.createElement('div');
      const name = document.createElement('div');
      name.className = 'channel-name';
      name.textContent = ch.name;
      const meta = document.createElement('div');
      meta.className = 'channel-meta';
      meta.textContent = `Ниво ON: ${ch.levelOn}°C • Ниво OFF: ${ch.levelOff}°C`;
      nameWrap.appendChild(name);
      nameWrap.appendChild(meta);

      const forcedBtn = document.createElement('button');
      forcedBtn.className = 'forced-toggle' + (ch.forcedOn ? ' active' : '');
      forcedBtn.title = ch.forcedOn ? 'Принудителен режим: ON' : 'Принудителен режим: OFF';
      forcedBtn.setAttribute('aria-pressed', ch.forcedOn ? 'true' : 'false');
      forcedBtn.style.outlineColor = ch.color;
      forcedBtn.innerHTML = ch.forcedOn ? getCheckSvg() : '';

      forcedBtn.addEventListener('click', () => {
        ch.forcedOn = !ch.forcedOn;
        forcedBtn.classList.toggle('active', ch.forcedOn);
        forcedBtn.setAttribute('aria-pressed', ch.forcedOn ? 'true' : 'false');
        forcedBtn.innerHTML = ch.forcedOn ? getCheckSvg() : '';
        saveConfig(config);
      });

      row.appendChild(colorDot);
      row.appendChild(nameWrap);
      row.appendChild(forcedBtn);
      channelsList.appendChild(row);
    });
  }

  function getCheckSvg(){
    return '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M5 13l4 4L19 7" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  }

  // Chart setup
  let chart;
  function generateSeedData(){
    const points = [];
    const now = Date.now();
    const start = now - 24*60*60*1000;
    const stepMs = 5 * 60 * 1000; // 5 минути
    for(let t = start; t <= now; t += stepMs){
      points.push(t);
    }
    // generate 8 series via random walk around 22-26C
    const datasets = config.channels.map((ch, idx) => {
      let val = 22 + (idx % 4);
      const data = points.map(ts => {
        const drift = (Math.random() - 0.5) * 0.2;
        val = Math.max(10, Math.min(40, val + drift));
        return {x: ts, y: Number(val.toFixed(2))};
      });
      return { chId: ch.id, color: ch.color, data };
    });
    return {points, datasets};
  }

  const seed = generateSeedData();

  function buildChart(){
    const ctx = document.getElementById('tempChart');
    const datasets = config.channels.map((ch, i) => ({
      label: ch.name,
      data: seed.datasets[i].data,
      borderColor: ch.color,
      backgroundColor: ch.color + '33',
      tension: 0.25,
      borderWidth: 2,
      pointRadius: 0,
    }));

    chart = new Chart(ctx, {
      type: 'line',
      data: { datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: 'nearest', intersect: false },
        parsing: false,
        scales: {
          x: {
            type: 'time',
            time: { tooltipFormat: 'dd.MM.yyyy HH:mm' },
            ticks: { color: '#c9cfdd' },
            grid: { color: 'rgba(255,255,255,0.06)' },
          },
          y: {
            title: { display: true, text: 'Температура (°C)' },
            ticks: { color: '#c9cfdd' },
            grid: { color: 'rgba(255,255,255,0.06)' },
            suggestedMin: 10,
            suggestedMax: 40
          }
        },
        plugins: {
          legend: { labels: { color: '#e6e8ee' } },
          zoom: {
            limits: { x: { minRange: 60 * 1000 } },
            pan: { enabled: true, mode: 'x' },
            zoom: {
              wheel: { enabled: true },
              pinch: { enabled: true },
              mode: 'x'
            }
          },
          tooltip: {
            callbacks: {
              label: (ctx) => `${ctx.dataset.label}: ${ctx.parsed.y} °C`
            }
          }
        }
      }
    });
  }

  function updateChartColorsAndLabels(){
    chart.data.datasets.forEach((ds, i) => {
      const ch = config.channels[i];
      ds.label = ch.name;
      ds.borderColor = ch.color;
      ds.backgroundColor = ch.color + '33';
    });
    chart.update();
  }

  // Live update simulation (optional)
  function startLiveUpdates(){
    setInterval(() => {
      const now = Date.now();
      chart.data.datasets.forEach((ds, i) => {
        const last = ds.data[ds.data.length - 1];
        let val = last ? last.y : 22;
        const drift = (Math.random() - 0.5) * 0.2;
        val = Math.max(10, Math.min(40, val + drift));
        ds.data.push({ x: now, y: Number(val.toFixed(2)) });
        // keep only last 24h
        const cutoff = now - 24*60*60*1000;
        while (ds.data.length && ds.data[0].x < cutoff) ds.data.shift();
      });
      chart.update('none');
    }, 60 * 1000);
  }

  function openSettings(){
    window.location.assign('/workspace/settings.html');
  }

  function showPasswordModal(){
    passwordModal.classList.remove('hidden');
    pwdError.classList.add('hidden');
    pwdInput.value = '';
    setTimeout(() => pwdInput.focus(), 50);
  }
  function hidePasswordModal(){
    passwordModal.classList.add('hidden');
  }

  // Event wiring
  settingsBtn.addEventListener('click', () => {
    const pass = config.settingsPassword || '';
    if(!pass){
      openSettings();
      return;
    }
    showPasswordModal();
  });
  pwdCancel.addEventListener('click', hidePasswordModal);
  pwdConfirm.addEventListener('click', () => {
    const pass = config.settingsPassword || '';
    if(pwdInput.value === pass){
      hidePasswordModal();
      openSettings();
    }else{
      pwdError.classList.remove('hidden');
    }
  });
  pwdInput.addEventListener('keydown', (e) => {
    if(e.key === 'Enter') pwdConfirm.click();
  });

  resetZoomBtn.addEventListener('click', () => {
    if(chart) chart.resetZoom();
  });

  // Init
  renderChannels();
  buildChart();
  updateChartColorsAndLabels();
  startLiveUpdates();

  // React to storage changes (e.g., after saving settings)
  window.addEventListener('storage', (e) => {
    if(e.key === STORAGE_KEY){
      config = loadConfig();
      renderChannels();
      updateChartColorsAndLabels();
    }
  });
})();