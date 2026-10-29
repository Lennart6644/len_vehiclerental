const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'len_vehiclerental';
const $ = (id) => document.getElementById(id);

let L = {};
let currency = '$';
let data = null;
let rental = null;
let debts = [];
let debtTotal = 0;

const view = {
    open: false,
    cat: 1,
    vehicle: 0,
    duration: 2,
    insurance: 'none',
    extend: 2,
    tab: 'rent'
};

function t(key) {
    return L[key] !== undefined ? L[key] : key;
}

function fmt(text, ...args) {
    let i = 0;
    return String(text).replace(/%[sd]/g, () => args[i++]);
}

function money(value) {
    const code = L.lang === 'en' ? 'en-US' : 'de-DE';
    return currency + Math.floor(value).toLocaleString(code);
}

function formatTime(seconds) {
    const s = Math.max(0, Math.floor(seconds));
    return String(Math.floor(s / 60)).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0');
}

function post(name, body) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {})
    }).then((r) => r.json()).catch(() => ({}));
}

function applyLocale(locale) {
    L = locale || {};
    document.documentElement.lang = L.lang || 'de';
    document.querySelectorAll('[data-i18n]').forEach((el) => {
        el.textContent = t(el.dataset.i18n);
    });
}

function setVehicleImage(img, model) {
    img.dataset.stage = '0';
    img.style.display = '';
    img.onerror = function () {
        if (this.dataset.stage === '0') {
            this.dataset.stage = '1';
            this.src = `img/vehicles/${model}.png`;
        } else {
            this.style.display = 'none';
        }
    };
    img.src = `img/vehicles/${model}.webp`;
}

function shake(el) {
    el.classList.remove('shake');
    void el.offsetWidth;
    el.classList.add('shake');
}

function currentCategory() {
    return data.categories[view.cat - 1];
}

function currentVehicle() {
    const cat = currentCategory();
    return cat ? cat.vehicles[view.vehicle - 1] : null;
}

function renderChips(listId, selected, base, onPick) {
    const list = $(listId);
    list.innerHTML = '';
    data.durations.forEach((d, i) => {
        const btn = document.createElement('button');
        btn.className = 'chip' + (i + 1 === selected ? ' active' : '');
        const time = document.createElement('b');
        time.textContent = `${d.minutes} ${t('ui_minutes')}`;
        const price = document.createElement('span');
        price.textContent = money(base * d.multiplier);
        btn.append(time, price);
        btn.onclick = () => onPick(i + 1);
        list.appendChild(btn);
    });
}

function renderCategories() {
    const wrap = $('categories');
    wrap.innerHTML = '';
    data.categories.forEach((cat, i) => {
        const btn = document.createElement('button');
        btn.className = 'cat';
        btn.innerHTML = `<i class="fas ${cat.locked ? 'fa-lock' : 'fa-layer-group'}"></i>`;
        const label = document.createElement('span');
        label.textContent = cat.name;
        btn.appendChild(label);
        btn.onclick = () => selectCategory(i + 1);
        wrap.appendChild(btn);
    });
}

function selectCategory(index) {
    view.cat = index;
    view.vehicle = 0;
    const cat = currentCategory();
    $('category-title').textContent = cat.name;
    document.querySelectorAll('.cat').forEach((el, i) => el.classList.toggle('active', i + 1 === index));

    const grid = $('vehicle-grid');
    grid.innerHTML = '';
    cat.vehicles.forEach((veh, i) => {
        const card = document.createElement('div');
        card.className = 'vehicle-card';
        card.style.animationDelay = `${i * 40}ms`;

        const media = document.createElement('div');
        media.className = 'card-media';
        const icon = document.createElement('i');
        icon.className = 'fas fa-car-side media-icon';
        const img = document.createElement('img');
        img.alt = veh.label;
        setVehicleImage(img, veh.model);
        media.append(icon, img);

        const name = document.createElement('h3');
        name.textContent = veh.label;

        const price = document.createElement('p');
        price.className = 'card-price';
        const amount = document.createElement('b');
        amount.textContent = money(veh.basePrice);
        const suffix = document.createElement('span');
        suffix.textContent = ' ' + t('ui_fixed');
        price.append(amount, suffix);

        card.append(media, name, price);
        if (cat.locked) {
            const badge = document.createElement('span');
            badge.className = 'lock-badge';
            badge.innerHTML = '<i class="fas fa-lock"></i>';
            card.appendChild(badge);
        }
        card.onclick = () => selectVehicle(i + 1);
        grid.appendChild(card);
    });

    $('detail-empty').classList.remove('hidden');
    $('detail-body').classList.add('hidden');
}

