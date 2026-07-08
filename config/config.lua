Config = {
    Framework = 'qbcore', -- 'qbcore', 'qbox', 'standalone'
    UseTarget = GetConvar('UseTarget', 'false') == 'true',

    MaxWeight = 120000,
    MaxSlots = 40,

    ContainerWeights = {
        player = 120.0,
        backpack = 20.0,
        stash = 1000.0,
        trunk = 150.0,
        glovebox = 15.0,
        drop = 50.0
    },

    StashSize = {
        maxweight = 2000000,
        slots = 100
    },

    DropSize = {
        maxweight = 1000000,
        slots = 50
    },

    Keybinds = {
        Open = 'TAB',
        Hotbar = 'Z',
    },

    CleanupDropTime = 15,    -- in minutes
    CleanupDropInterval = 1, -- in minutes

    -- CONFIGURACIÓN DE MOCHILA AL MORIR
    -- true: Al morir, el jugador dropea una mochila/bolsa en el suelo con todos sus ítems dentro.
    -- false: Al morir, los ítems NO se dropean en el suelo y se mantienen en el inventario con el jugador cuando revive o reaparece.
    DropBackpackOnDeath = true,
    DropInventoryOnDeath = true, -- Alias compatible por comodidad

    -- Webhook de Discord para el log de mochilas que se dropean al morir.
    -- Si lo dejas en '' (vacío), utilizará el sistema estándar de logs (qb-log en los canales 'drop' y 'death').
    -- Si colocas una URL de Discord Webhook válida, enviará además un embed detallado con los ítems y el comando de devolución directamente a ese canal.
    DeathDropWebhook = '',

    ItemDropObject = `bkr_prop_duffel_bag_01a`,
    ItemDropObjectBone = 28422,
    ItemDropObjectOffset = {
        vector3(0.260000, 0.040000, 0.000000),
        vector3(90.000000, 0.000000, -78.989998),
    },

    VendingObjects = {
        'prop_vend_soda_01',
        'prop_vend_soda_02',
        'prop_vend_water_01',
        'prop_vend_coffe_01',
    },

    VendingItems = {
        { name = 'kurkakola',    price = 4, amount = 50 },
        { name = 'water_bottle', price = 4, amount = 50 },
    },
}
