/* ==========================================
   QBCore Premium Inventory - NUI Controller
   NoPixel 4.0 Inspired Vanilla Web
   ========================================== */

let playerData = {
    inventory: {},
    maxWeight: 120000,
    currentWeight: 0
};

let otherData = {
    id: null,
    name: "Suelo",
    inventory: {},
    maxSlots: 40,
    invType: "drop"
};

let draggedItem = null;

window.addEventListener("mousemove", (e) => {
    if (!window._dragState) return;
    const dist = Math.abs(e.clientX - window._dragState.startX) + Math.abs(e.clientY - window._dragState.startY);
    if (dist > 4 && !window._dragState.active) {
        window._dragState.active = true;
        let ghost = document.getElementById("drag-ghost");
        if (!ghost) {
            ghost = document.createElement("div");
            ghost.id = "drag-ghost";
            ghost.style.cssText = "position: fixed; pointer-events: none; z-index: 999999; width: 68px; height: 68px; background: var(--bg-slot-hover); border: 2px solid var(--accent-color); border-radius: 10px; display: flex; align-items: center; justify-content: center; box-shadow: 0 10px 25px rgba(0,0,0,0.8); transform: translate(-50%, -50%);";
            document.body.appendChild(ghost);
        }
        const img = window._dragState.slotDiv.querySelector("img");
        ghost.innerHTML = img ? `<img src="${img.src}" style="max-width: 80%; max-height: 80%; pointer-events: none;">` : `<span>${window._dragState.item.name}</span>`;
        ghost.classList.remove("hidden");
    }

    if (window._dragState.active) {
        const ghost = document.getElementById("drag-ghost");
        if (ghost) {
            ghost.style.left = `${e.clientX}px`;
            ghost.style.top = `${e.clientY}px`;
        }
        document.querySelectorAll(".inv-slot.drag-over").forEach(el => el.classList.remove("drag-over"));
        const hovered = document.elementFromPoint(e.clientX, e.clientY);
        const targetSlotDiv = hovered ? hovered.closest(".inv-slot") : null;
        if (targetSlotDiv && targetSlotDiv !== window._dragState.slotDiv) {
            targetSlotDiv.classList.add("drag-over");
        }
    }
});

window.addEventListener("mouseup", (e) => {
    if (!window._dragState) return;
    const ds = window._dragState;
    window._dragState = null;

    const ghost = document.getElementById("drag-ghost");
    if (ghost) ghost.classList.add("hidden");
    document.querySelectorAll(".inv-slot.drag-over").forEach(el => el.classList.remove("drag-over"));

    if (ds.active) {
        const hovered = document.elementFromPoint(e.clientX, e.clientY);
        const targetSlotDiv = hovered ? hovered.closest(".inv-slot") : null;
        if (targetSlotDiv) {
            if (targetSlotDiv.dataset.slot === "backpack") {
                if (ds.fromInv === "player") {
                    postNUI("equipBackpack", { slot: ds.fromSlot });
                }
                return;
            }
            if (ds.slotDiv && ds.slotDiv.dataset.slot === "backpack") {
                if (targetSlotDiv.dataset.invType === "player") {
                    postNUI("unequipBackpack");
                }
                return;
            }

            const targetSlot = Number(targetSlotDiv.dataset.slot);
            const targetInv = targetSlotDiv.dataset.invType;
            const fromSlot = Number(ds.fromSlot);
            const fromInv = ds.fromInv;
            const amountElem = document.getElementById("item-amount");
            const amount = (amountElem && Number(amountElem.value)) ? Number(amountElem.value) : Number(ds.item.amount);

            if (!(fromSlot === targetSlot && fromInv === targetInv)) {
                moveItem(fromSlot, targetSlot, fromInv, targetInv, amount, ds.item);
            }
        }
    }
});

window.handleImgError = function(img, name) {
    const baseName = (name || 'box').replace(/\.[^/.]+$/, "");
    if (!img.dataset.triedWebp) {
        img.dataset.triedWebp = "1";
        img.src = `images/${baseName}.webp`;
    } else if (!img.dataset.triedPNG) {
        img.dataset.triedPNG = "1";
        img.src = `images/${baseName}.PNG`;
    } else if (!img.dataset.triedLower) {
        img.dataset.triedLower = "1";
        img.src = `images/${baseName.toLowerCase()}.png`;
    } else if (!img.dataset.triedLegacy) {
        img.dataset.triedLegacy = "1";
        img.src = `nui://qb-inventory/html/images/${baseName}.png`;
    } else {
        img.onerror = null;
        img.src = `images/box.png`;
    }
};
let selectedSlot = null; // { item, slotNumber, invType }
let activeTab = "inventory";
let currentTheme = localStorage.getItem("qb_theme") || "dark-glass";

const CraftingRecipes = [
    { id: 'bandage', label: 'Venda Médica', img: 'bandage.png', amount: 2, reqs: [{ item: 'cloth', count: 2, label: 'Tela' }] },
    { id: 'medkit', label: 'Botiquín de Primeros Auxilios', img: 'medkit.png', amount: 1, reqs: [{ item: 'bandage', count: 2, label: 'Venda Médica' }, { item: 'alcohol', count: 1, label: 'Alcohol' }] },
    { id: 'ammo-9', label: 'Caja de Munición 9mm', img: 'pistol_ammo.png', amount: 1, reqs: [{ item: 'metalscrap', count: 3, label: 'Chatarra' }, { item: 'gunpowder', count: 2, label: 'Pólvora' }] },
    { id: 'repairkit', label: 'Kit de Reparación Mecánico', img: 'repairkit.png', amount: 1, reqs: [{ item: 'iron', count: 4, label: 'Hierro' }, { item: 'steel', count: 2, label: 'Acero' }] },
    { id: 'lockpick', label: 'Ganzúa Básica', img: 'lockpick.png', amount: 1, reqs: [{ item: 'metalscrap', count: 2, label: 'Chatarra' }] },
    { id: 'armor', label: 'Chaleco Antibalas Táctico', img: 'armor.png', amount: 1, reqs: [{ item: 'kevlar', count: 5, label: 'Kevlar' }, { item: 'steel', count: 3, label: 'Acero' }] }
];

// Initialize Theme
document.body.setAttribute("data-theme", currentTheme);

document.addEventListener("DOMContentLoaded", () => {
    setupTabNavigation();
    setupThemeSelector();
    setupActionButtons();
    setupClothingToggles();
    setupAdminPanel();
    setupModalHandlers();
    renderCraftingRecipes();

    // Set initial theme card active state
    document.querySelectorAll(".theme-card").forEach(card => {
        if (card.dataset.themeName === currentTheme) {
            card.classList.add("active");
        } else {
            card.classList.remove("active");
        }
    });
});

