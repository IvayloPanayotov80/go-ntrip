(function(){
  const CHANNEL_COUNT = 8;
  const STORAGE_KEY = 'thermoConfig.v1';

  function createDefaultConfig(){
    return {
      channels: Array.from({length: CHANNEL_COUNT}, (_, i) => ({
        id: i,
        name: `Канал ${i+1}`,
        color: ['#ef4444','#f59e0b','#22c55e','#3b82f6','#a855f7','#06b6d4','#eab308','#f472b6'][i%8],
        levelOn: 25,
        levelOff: 20,
        sensorAddress: '',
        forcedOn: false,
      })),
      wifi: [ {ssid:'', pass:''}, {ssid:'', pass:''}, {ssid:'', pass:''} ],
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
      if(!Array.isArray(parsed.channels) || parsed.channels.length !== CHANNEL_COUNT){
        parsed.channels = createDefaultConfig().channels;
      }
      if(!Array.isArray(parsed.wifi) || parsed.wifi.length !== 3){
        parsed.wifi = createDefaultConfig().wifi;
      }
      if(typeof parsed.settingsPassword !== 'string') parsed.settingsPassword = '';
      return parsed;
    }catch(e){
      const cfg = createDefaultConfig();
      localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
      return cfg;
    }
  }

  function saveConfig(cfg){
    localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
  }

  const channelsForm = document.getElementById('channelsForm');
  const wifiForm = document.getElementById('wifiForm');
  const pwdInput = document.getElementById('settingsPassword');
  const saveBtn = document.getElementById('saveBtn');
  const resetBtn = document.getElementById('resetBtn');

  let config = loadConfig();

  function renderChannelCard(ch){
    const wrapper = document.createElement('div');
    wrapper.className = 'card-inner';

    wrapper.innerHTML = `
      <div class="form-row">
        <label>Име на канал</label>
        <input type="text" class="input name" value="${ch.name}" maxlength="32" />
      </div>
      <div class="row-2">
        <div class="form-row">
          <label>Ниво ON (°C)</label>
          <input type="number" class="input on" inputmode="decimal" step="0.1" min="-40" max="120" value="${ch.levelOn}" />
        </div>
        <div class="form-row">
          <label>Ниво OFF (°C)</label>
          <input type="number" class="input off" inputmode="decimal" step="0.1" min="-40" max="120" value="${ch.levelOff}" />
        </div>
      </div>
      <div class="row-2">
        <div class="form-row">
          <label>Цвят</label>
          <input type="color" class="input color" value="${ch.color}" />
        </div>
        <div class="form-row">
          <label>Адрес на сонда</label>
          <input type="text" class="input addr" value="${ch.sensorAddress}" placeholder="напр. 28-3C-01-..." />
        </div>
      </div>
      <div class="form-row">
        <label class="label">Принудителен режим</label>
        <select class="input forced">
          <option value="off" ${!ch.forcedOn ? 'selected' : ''}>OFF</option>
          <option value="on" ${ch.forcedOn ? 'selected' : ''}>ON</option>
        </select>
      </div>
    `;

    return wrapper;
  }

  function renderWifiCard(idx, w){
    const wrap = document.createElement('div');
    wrap.className = 'card-inner';
    wrap.innerHTML = `
      <div class="form-row">
        <label>Wi‑Fi ${idx+1} SSID</label>
        <input type="text" class="input ssid" value="${w.ssid}" maxlength="64" />
      </div>
      <div class="form-row">
        <label>Парола</label>
        <input type="password" class="input wpass" value="${w.pass}" maxlength="64" />
      </div>
    `;
    return wrap;
  }

  function render(){
    channelsForm.innerHTML = '';
    config.channels.forEach((ch) => channelsForm.appendChild(renderChannelCard(ch)));

    wifiForm.innerHTML = '';
    config.wifi.forEach((w, i) => wifiForm.appendChild(renderWifiCard(i, w)));

    pwdInput.value = config.settingsPassword || '';
  }

  function collect(){
    const newCfg = JSON.parse(JSON.stringify(config));

    const chCards = channelsForm.querySelectorAll('.card-inner');
    chCards.forEach((card, i) => {
      const name = card.querySelector('.name').value.trim() || `Канал ${i+1}`;
      const on = Number(card.querySelector('.on').value);
      const off = Number(card.querySelector('.off').value);
      const color = card.querySelector('.color').value;
      const addr = card.querySelector('.addr').value.trim();
      const forced = card.querySelector('.forced').value === 'on';

      newCfg.channels[i].name = name;
      newCfg.channels[i].levelOn = isFinite(on) ? on : newCfg.channels[i].levelOn;
      newCfg.channels[i].levelOff = isFinite(off) ? off : newCfg.channels[i].levelOff;
      newCfg.channels[i].color = color;
      newCfg.channels[i].sensorAddress = addr;
      newCfg.channels[i].forcedOn = forced;
    });

    const wifiCards = wifiForm.querySelectorAll('.card-inner');
    wifiCards.forEach((card, i) => {
      const ssid = card.querySelector('.ssid').value.trim();
      const pass = card.querySelector('.wpass').value;
      newCfg.wifi[i].ssid = ssid;
      newCfg.wifi[i].pass = pass;
    });

    const pwd = pwdInput.value;
    newCfg.settingsPassword = pwd || '';

    return newCfg;
  }

  saveBtn.addEventListener('click', () => {
    const next = collect();
    saveConfig(next);
    config = next;
    // notify other tabs
    window.dispatchEvent(new StorageEvent('storage', { key: STORAGE_KEY, newValue: JSON.stringify(next) }));
    saveBtn.textContent = 'Запазено ✓';
    setTimeout(() => saveBtn.textContent = 'Запази', 1200);
  });

  resetBtn.addEventListener('click', () => {
    const def = createDefaultConfig();
    saveConfig(def);
    config = def;
    render();
    window.dispatchEvent(new StorageEvent('storage', { key: STORAGE_KEY, newValue: JSON.stringify(def) }));
  });

  render();
})();