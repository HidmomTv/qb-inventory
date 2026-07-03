Config = Config or {}

Config.Backpacks = {
    ['backpack'] = {
        label = 'Mochila Militar',
        image = 'backpack.png',
        slots = 30,
        maxWeight = 60000, -- 60 kg
        clothing = {
            male = { drawable = 82, texture = 0 },
            female = { drawable = 82, texture = 0 }
        }
    },
    ['backpack_small'] = {
        label = 'Mochila Pequeña',
        image = 'backpack_small.png',
        slots = 15,
        maxWeight = 25000, -- 25 kg
        clothing = {
            male = { drawable = 40, texture = 0 },
            female = { drawable = 40, texture = 0 }
        }
    },
    ['backpack_medium'] = {
        label = 'Mochila Táctica',
        image = 'backpack_medium.png',
        slots = 25,
        maxWeight = 50000, -- 50 kg
        clothing = {
            male = { drawable = 41, texture = 0 },
            female = { drawable = 41, texture = 0 }
        }
    },
    ['backpack_large'] = {
        label = 'Mochila de Excursión',
        image = 'backpack_large.png',
        slots = 35,
        maxWeight = 80000, -- 80 kg
        clothing = {
            male = { drawable = 82, texture = 0 },
            female = { drawable = 82, texture = 0 }
        }
    }
}