function renderInsurances() {
    const list = $('insurance-list');
    list.innerHTML = '';
    data.insurances.forEach((ins) => {
        const btn = document.createElement('button');
        btn.className = 'choice' + (ins.key === view.insurance ? ' active' : '');
        const head = document.createElement('div');
        head.className = 'choice-head';
        const name = document.createElement('b');
        name.textContent = ins.label;
        const pct = document.createElement('span');
        pct.textContent = ins.percent > 0 ? `${Math.round(ins.percent * 100)}%` : '-';
        head.append(name, pct);
        const desc = document.createElement('small');
        let text = `${ins.desc} · ${fmt(t('ui_coverage'), Math.round(ins.coverage * 100) + '%')}`;
        if (ins.totalLoss) {
            text += ` · ${t('ui_totalloss_covered')}`;
        }
        desc.textContent = text;
        btn.append(head, desc);
        btn.onclick = () => {
            view.insurance = ins.key;
            renderInsurances();
            updateSummary();
        };
        list.appendChild(btn);
    });
}

function renderDurations() {
    const veh = currentVehicle();
    if (!veh) {
        return;
    }
    renderChips('duration-list', view.duration, veh.basePrice, (index) => {
        view.duration = index;
        renderDurations();
        updateSummary();
    });
}

function updateSummary() {
    const veh = currentVehicle();
    if (!veh) {
        return;
    }
    const duration = data.durations[view.duration - 1];
    const insurance = data.insurances.find((ins) => ins.key === view.insurance);
    const rent = Math.floor(veh.basePrice * duration.multiplier);
    const insuranceCost = Math.floor(veh.basePrice * insurance.percent);
    const deposit = Math.floor(veh.basePrice * data.deposit);
    $('d-rent').textContent = money(rent);
    $('d-insurance').textContent = insuranceCost > 0 ? money(insuranceCost) : t('ui_free');
    $('d-deposit').textContent = money(deposit);
    $('d-total').textContent = money(rent + insuranceCost + deposit);
}

function selectVehicle(index) {
    view.vehicle = index;
    const cat = currentCategory();
    const veh = currentVehicle();
    document.querySelectorAll('.vehicle-card').forEach((el, i) => el.classList.toggle('selected', i + 1 === index));
    $('detail-empty').classList.add('hidden');
    $('detail-body').classList.remove('hidden');
    $('d-name').textContent = veh.label;
    $('d-class').textContent = cat.name;
    $('d-base').textContent = money(veh.basePrice);
    $('d-km').textContent = money(veh.tempPrice);
    setVehicleImage($('d-img'), veh.model);
    $('lock-note').classList.toggle('hidden', !cat.locked);
    $('rent-btn').disabled = cat.locked;
    renderDurations();
    updateSummary();
    if (data.previewEnabled) {
        post('preview', { stationIndex: data.station.id, model: veh.model });
    }
}

function updateActiveTime() {
    if (!rental) {
        return;
    }
    const overdue = rental.status === 'overdue' || rental.expiresIn <= 0;
    const time = $('a-time');
    const status = $('a-status');
    time.textContent = formatTime(rental.expiresIn);
    time.classList.toggle('danger', overdue);
    status.textContent = overdue ? t('ui_status_overdue') : t('ui_status_active');
    status.classList.toggle('danger', overdue);
    $('extend-btn').disabled = overdue;
}

function renderActive() {
    const hasRental = !!rental;
    $('active-empty').classList.toggle('hidden', hasRental);
    $('active-body').classList.toggle('hidden', !hasRental);
    if (!hasRental) {
        return;
    }
    const insurance = data.insurances.find((ins) => ins.key === rental.insurance);
    $('a-vehicle').textContent = rental.label;
    $('a-plate').textContent = rental.plate;
    $('a-insurance').textContent = insurance ? insurance.label : '-';
    $('a-deposit').textContent = money(rental.deposit);
    $('a-damage').textContent = money(rental.damage);
    $('a-late').textContent = money(rental.lateFees);
    $('a-km').textContent = `${rental.km} km`;
    updateActiveTime();
    renderChips('extend-list', view.extend, rental.basePrice, (index) => {
        view.extend = index;
        renderActive();
    });
}

