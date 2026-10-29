Config = {}
Locales = {}

Config.Locale = 'en'
Config.Currency = '$'
Config.Account = 'bank'
Config.RequireLicenseCheck = true
Config.LicenseTable = 'user_licenses'

Config.Keys = {
    system = 'auto'
}

Config.ReturnRadius = 6.0
Config.MaxRentDistance = 25.0
Config.Deposit = 0.2
Config.OverdueDepositRefund = 0.5
Config.DefaultDuration = 2

Config.Blip = {
    enable = true,
    sprite = 326,
    color = 47,
    scale = 0.7
}

Config.Preview = {
    enable = true,
    distance = 6.5,
    height = 1.4,
    speed = 0.25
}

Config.Durations = {
    { minutes = 5, multiplier = 0.5 },
    { minutes = 15, multiplier = 1.0 },
    { minutes = 30, multiplier = 1.6 },
    { minutes = 60, multiplier = 2.6 },
    { minutes = 90, multiplier = 3.4 },
    { minutes = 120, multiplier = 4.2 }
}

Config.Insurances = {
    { key = 'none', percent = 0.0, coverage = 0.0, totalLoss = false },
    { key = 'liability', percent = 0.08, coverage = 0.2, totalLoss = false },
    { key = 'partial', percent = 0.15, coverage = 0.5, totalLoss = false },
    { key = 'full', percent = 0.3, coverage = 0.9, totalLoss = true }
}

Config.Damage = {
    threshold = 10,
    maxPointsPerEvent = 1000,
    costFactor = 0.0015,
    totalLossFactor = 1.0
}

Config.Penalties = {
    abandonFactor = 0.5,
    lostFactor = 0.3,
    lateFeeFactor = 0.1,
    lateFeeInterval = 5,
    stolenAfter = 30,
    stolenJobs = { 'police' }
}

Config.Stations = {
    {
        name = { de = 'Mietstation 1', en = 'Rental Station 1' },
        coords = vector3(-769.0728, 5597.3687, 33.6172),
        spawnPoint = vector4(-774.3129, 5585.0342, 33.4857, 140.1718),
        returnPoint = vector3(-774.3129, 5585.0342, 32.4857),
        categories = {
            {
                name = { de = 'Motorräder', en = 'Motorcycles' },
                license = 'drive_bike',
                vehicles = {
                    { model = 'sanchez', basePrice = 500, tempPrice = 50 },
                    { model = 'sanchez2', basePrice = 550, tempPrice = 55 }
                }
            },
            {
                name = { de = 'Fahrräder', en = 'Bicycles' },
                vehicles = {
                    { model = 'scorcher', basePrice = 75, tempPrice = 10 },
                    { model = 'tribike', basePrice = 75, tempPrice = 10 },
                    { model = 'bmx', basePrice = 75, tempPrice = 10 },
                    { model = 'fixter', basePrice = 75, tempPrice = 10 }
                }
            }
        }
    },
    {
        name = { de = 'Mietstation 2', en = 'Rental Station 2' },
        coords = vector3(-1604.9492, 5257.4321, 2.0787),
        spawnPoint = vector4(-1596.5488, 5263.4189, 0.0, 19.9839),
        returnPoint = vector3(-1596.5488, 5263.4189, 0.0),
        categories = {
            {
                name = { de = 'Boote', en = 'Boats' },
                license = 'dmv',
                vehicles = {
                    { model = 'seashark', basePrice = 200, tempPrice = 20 },
                    { model = 'seashark2', basePrice = 220, tempPrice = 25 },
                    { model = 'dinghy', basePrice = 300, tempPrice = 35 },
                    { model = 'dinghy2', basePrice = 320, tempPrice = 40 },
                    { model = 'dinghy3', basePrice = 350, tempPrice = 45 },
                    { model = 'suntrap', basePrice = 400, tempPrice = 50 },
                    { model = 'tropic', basePrice = 500, tempPrice = 60 },
                    { model = 'tropic2', basePrice = 600, tempPrice = 65 },
                    { model = 'jetmax', basePrice = 700, tempPrice = 75 },
                    { model = 'speeder', basePrice = 800, tempPrice = 80 }
                }
            }
        }
    }
}