/* NUI EVENT LISTENER */
window.addEventListener("message", (event) => {
    const action = event.data.action;

    if (action === "open" || action === "openInventory" || action === "setItems") {
        document.getElementById("app").classList.remove("hidden");
        
        if (event.data.payload || event.data.inventory) {
            playerData.inventory = event.data.payload || event.data.inventory || {};
        }
        
        if (event.data.maxWeight) {
            let mw = tonumberOr(event.data.maxWeight, 120);
            playerData.maxWeight = mw > 1000 ? mw : mw * 1000;
        }
        
        playerData.currentWeight = event.data.weight || calculateWeight(playerData.inventory);

        if (event.data.equippedBackpack !== undefined) {
            window.equippedBackpack = event.data.equippedBackpack;
        }


        if (event.data.otherInventory) {
            window.envContainer = event.data.otherInventory;
        } else if (!window.envContainer || window.envContainer.isBackpack) {
            window.envContainer = { id: null, name: "Suelo", inventory: {}, maxSlots: 40, invType: "drop" };
        }
        otherData = window.envContainer;
        document.getElementById("other-inventory-title").innerHTML = !otherData.id ? `<i class="fa-solid fa-cloud-arrow-down"></i> Suelo / Drops` : `<i class="fa-solid fa-box-open"></i> ${otherData.name}`;

        if (event.data.isAdmin !== undefined) {
            window.isPlayerAdmin = event.data.isAdmin;
        }
        if (window.isPlayerAdmin) {
            document.getElementById("admin-nav-btn").classList.remove("hidden");
        } else {
            document.getElementById("admin-nav-btn").classList.add("hidden");
        }

        updateWeightBar();
        renderAllGrids();
        switchTab("inventory");
    } else if (action === "openContainer") {
        document.getElementById("app").classList.remove("hidden");
        const isBp = event.data.isBackpack || (window.equippedBackpack && window.equippedBackpack.info && event.data.containerId === window.equippedBackpack.info.stashId);
        
        const cData = {
            id: event.data.containerId,
            name: event.data.title || (isBp ? "Mochila" : "Contenedor"),
            inventory: event.data.items || {},
            maxSlots: event.data.slots || (otherData && otherData.id === event.data.containerId ? otherData.maxSlots : (isBp ? 35 : 40)) || 40,
            maxWeight: event.data.maxWeight || (otherData && otherData.id === event.data.containerId ? otherData.maxWeight : 100.0) || 100.0,
            invType: event.data.invType || (isBp ? "stash" : "container"),
            isBackpack: isBp
        };

        if (isBp) {
            window.bpContainer = cData;
            otherData = window.bpContainer;
            switchTab("backpack");
        } else {
            window.envContainer = cData;
            otherData = window.envContainer;
            switchTab("inventory");
        }
        renderAllGrids();
    } else if (action === "openAdminPanel") {
        window.isPlayerAdmin = true;
        document.getElementById("app").classList.remove("hidden");
        document.getElementById("admin-nav-btn").classList.remove("hidden");
        if (!playerData.inventory) playerData.inventory = {};
        updateWeightBar();
        renderAllGrids();
        populateAdminUI(event.data.players, event.data.items);
        switchTab("admin");
    } else if (action === "close" || action === "closeInventory") {
        closeInventorySilently();
    } else if (action === "updateInventory") {
        if (event.data.inventory) playerData.inventory = event.data.inventory;
        playerData.currentWeight = event.data.weight || calculateWeight(playerData.inventory);
        if (event.data.otherInventory) {
            if (activeTab === "backpack" && window.bpContainer) {
                window.bpContainer.inventory = event.data.otherInventory.inventory || event.data.otherInventory;
                otherData = window.bpContainer;
            } else {
                otherData = event.data.otherInventory;
                window.envContainer = otherData;
            }
        }
        if (event.data.hasOwnProperty("equippedBackpack")) {
            window.equippedBackpack = (event.data.equippedBackpack && event.data.equippedBackpack !== false) ? event.data.equippedBackpack : null;
        }
        updateWeightBar();
        renderAllGrids();

    } else if (action === "closeSecondaryDrop") {
        if (otherData && (String(otherData.id) === String(event.data.dropId) || otherData.invType === "drop")) {
            window.envContainer = { id: null, name: "Suelo", inventory: {}, maxSlots: 40, invType: "drop" };
            if (activeTab !== "backpack") {
                otherData = window.envContainer;
                const titleEl = document.getElementById("other-inventory-title");
                if (titleEl) titleEl.innerHTML = `<i class="fa-solid fa-cloud-arrow-down"></i> Suelo / Drops`;
                renderAllGrids();
            }
        }
    } else if (action === "showHotbar") {
        if (event.data.items) playerData.inventory = event.data.items;
        renderStandaloneHotbar();
        const overlay = document.getElementById("standalone-hotbar-overlay");
        if (overlay) overlay.classList.remove("hidden");
    } else if (action === "hideHotbar") {
        const overlay = document.getElementById("standalone-hotbar-overlay");
        if (overlay) overlay.classList.add("hidden");
    } else if (action === "unequipBackpackUI") {
        window.equippedBackpack = null;
        renderEquippedBackpack();
    }
});

function tonumberOr(val, fallback) {
    const n = Number(val);
    return isNaN(n) ? fallback : n;
}