function renderDebts() {
    const list = $('debt-list');
    list.innerHTML = '';
    const hasDebts = debtTotal > 0;
    $('debt-empty').classList.toggle('hidden', hasDebts);
    $('debt-content').classList.toggle('hidden', !hasDebts);
    $('debt-total').textContent = money(debtTotal);
    debts.forEach((debt) => {
        const row = document.createElement('div');
        row.className = 'debt-row';
        const reason = document.createElement('span');
        reason.textContent = t('reason_' + debt.reason);
        const amount = document.createElement('b');
        amount.textContent = money(debt.amount);
        row.append(reason, amount);
        list.appendChild(row);
    });
}

function applyRental(value) {
    rental = value || null;
    $('tab-active').classList.toggle('hidden', !rental);
    if (!rental && view.tab === 'active') {
        showTab('rent');
    }
    renderActive();
}

function applyDebts(list, total) {
    debts = Array.isArray(list) ? list : [];
    debtTotal = total || 0;
    $('debt-badge').classList.toggle('hidden', debtTotal <= 0);
    renderDebts();
}

function showTab(tab) {
    view.tab = tab;
    document.querySelectorAll('.tab').forEach((el) => el.classList.toggle('active', el.dataset.tab === tab));
    ['rent', 'active', 'debts'].forEach((name) => $('view-' + name).classList.toggle('active', name === tab));
    $('details').classList.toggle('hidden', tab !== 'rent');
    $('categories').classList.toggle('hidden', tab !== 'rent');
    if (tab === 'active') {
        renderActive();
    }
    if (tab === 'debts') {
        renderDebts();
    }
}

function renderHud(msg) {
    $('hud').classList.toggle('hidden', !msg.active);
    if (!msg.active) {
        return;
    }
    const overdue = msg.status === 'overdue';
    $('hud-vehicle').textContent = msg.vehicle;
    $('hud-time').textContent = msg.time;
    $('hud-time').classList.toggle('danger', overdue);
    $('hud-insurance').textContent = msg.insurance;
    $('hud-status').textContent = overdue ? t('ui_status_overdue') : t('ui_status_active');
    $('hud-status').classList.toggle('danger', overdue);
}

function open(payload) {
    data = payload;
    currency = payload.currency || '$';
    applyLocale(payload.locale);
    view.open = true;
    view.cat = 1;
    view.vehicle = 0;
    view.duration = payload.defaultDuration || 2;
    view.extend = view.duration;
    view.insurance = 'none';
    $('app').classList.remove('hidden');
    $('station-name').textContent = payload.station.name;
    applyDebts(payload.debts, payload.debtTotal);
    applyRental(payload.rental);
    renderCategories();
    renderInsurances();
    selectCategory(1);
    showTab('rent');
}

function closeUI() {
    if (!view.open) {
        return;
    }
    view.open = false;
    $('app').classList.add('hidden');
    post('close');
}

window.addEventListener('message', (event) => {
    const msg = event.data || {};
    switch (msg.action) {
        case 'locale':
            applyLocale(msg.locale);
            break;
        case 'open':
            open(msg);
            break;
        case 'close':
            view.open = false;
            $('app').classList.add('hidden');
            break;
        case 'hud':
            renderHud(msg);
            break;
        case 'refresh':
            applyRental(msg.rental);
            applyDebts(msg.debts, msg.debtTotal);
            break;
    }
});

document.querySelectorAll('.tab').forEach((el) => {
    el.onclick = () => showTab(el.dataset.tab);
});

$('close-btn').onclick = closeUI;

$('rent-btn').onclick = () => {
    const cat = currentCategory();
    if (!view.vehicle || cat.locked) {
        shake($('rent-btn'));
        return;
    }
    post('rent', {
        stationIndex: data.station.id,
        categoryIndex: view.cat,
        vehicleIndex: view.vehicle,
        durationIndex: view.duration,
        insuranceKey: view.insurance
    });
};

$('extend-btn').onclick = () => {
    post('extend', { durationIndex: view.extend });
};

$('return-btn').onclick = () => {
    if (view.open) {
        view.open = false;
        $('app').classList.add('hidden');
    }
    post('returnVehicle');
};

$('pay-btn').onclick = () => {
    post('payDebts');
};

document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && view.open) {
        closeUI();
    }
});

setInterval(() => {
    if (!rental) {
        return;
    }
    rental.expiresIn -= 1;
    if (view.open && view.tab === 'active') {
        updateActiveTime();
    }
}, 1000);