function postNUI(endpoint, data = {}) {
    const resName = (typeof GetParentResourceName === "function") ? GetParentResourceName() : (window.GetParentResourceName ? window.GetParentResourceName() : "qb-inventory");
    return fetch(`https://${resName}/${endpoint}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json; charset=UTF-8"
        },
        body: JSON.stringify(data)
    }).then(res => res.json()).catch(err => console.error("Error sending postNUI:", endpoint, err));
}

/* CLOSE INVENTORY */
function closeInventory() {
    closeInventorySilently();
    postNUI("close", {});
}

function closeInventorySilently() {
    document.getElementById("app").classList.add("hidden");
    closeModal("weapon-modal");
    closeModal("give-modal");
    selectedSlot = null;
    window.envContainer = null;
    window.bpContainer = null;
    otherData = { id: null, name: "Suelo", inventory: {}, maxSlots: 40, invType: "drop" };
}

document.getElementById("close-inv-btn").addEventListener("click", closeInventory);
document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" || e.key === "Tab") {
        if (!document.getElementById("app").classList.contains("hidden")) {
            closeInventory();
        }
    }
});

/* WEIGHT CALCULATION */
function calculateWeight(inv) {
    let weight = 0;
    Object.values(inv).forEach(item => {
        if (item) {
            let itemWeight = Number(item.weight);
            if (isNaN(itemWeight) || itemWeight < 0) itemWeight = 100;
            weight += itemWeight * (Number(item.amount) || 1);
        }
    });
    return weight;
}

function updateWeightBar() {
    const currentKg = (playerData.currentWeight / 1000).toFixed(1);
    const maxKg = (playerData.maxWeight / 1000).toFixed(1);
    const percentage = Math.min(100, Math.round((playerData.currentWeight / playerData.maxWeight) * 100));

    document.getElementById("weight-text").innerText = `${currentKg} / ${maxKg} kg`;
    document.getElementById("weight-bar-fill").style.width = `${percentage}%`;
}

function updateSecondaryGridVisibility() {
    const otherCol = document.getElementById("other-inventory-column");
    const wrapper = document.querySelector(".main-grids-wrapper");
    if (otherCol && wrapper) {
        const hasOtherItems = otherData && otherData.inventory && Object.keys(otherData.inventory).length > 0;
        if (!otherData.id && !hasOtherItems) {
            otherCol.style.display = "none";
            wrapper.classList.add("single-grid");
        } else {
            otherCol.style.display = "flex";
            wrapper.classList.remove("single-grid");
        }
    }
}

/* RENDERING GRIDS (HOTBAR + MAIN + OTHER) */
function renderAllGrids() {
    renderHotbar();
    renderPlayerGrid();
    renderOtherGrid();
    renderCraftingRecipes();
    highlightSelectedSlot();

    updateSecondaryGridVisibility();

    renderEquippedBackpack();

    const takeAllBtn = document.getElementById("btn-take-all");
    if (takeAllBtn) {
        if (otherData && otherData.id && (otherData.invType === "drop" || String(otherData.id).startsWith("drop-") || String(otherData.id).startsWith("death-"))) {
            takeAllBtn.classList.remove("hidden");
        } else {
            takeAllBtn.classList.add("hidden");
        }
    }
}

function renderEquippedBackpack() {
    const slotEl = document.getElementById("equipped-backpack-slot");
    const nameEl = document.getElementById("eq-bp-name");
    const infoEl = document.getElementById("eq-bp-info");
    const actionsEl = document.getElementById("eq-bp-actions");
    const navBtnEl = document.getElementById("backpack-nav-btn");

    if (!slotEl) return;
    slotEl.innerHTML = "";

    if (window.equippedBackpack && window.equippedBackpack.name) {
        const bp = window.equippedBackpack;
        if (nameEl) nameEl.innerText = bp.label || "Mochila";
        const mwKg = (bp.info && bp.info.maxWeight) ? (bp.info.maxWeight / 1000).toFixed(1) : "Extra";
        if (infoEl) infoEl.innerText = `Capacidad: ${mwKg} kg`;

        if (actionsEl) actionsEl.classList.remove("hidden");
        if (navBtnEl) navBtnEl.classList.remove("hidden");

        const imgName = bp.image || `${bp.name}.png`;
        const baseName = imgName.replace(/\.[^/.]+$/, "");
        const img = document.createElement("img");
        img.alt = bp.label || bp.name;
        img.className = "item-img";
        img.style.maxWidth = "80%";
        img.style.maxHeight = "80%";
        img.src = `images/${baseName}.png`;
        img.onerror = function() { window.handleImgError(this, baseName); };
        slotEl.appendChild(img);
    } else {
        if (nameEl) nameEl.innerText = "Sin Mochila";
        if (infoEl) infoEl.innerText = "Capacidad extra";
        if (actionsEl) actionsEl.classList.add("hidden");
        if (navBtnEl) navBtnEl.classList.add("hidden");

        slotEl.innerHTML = `<span class="empty-bp-text" style="font-size: 10px; color: rgba(255,255,255,0.3); text-align: center;"><i class="fa-solid fa-plus" style="font-size: 14px; display: block; margin-bottom: 2px;"></i>Equipar</span>`;
    }
}

function renderHotbar() {
    const hotbarGrid = document.getElementById("hotbar-grid");
    if (hotbarGrid) {
        hotbarGrid.innerHTML = "";
        for (let slot = 1; slot <= 5; slot++) {
            const item = getItemInSlot(playerData.inventory, slot);
            hotbarGrid.appendChild(createSlotElement(slot, item, "player"));
        }
    }

    const quickGiveGrid = document.getElementById("quick-give-grid");
    if (quickGiveGrid) {
        quickGiveGrid.innerHTML = "";
        const item6 = getItemInSlot(playerData.inventory, 6);
        const el6 = createSlotElement(6, item6, "player");
        el6.style.borderColor = "rgba(234, 179, 8, 0.6)";
        quickGiveGrid.appendChild(el6);
    }
}

function renderStandaloneHotbar() {
    const inv = playerData.inventory || {};
    const grid1 = document.getElementById("standalone-hotbar-grid");
    if (grid1) {
        grid1.innerHTML = "";
        for (let slot = 1; slot <= 5; slot++) {
            const item = getItemInSlot(inv, slot);
            grid1.appendChild(createStandaloneSlotElement(slot, item));
        }
    }
    const grid2 = document.getElementById("standalone-quickgive-grid");
    if (grid2) {
        grid2.innerHTML = "";
        const item6 = getItemInSlot(inv, 6);
        grid2.appendChild(createStandaloneSlotElement(6, item6, true));
    }
}

function createStandaloneSlotElement(slot, item, isGold = false) {
    const div = document.createElement("div");
    div.className = "inv-slot standalone-slot";
    if (isGold) div.style.borderColor = "rgba(234, 179, 8, 0.7)";
    
    let content = `<span class="slot-num" style="${isGold ? 'color:#facc15;' : ''}">${slot}</span>`;
    if (item && item.name) {
        const imgName = item.image || item.name + '.png';
        const baseName = imgName.replace(/\.[^/.]+$/, "");
        content += `<img src="images/${baseName}.png" class="slot-item-img item-img" onerror="handleImgError(this, '${item.name}')">`;
        if (item.amount > 1) {
            content += `<span class="slot-item-count">x${item.amount}</span>`;
        }
    }
    div.innerHTML = content;
    return div;
}

function renderPlayerGrid() {
    const playerGrid = document.getElementById("player-inventory-grid");
    if (!playerGrid) return;
    const oldScroll = playerGrid.scrollTop;
    playerGrid.innerHTML = "";
    const totalSlots = 35; // Slots 7 to 41

    for (let slot = 7; slot <= totalSlots + 6; slot++) {
        const item = getItemInSlot(playerData.inventory, slot);
        playerGrid.appendChild(createSlotElement(slot, item, "player"));
    }
    playerGrid.scrollTop = oldScroll;
}

function renderOtherGrid() {
    const otherGrid = document.getElementById("other-inventory-grid");
    if (!otherGrid) return;
    const oldScroll = otherGrid.scrollTop;
    otherGrid.innerHTML = "";
    const totalSlots = otherData.maxSlots || 40;

    const slotCountEl = document.getElementById("other-slot-count");
    if (slotCountEl) {
        if (otherData.maxWeight && Number(otherData.maxWeight) > 0) {
            let mwKg = tonumberOr(otherData.maxWeight, 50);
            if (mwKg > 1000) mwKg = mwKg / 1000;
            let currentOtherW = calculateWeight(otherData.inventory) / 1000;
            slotCountEl.innerHTML = `<span style="color:#00ffa6; font-weight:600;">${currentOtherW.toFixed(1)} / ${mwKg.toFixed(1)} kg</span> &nbsp;|&nbsp; ${totalSlots} slots`;
        } else {
            slotCountEl.innerText = `${totalSlots} slots`;
        }
    }

    for (let slot = 1; slot <= totalSlots; slot++) {
        const item = getItemInSlot(otherData.inventory, slot);
        otherGrid.appendChild(createSlotElement(slot, item, "other"));
    }
    otherGrid.scrollTop = oldScroll;
}


function getItemInSlot(inv, slot) {
    return Object.values(inv).find(i => i && Number(i.slot) === Number(slot)) || null;
}

/* SLOT ELEMENT CREATION */
function createSlotElement(slotNumber, item, invType) {
    const slotDiv = document.createElement("div");
    slotDiv.className = "inv-slot";
    slotDiv.dataset.slot = slotNumber;
    slotDiv.dataset.invType = invType;

    const slotNumSpan = document.createElement("span");
    slotNumSpan.className = "slot-number";
    slotNumSpan.style.pointerEvents = "none";
    slotNumSpan.innerText = slotNumber;
    slotDiv.appendChild(slotNumSpan);

    if (item) {
        slotDiv.dataset.itemName = item.name;
        slotDiv.draggable = false;
        slotDiv.addEventListener("mousedown", (e) => {
            if (e.button === 0) {
                window._dragState = { item, fromSlot: slotNumber, fromInv: invType, startX: e.clientX, startY: e.clientY, slotDiv, active: false };
            }
        });

        const img = document.createElement("img");
        img.className = "item-img";
        img.draggable = false;
        img.style.pointerEvents = "none";
        const imgName = item.image || item.name + '.png';
        const baseName = imgName.replace(/\.[^/.]+$/, "");
        img.src = `images/${baseName}.png`;
        img.onerror = function() { window.handleImgError(this, baseName); };
        slotDiv.appendChild(img);

        if (item.amount > 1 || (otherData.invType === "shop" && item.price)) {
            const badge = document.createElement("span");
            badge.className = "item-count-badge";
            badge.style.pointerEvents = "none";
            if (otherData.invType === "shop" && invType === "other") {
                badge.innerText = `$${item.price}`;
                badge.style.background = "rgba(46, 204, 113, 0.8)";
            } else {
                badge.innerText = `x${formatNumber(item.amount)}`;
            }
            slotDiv.appendChild(badge);
        }

        const label = document.createElement("span");
        label.className = "item-label";
        label.style.pointerEvents = "none";
        label.innerText = item.label || item.name;
        slotDiv.appendChild(label);

        // Click to Select
        slotDiv.addEventListener("click", () => {
            selectedSlot = { item, slotNumber, invType };
            highlightSelectedSlot();
        });

        // Double Click
        slotDiv.addEventListener("dblclick", () => {
            if (otherData.invType === "shop" && invType === "other") {
                const amount = Number(document.getElementById("item-amount").value) || 1;
                postNUI("BuyItem", { shop: otherData.id, item: item, amount: amount });
            } else if (item.type === "weapon" || String(item.name || '').toLowerCase().startsWith("weapon_")) {
                openWeaponInspection(item);
            } else if (invType === "player") {
                useItem(item);
            }
        });

        // Right Click Context Menu
        slotDiv.addEventListener("contextmenu", (e) => {
            e.preventDefault();
            e.stopPropagation();
            selectedSlot = { item, slotNumber, invType };
            highlightSelectedSlot();
            showContextMenu(e.clientX, e.clientY, item, invType);
        });

    }

    slotDiv.addEventListener("dragenter", (e) => {
        e.preventDefault();
    });

    slotDiv.addEventListener("dragover", (e) => {
        e.preventDefault();
        e.stopPropagation();
        e.dataTransfer.dropEffect = "move";
        if (!slotDiv.classList.contains("drag-over")) {
            slotDiv.classList.add("drag-over");
        }
    });

    slotDiv.addEventListener("dragleave", () => {
        slotDiv.classList.remove("drag-over");
    });

    slotDiv.addEventListener("drop", (e) => {
        e.preventDefault();
        e.stopPropagation();
        document.querySelectorAll(".inv-slot.drag-over").forEach(el => el.classList.remove("drag-over"));
        if (!draggedItem) {
            try {
                const dt = e.dataTransfer.getData("text/plain");
                if (dt) draggedItem = JSON.parse(dt);
            } catch (err) {}
        }
        if (!draggedItem) return;

        const targetSlot = Number(slotNumber);
        const fromSlot = Number(draggedItem.fromSlot);
        const targetInv = invType;
        const amountElem = document.getElementById("item-amount");
        const amount = (amountElem && Number(amountElem.value)) ? Number(amountElem.value) : Number(draggedItem.item.amount);

        if (fromSlot === targetSlot && draggedItem.fromInv === targetInv) return;

        moveItem(fromSlot, targetSlot, draggedItem.fromInv, targetInv, amount, draggedItem.item);
        draggedItem = null;
    });

    return slotDiv;
}

function highlightSelectedSlot() {
    document.querySelectorAll(".inv-slot").forEach(el => {
        el.style.borderColor = "";
        el.style.boxShadow = "";
    });
    if (selectedSlot) {
        const el = document.querySelector(`.inv-slot[data-slot="${selectedSlot.slotNumber}"][data-inv-type="${selectedSlot.invType}"]`);
        if (el) {
            el.style.borderColor = "#ffaa00";
            el.style.boxShadow = "0 0 10px rgba(255, 170, 0, 0.4)";
        }
    }
}

function formatNumber(num) {
    return num >= 1000 ? (num / 1000).toFixed(1) + 'k' : num;
}

/* ACTIONS */
function useItem(item) {
    postNUI("UseItem", { inventory: "player", item: item, slot: item.slot });
}

function moveItem(fromSlot, toSlot, fromInv, toInv, amount, item) {
    if (fromInv === "other" && otherData.invType === "shop") {
        postNUI("BuyItem", { shop: otherData.id, item: item, amount: amount });
        return;
    }

    if (fromInv === "player" && toInv === "player") {
        postNUI("SetItemSlot", { item: item, fromSlot: fromSlot, toSlot: toSlot, amount: amount });
    } else if (fromInv === "other" && toInv === "player") {
        postNUI("TakeFromSecondary", { containerId: otherData.id, invType: otherData.invType, item: item, toSlot: toSlot, amount: amount });
    } else if (fromInv === "player" && toInv === "other") {
        if (!otherData.id) {
            postNUI("DropItem", { item: item, amount: amount });
        } else {
            postNUI("PutInSecondary", { containerId: otherData.id, invType: otherData.invType, item: item, toSlot: toSlot, amount: amount });
        }
    } else if (fromInv === "other" && toInv === "other") {
        if (otherData.id) {
            postNUI("MoveInSecondary", { containerId: otherData.id, invType: otherData.invType, item: item, fromSlot: fromSlot, toSlot: toSlot });
        }
    }
}

function setupActionButtons() {
    document.getElementById("btn-use").addEventListener("click", () => {
        if (selectedSlot && selectedSlot.invType === "player") {
            useItem(selectedSlot.item);
        }
    });

    document.getElementById("btn-drop").addEventListener("click", () => {
        if (selectedSlot && selectedSlot.invType === "player") {
            const amount = Number(document.getElementById("item-amount").value) || selectedSlot.item.amount;
            postNUI("DropItem", { item: selectedSlot.item, amount: amount });
            selectedSlot = null;
        }
    });

    document.getElementById("btn-split").addEventListener("click", () => {
        if (selectedSlot && selectedSlot.invType === "player") {
            const inputVal = Number(document.getElementById("item-amount").value);
            const amount = (inputVal > 0) ? inputVal : Math.max(1, Math.floor(selectedSlot.item.amount / 2));
            postNUI("SplitItem", { item: selectedSlot.item, amount: amount });
            selectedSlot = null;
        }
    });

    document.getElementById("btn-give").addEventListener("click", () => {
        if (selectedSlot && selectedSlot.invType === "player") {
            openModal("give-modal");
        }
    });

    const takeAllBtn = document.getElementById("btn-take-all");
    if (takeAllBtn) {
        takeAllBtn.addEventListener("click", () => {
            if (otherData && otherData.id) {
                postNUI("takeAllFromDrop", { containerId: otherData.id });
            }
        });
    }

    const btnOpenBp = document.getElementById("btn-open-equipped-bp");
    if (btnOpenBp) {
        btnOpenBp.addEventListener("click", () => {
            postNUI("openEquippedBackpack");
        });
    }

    const btnUnequipBp = document.getElementById("btn-unequip-equipped-bp");
    if (btnUnequipBp) {
        btnUnequipBp.addEventListener("click", () => {
            if (window.equippedBackpack) {
                postNUI("unequipBackpack");
            }
        });
    }

    const navBpBtn = document.getElementById("backpack-nav-btn");
    if (navBpBtn) {
        navBpBtn.addEventListener("click", () => {
            postNUI("openEquippedBackpack");
        });
    }

    const eqBpSlot = document.getElementById("equipped-backpack-slot");
    if (eqBpSlot) {
        eqBpSlot.addEventListener("dblclick", () => {
            if (window.equippedBackpack) {
                postNUI("unequipBackpack");
            }
        });
    }
}


/* CRAFTING RECIPES RENDER */
function canCraftRecipe(rec) {
    if (!playerData || !playerData.inventory) return false;
    const invItems = Object.values(playerData.inventory);
    for (let req of (rec.reqs || [])) {
        let reqName = req.item;
        let reqCount = req.count;
        let foundAmount = 0;
        for (let item of invItems) {
            if (item && item.name === reqName) {
                foundAmount += (Number(item.amount) || 1);
            }
        }
        if (foundAmount < reqCount) return false;
    }
    return true;
}

function renderCraftingRecipes() {
    const list = document.getElementById("recipes-list");
    if (!list) return;
    list.innerHTML = "";

    CraftingRecipes.forEach(rec => {
        const canCraft = canCraftRecipe(rec);
        const dotColor = canCraft ? "#4cd137" : "#555555";
        const dotShadow = canCraft ? "0 0 8px #4cd137" : "none";

        const row = document.createElement("div");
        row.className = "recipe-item";
        row.style.cssText = "display: flex; align-items: center; justify-content: space-between; padding: 10px; background: rgba(255,255,255,0.03); border-radius: 8px; cursor: pointer; margin-bottom: 8px; border: 1px solid rgba(255,255,255,0.05); transition: 0.2s;";
        row.innerHTML = `
            <div style="display: flex; align-items: center; gap: 12px;">
                <img src="images/${rec.img.replace(/\.[^/.]+$/, '')}.png" onerror="window.handleImgError(this, '${rec.img}')" style="width: 36px; height: 36px; object-fit: contain;">
                <div>
                    <h4 style="font-size: 14px; margin: 0; color: #fff;">${rec.label}</h4>
                    <span style="font-size: 12px; color: #aaa;">Produce x${rec.amount}</span>
                </div>
            </div>
            <div style="width: 14px; height: 14px; border-radius: 50%; background: ${dotColor}; box-shadow: ${dotShadow}; margin-right: 8px;" title="${canCraft ? 'Materiales suficientes' : 'Faltan materiales'}"></div>
        `;

        row.addEventListener("mouseenter", () => row.style.background = "rgba(255,255,255,0.08)");
        row.addEventListener("mouseleave", () => row.style.background = "rgba(255,255,255,0.03)");
        row.addEventListener("click", () => selectRecipe(rec));
        list.appendChild(row);
    });
}

function selectRecipe(rec) {
    const details = document.getElementById("recipe-details");
    let reqHtml = rec.reqs.map(r => `
        <div style="display: flex; justify-content: space-between; padding: 8px; background: rgba(0,0,0,0.3); border-radius: 6px; margin-bottom: 6px;">
            <span>${r.label || r.item}</span>
            <strong style="color: #ffaa00;">x${r.count}</strong>
        </div>
    `).join('');

    details.innerHTML = `
        <div style="text-align: center; margin-bottom: 20px;">
            <img src="images/${rec.img.replace(/\.[^/.]+$/, '')}.png" onerror="window.handleImgError(this, '${rec.img}')" style="width: 80px; height: 80px; object-fit: contain;">
            <h3 style="margin: 10px 0 5px 0;">${rec.label}</h3>
            <span style="color: #4cd137; font-size: 13px;">Cantidad producida: x${rec.amount}</span>
        </div>
        <h4 style="margin-bottom: 10px; font-size: 14px; color: #ccc;">Materiales Requeridos:</h4>
        <div style="margin-bottom: 20px;">${reqHtml}</div>
        <button id="craft-now-btn" class="action-btn use-btn" style="width: 100%; padding: 12px; font-size: 15px;"><i class="fa-solid fa-hammer"></i> Fabricar Ahora</button>
    `;

    document.getElementById("craft-now-btn").addEventListener("click", () => {
        postNUI("craftItem", { item: rec.id, count: 1 });
    });
}

/* NAVIGATION TABS */
function setupTabNavigation() {
    document.querySelectorAll(".nav-btn").forEach(btn => {
        btn.addEventListener("click", () => {
            switchTab(btn.dataset.tab);
        });
    });
}

function switchTab(tabId) {
    document.querySelectorAll(".tab-content").forEach(t => t.classList.remove("active"));
    document.querySelectorAll(".nav-btn").forEach(b => b.classList.remove("active"));
    
    const targetTab = document.getElementById(`tab-${tabId}`);
    if (targetTab) targetTab.classList.add("active");
    if (tabId === "inventory" || tabId === "backpack") {
        const invTab = document.getElementById("tab-inventory");
        if (invTab) invTab.classList.add("active");

        if (tabId === "inventory") {
            otherData = window.envContainer || { id: null, name: "Suelo", inventory: {}, maxSlots: 40, invType: "drop" };
            const titleEl = document.getElementById("other-inventory-title");
            if (titleEl) titleEl.innerHTML = !otherData.id ? `<i class="fa-solid fa-cloud-arrow-down"></i> Suelo / Drops` : `<i class="fa-solid fa-box-open"></i> ${otherData.name || 'Contenedor'}`;
            renderOtherGrid();
            updateSecondaryGridVisibility();
        } else if (tabId === "backpack") {
            if (window.bpContainer) {
                otherData = window.bpContainer;
                const titleEl = document.getElementById("other-inventory-title");
                if (titleEl) {
                    const bpImg = window.equippedBackpack ? (window.equippedBackpack.image || window.equippedBackpack.name + '.png').replace(/\.[^/.]+$/, "") : 'backpack';
                    titleEl.innerHTML = `<img src="images/${bpImg}.png" style="width: 20px; height: 20px; object-fit: contain; vertical-align: middle; margin-right: 6px;"> ${otherData.name || 'Mochila'}`;
                }
                renderOtherGrid();
                updateSecondaryGridVisibility();
            }
        }
    }
    if (tabId === "admin" && !window.isPlayerAdmin) {
        switchTab("inventory");
        return;
    }
    
    const targetBtn = document.querySelector(`.nav-btn[data-tab="${tabId}"]`);
    if (targetBtn) targetBtn.classList.add("active");
    
    const app = document.getElementById("app");
    if (tabId === "clothing") {
        app.classList.add("side-mode");
    } else {
        app.classList.remove("side-mode");
    }

    if (tabId === "admin" && !window._adminLoaded && window.isPlayerAdmin) {
        postNUI("GetAdminData", {}).then(data => {
            if (data && data.players) populateAdminUI(data.players, data.items);
        }).catch(() => {});
    }
    
    activeTab = tabId;
}

/* THEMES SELECTOR */
function setupThemeSelector() {
    document.querySelectorAll(".theme-card").forEach(card => {
        card.addEventListener("click", () => {
            const themeName = card.dataset.themeName;
            document.body.setAttribute("data-theme", themeName);
            localStorage.setItem("qb_theme", themeName);

            document.querySelectorAll(".theme-card").forEach(c => c.classList.remove("active"));
            card.classList.add("active");
        });
    });
}

/* CLOTHING TOGGLES */
function setupClothingToggles() {
    document.querySelectorAll(".clothing-btn").forEach(btn => {
        btn.addEventListener("click", () => {
            const type = btn.dataset.clothing;
            postNUI("toggleClothing", { type: type, slot: type });
        });
    });
}

/* WEAPON INSPECTION MODAL */
function openWeaponInspection(weapon) {
    if (!weapon) return;
    document.getElementById("weapon-inspect-title").innerHTML = `<i class="fa-solid fa-crosshairs"></i> ${weapon.label || weapon.name}`;
    
    const wImg = document.getElementById("weapon-inspect-img");
    if (wImg) {
        const imgName = weapon.image || weapon.name + '.png';
        const baseName = imgName.replace(/\.[^/.]+$/, "");
        wImg.dataset.triedWebp = ""; wImg.dataset.triedPNG = ""; wImg.dataset.triedLegacy = ""; wImg.dataset.triedLegacyWebp = "";
        wImg.src = `images/${baseName}.png`;
        wImg.onerror = function() { window.handleImgError(this, baseName); };
    }

    const ammoEl = document.getElementById("weapon-ammo-count");
    if (ammoEl) ammoEl.innerText = `${weapon.info?.ammo || 0} disparos`;

    const dmgEl = document.getElementById("weapon-damage-stat");
    if (dmgEl) {
        const quality = (weapon.info && weapon.info.quality !== undefined) ? `${Math.round(weapon.info.quality)}% Óptimo` : "100% Óptimo";
        dmgEl.innerText = quality;
    }

    const serEl = document.getElementById("weapon-serial-stat");
    if (serEl) serEl.innerText = weapon.info?.serie || "N/A - ILEGAL";

    const attachList = document.getElementById("attachments-list");
    if (attachList) {
        attachList.innerHTML = "";
        const attachments = Array.isArray(weapon.info?.attachments) ? weapon.info.attachments : Object.values(weapon.info?.attachments || {});

        if (attachments.length > 0) {
            const header = document.createElement("div");
            header.style.cssText = "font-size:12px; color:#00ffa6; margin-bottom:8px; font-weight:600;";
            header.innerHTML = '<i class="fa-solid fa-check-double"></i> INSTALADOS ACTUALMENTE:';
            attachList.appendChild(header);

            attachments.forEach(att => {
                if (!att) return;
                const compVal = typeof att === 'object' ? (att.component || att.id || att.name) : att;
                let compLabel = (typeof att === 'object' && att.label && att.label !== 'Accesorio Táctico' && att.label !== 'Componente Táctico') ? att.label : null;

                if (!compLabel) {
                    const numVal = Number(compVal);
                    const knownHashes = {
                        1709866683: 'Silenciador Táctico',
                        316253668: 'Linterna Táctica',
                        899381934: 'Linterna Táctica',
                        [-2218447396]: 'Cargador Ampliado',
                        [1593441988]: 'Silenciador Táctico'
                    };
                    if (knownHashes[numVal]) {
                        compLabel = knownHashes[numVal];
                    } else {
                        const strVal = String((typeof att === 'object' && att.item) || compVal || '').toLowerCase();
                        if (strVal.includes('camo')) compLabel = 'Camuflaje de Arma';
                        else if (strVal.includes('tint') || strVal.includes('luxe') || strVal.includes('finish')) compLabel = 'Acabado de Lujo';
                        else if (strVal.includes('supp')) compLabel = 'Silenciador Táctico';
                        else if (strVal.includes('flsh')) compLabel = 'Linterna Táctica';
                        else if (strVal.includes('clip') || strVal.includes('mag') || strVal.includes('drum')) compLabel = 'Cargador Ampliado';
                        else if (strVal.includes('scope') || strVal.includes('sight') || strVal.includes('holo')) compLabel = 'Mira Telescópica';
                        else if (strVal.includes('grip')) compLabel = 'Empuñadura Táctica';
                        else if (strVal.includes('muzzle') || strVal.includes('comp') || strVal.includes('brake')) compLabel = 'Compensador Táctico';
                        else if (strVal.includes('barrel')) compLabel = 'Cañón Pesado';
                        else compLabel = 'Modificación Táctica';
                    }
                }

                const row = document.createElement("div");
                row.className = "attachment-row";
                row.style.cssText = "border: 1px solid rgba(0,255,166,0.3); background: rgba(0,255,166,0.05); margin-bottom: 6px;";
                row.innerHTML = `
                    <span style="color:#fff;"><i class="fa-solid fa-microchip" style="color:#00ffa6;"></i> ${compLabel}</span>
                    <button class="action-btn drop-btn" style="padding: 6px 12px; font-size: 11px; background: #ff3b3b; color: #fff;">
                        Desacoplar
                    </button>
                `;
                row.querySelector("button").addEventListener("click", (e) => {
                    e.stopPropagation();
                    postNUI("modifyWeapon", {
                        weaponName: weapon.name,
                        componentName: String(compVal),
                        componentHash: compVal,
                        install: false,
                        slot: weapon.slot
                    });
                    closeModal("weapon-modal");
                });
                attachList.appendChild(row);
            });
        } else {
            const noAtt = document.createElement("div");
            noAtt.style.cssText = "font-size:12px; color:#aaa; padding:10px; text-align:center; background:rgba(255,255,255,0.03); border-radius:6px; margin-bottom:10px;";
            noAtt.innerHTML = "No hay accesorios avanzados montados en este arma.";
            attachList.appendChild(noAtt);
        }

        const infoBench = document.createElement("div");
        infoBench.style.cssText = "margin-top:12px; font-size:11px; color:#00d9ff; padding:8px; background:rgba(0,217,255,0.1); border:1px dashed rgba(0,217,255,0.3); border-radius:6px;";
        infoBench.innerHTML = '<i class="fa-solid fa-info-circle"></i> Para ensamblar accesorios o camuflajes, utiliza la <strong>Mesa de Armero</strong>.';
        attachList.appendChild(infoBench);
    }

    openModal("weapon-modal");
}


function openModal(id) {
    const modal = document.getElementById(id);
    if (modal) {
        modal.classList.remove("hidden");
        const invContainer = document.querySelector(".inventory-container");
        if (invContainer) invContainer.style.pointerEvents = "none";
    }
}

function closeModal(id) {
    const modal = document.getElementById(id);
    if (modal) {
        modal.classList.add("hidden");
        setTimeout(() => {
            const wModal = document.getElementById("weapon-modal");
            const gModal = document.getElementById("give-modal");
            if ((!wModal || wModal.classList.contains("hidden")) && (!gModal || gModal.classList.contains("hidden"))) {
                const invContainer = document.querySelector(".inventory-container");
                if (invContainer) invContainer.style.pointerEvents = "auto";
            }
        }, 50);
    }
}

function setupModalHandlers() {
    document.querySelectorAll(".modal-overlay").forEach(overlay => {
        overlay.addEventListener("click", (e) => {
            if (e.target === overlay) closeModal(overlay.id);
            e.stopPropagation();
        });
        overlay.addEventListener("mousedown", (e) => e.stopPropagation());
        overlay.addEventListener("mouseup", (e) => e.stopPropagation());
    });

    document.querySelectorAll(".modal-box").forEach(box => {
        box.addEventListener("click", (e) => e.stopPropagation());
        box.addEventListener("mousedown", (e) => e.stopPropagation());
        box.addEventListener("mouseup", (e) => e.stopPropagation());
    });

    document.getElementById("close-weapon-modal").addEventListener("click", (e) => {
        e.stopPropagation();
        closeModal("weapon-modal");
    });

    document.getElementById("close-give-modal").addEventListener("click", (e) => {
        e.stopPropagation();
        closeModal("give-modal");
    });

    document.getElementById("confirm-give-btn").addEventListener("click", (e) => {
        e.stopPropagation();
        if (selectedSlot && selectedSlot.invType === "player") {
            const targetId = document.getElementById("give-target-id").value;
            const amount = Number(document.getElementById("item-amount").value) || selectedSlot.item.amount;
            if (targetId) {
                postNUI("GiveItem", { targetId: targetId, item: selectedSlot.item, amount: amount });
                closeModal("give-modal");
                selectedSlot = null;
            }
        }
    });

    const ctxMenuElement = document.getElementById("item-context-menu");
    if (ctxMenuElement) {
        ctxMenuElement.addEventListener("mousedown", (e) => e.stopPropagation());
        ctxMenuElement.addEventListener("mouseup", (e) => e.stopPropagation());
    }

    document.addEventListener("click", () => {
        const ctxMenu = document.getElementById("item-context-menu");
        if (ctxMenu) ctxMenu.classList.add("hidden");
    });

    const ctxUse = document.getElementById("ctx-use");
    if (ctxUse) {
        ctxUse.addEventListener("click", (e) => {
            e.stopPropagation();
            const ctxMenu = document.getElementById("item-context-menu");
            if (ctxMenu) ctxMenu.classList.add("hidden");
            if (selectedSlot) {
                if (selectedSlot.invType === "other" && otherData.invType === "shop") {
                    const amount = Number(document.getElementById("item-amount").value) || 1;
                    postNUI("BuyItem", { shop: otherData.id, item: selectedSlot.item, amount: amount });
                } else if (selectedSlot.invType === "player" || selectedSlot.invType === "hotbar") {
                    useItem(selectedSlot.item);
                }
            }
        });
    }

    const ctxGive = document.getElementById("ctx-give");
    if (ctxGive) {
        ctxGive.addEventListener("click", (e) => {
            e.stopPropagation();
            const ctxMenu = document.getElementById("item-context-menu");
            if (ctxMenu) ctxMenu.classList.add("hidden");
            if (selectedSlot && (selectedSlot.invType === "player" || selectedSlot.invType === "hotbar")) {
                openModal("give-modal");
            }
        });
    }

    const ctxSplit = document.getElementById("ctx-split");
    if (ctxSplit) {
        ctxSplit.addEventListener("click", (e) => {
            e.stopPropagation();
            const ctxMenu = document.getElementById("item-context-menu");
            if (ctxMenu) ctxMenu.classList.add("hidden");
            if (selectedSlot && (selectedSlot.invType === "player" || selectedSlot.invType === "hotbar" || selectedSlot.invType === "other")) {
                const inputVal = Number(document.getElementById("item-amount").value);
                const amount = (inputVal > 0) ? inputVal : Math.max(1, Math.floor(selectedSlot.item.amount / 2));
                postNUI("SplitItem", { item: selectedSlot.item, amount: amount });
                selectedSlot = null;
            }
        });
    }

    const ctxDrop = document.getElementById("ctx-drop");
    if (ctxDrop) {
        ctxDrop.addEventListener("click", (e) => {
            e.stopPropagation();
            const ctxMenu = document.getElementById("item-context-menu");
            if (ctxMenu) ctxMenu.classList.add("hidden");
            if (selectedSlot && (selectedSlot.invType === "player" || selectedSlot.invType === "hotbar")) {
                const amount = Number(document.getElementById("item-amount").value) || selectedSlot.item.amount;
                postNUI("DropItem", { item: selectedSlot.item, amount: amount });
                selectedSlot = null;
            }
        });
    }

    const ctxInspect = document.getElementById("ctx-inspect");
    if (ctxInspect) {
        ctxInspect.addEventListener("click", (e) => {
            e.stopPropagation();
            const ctxMenu = document.getElementById("item-context-menu");
            if (ctxMenu) ctxMenu.classList.add("hidden");
            if (selectedSlot && selectedSlot.item) {
                openWeaponInspection(selectedSlot.item);
            }
        });
    }
}

/* CONTEXT MENU */
function showContextMenu(x, y, item, invType) {
    const ctxMenu = document.getElementById("item-context-menu");
    if (!ctxMenu) return;

    const inspectBtn = document.getElementById("ctx-inspect");
    if (inspectBtn) {
        if (item.type === "weapon" || String(item.name || '').toLowerCase().startsWith("weapon_")) {
            inspectBtn.classList.remove("hidden");
        } else {
            inspectBtn.classList.add("hidden");
        }
    }

    const giveBtn = document.getElementById("ctx-give");
    const useBtn = document.getElementById("ctx-use");
    const dropBtn = document.getElementById("ctx-drop");
    if (invType === "player" || invType === "hotbar") {
        if (giveBtn) giveBtn.classList.remove("hidden");
        if (useBtn) useBtn.classList.remove("hidden");
        if (dropBtn) dropBtn.classList.remove("hidden");
    } else {
        if (giveBtn) giveBtn.classList.add("hidden");
        if (useBtn && otherData.invType !== "shop") useBtn.classList.add("hidden");
        if (dropBtn) dropBtn.classList.add("hidden");
    }

    ctxMenu.classList.remove("hidden");
    const rect = ctxMenu.getBoundingClientRect();
    let left = x;
    let top = y;
    if (left + rect.width > window.innerWidth) left = window.innerWidth - rect.width - 10;
    if (top + rect.height > window.innerHeight) top = window.innerHeight - rect.height - 10;

    ctxMenu.style.left = `${left}px`;
    ctxMenu.style.top = `${top}px`;
}


/* ADMIN PANEL */
function populateAdminUI(players, items) {
    window._adminLoaded = true;
    const playerSelect = document.getElementById("admin-target-player");
    if (playerSelect && players) {
        playerSelect.innerHTML = '<option value="">Mi inventario (Propio)</option>';
        const playersArray = Array.isArray(players) ? players : Object.values(players || {});
        playersArray.forEach(p => {
            if (!p) return;
            const opt = document.createElement("option");
            opt.value = p.id;
            opt.innerText = `[ID: ${p.id}] ${p.name}`;
            playerSelect.appendChild(opt);
        });
    }

    const itemsList = document.getElementById("admin-items-list");
    if (itemsList && items) {
        const itemsArray = Array.isArray(items) ? items : Object.values(items || {});
        window._allAdminItems = itemsArray;
        renderAdminItemsList(itemsArray);
    }
}

function renderAdminItemsList(items) {
    const itemsList = document.getElementById("admin-items-list");
    if (!itemsList) return;
    itemsList.innerHTML = "";
    const itemsArray = Array.isArray(items) ? items : Object.values(items || {});
    itemsArray.forEach(item => {
        if (!item) return;
        const card = document.createElement("div");
        card.className = "admin-item-card";
        const imgName = item.image || item.name + '.png';
        const baseName = imgName.replace(/\.[^/.]+$/, "");
        card.innerHTML = `<img src="images/${baseName}.png" onerror="handleImgError(this, '${item.name}')"><span>${item.label || item.name}</span>`;
        card.addEventListener("click", () => {
            document.querySelectorAll(".admin-item-card").forEach(c => c.classList.remove("selected"));
            card.classList.add("selected");
            const nameInput = document.getElementById("admin-item-name");
            if (nameInput) nameInput.value = item.name;
        });
        itemsList.appendChild(card);
    });
}

function setupAdminPanel() {
    const searchInput = document.getElementById("admin-item-search");
    if (searchInput) {
        searchInput.addEventListener("input", (e) => {
            const q = e.target.value.toLowerCase();
            if (!window._allAdminItems) return;
            const filtered = window._allAdminItems.filter(i => i && (String(i.name || '').toLowerCase().includes(q) || String(i.label || '').toLowerCase().includes(q)));
            renderAdminItemsList(filtered);
        });
    }

    const spawnBtn = document.getElementById("admin-spawn-btn");
    if (spawnBtn) {
        spawnBtn.addEventListener("click", () => {
            const item = document.getElementById("admin-item-name").value;
            const amount = document.getElementById("admin-item-amount").value || 1;
            const targetId = document.getElementById("admin-target-player").value || 0;
            if (item) {
                postNUI("AdminGiveItem", { itemName: item, amount: Number(amount), targetId: Number(targetId) });
            }
        });
    }

    const clearBtn = document.getElementById("admin-clear-inv-btn");
    if (clearBtn) {
        clearBtn.addEventListener("click", () => {
            const targetId = document.getElementById("admin-target-player").value || 0;
            postNUI("AdminClearInventory", { targetId: Number(targetId) });
        });
    }

    const inspectBtn = document.getElementById("admin-inspect-inv-btn");
    if (inspectBtn) {
        inspectBtn.addEventListener("click", () => {
            const targetId = document.getElementById("admin-target-player").value;
            if (!targetId) {
                return;
            }
            postNUI("AdminInspectPlayer", { targetId: Number(targetId) });
        });
    }
}
