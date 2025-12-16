//
//  LoxoneStructure.swift
//  Loxone App
//
//  Codable models for Loxone API responses (LoxAPP3.json structure)
//

import Foundation

// MARK: - Main Structure Response

struct LoxoneStructure: Codable {
    let lastModified: String?
    let msInfo: MiniserverInfo?
    let rooms: [String: LoxoneRoom]?
    let cats: [String: LoxoneCategory]?
    let controls: [String: LoxoneControl]?
    let globalStates: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case lastModified
        case msInfo
        case rooms
        case cats
        case controls
        case globalStates
    }
}

// MARK: - Miniserver Info

struct MiniserverInfo: Codable {
    let serialNr: String?
    let msName: String?
    let projectName: String?
    let localUrl: String?
    let remoteUrl: String?
    let tempUnit: Int?
    let currency: String?
    let squareMeasure: String?
    let location: String?
    let languageCode: String?
    let heatPeriodStart: String?
    let heatPeriodEnd: String?
    let coolPeriodStart: String?
    let coolPeriodEnd: String?
    let catTitle: String?
    let roomTitle: String?
    let miniserverType: Int?
}

// MARK: - Room

struct LoxoneRoom: Codable, Identifiable, Equatable, Hashable {
    let uuid: String
    let name: String
    let image: String?
    let defaultRating: Int?
    let isFavorite: Bool?
    let type: Int?
    
    var id: String { uuid }
    
    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case image
        case defaultRating
        case isFavorite
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
        self.defaultRating = try container.decodeIfPresent(Int.self, forKey: .defaultRating)
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite)
        self.type = try container.decodeIfPresent(Int.self, forKey: .type)
        
        // UUID comes from the dictionary key, not the object itself
        self.uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? ""
    }
    
    init(uuid: String, name: String, image: String? = nil, defaultRating: Int? = nil, isFavorite: Bool? = nil, type: Int? = nil) {
        self.uuid = uuid
        self.name = name
        self.image = image
        self.defaultRating = defaultRating
        self.isFavorite = isFavorite
        self.type = type
    }
}

// MARK: - Category

struct LoxoneCategory: Codable, Identifiable {
    let uuid: String
    let name: String
    let image: String?
    let type: String?
    let color: String?
    let isFavorite: Bool?
    let defaultRating: Int?
    
    var id: String { uuid }
    
    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case image
        case type
        case color
        case isFavorite
        case defaultRating
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite)
        self.defaultRating = try container.decodeIfPresent(Int.self, forKey: .defaultRating)
        self.uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? ""
    }
}

// MARK: - Control (Device)

struct LoxoneControl: Codable, Identifiable {
    let uuid: String
    let name: String
    let type: String
    let room: String?
    let cat: String?
    let states: [String: LoxoneStateValue]?
    let details: LoxoneControlDetails?
    let subControls: [String: LoxoneControl]?
    let isFavorite: Bool?
    let isSecured: Bool?
    let defaultRating: Int?
    
    var id: String { uuid }
    
    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case type
        case room
        case cat
        case states
        case details
        case subControls
        case isFavorite
        case isSecured
        case defaultRating
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.room = try container.decodeIfPresent(String.self, forKey: .room)
        self.cat = try container.decodeIfPresent(String.self, forKey: .cat)
        self.states = try container.decodeIfPresent([String: LoxoneStateValue].self, forKey: .states)
        self.details = try container.decodeIfPresent(LoxoneControlDetails.self, forKey: .details)
        self.subControls = try container.decodeIfPresent([String: LoxoneControl].self, forKey: .subControls)
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite)
        self.isSecured = try container.decodeIfPresent(Bool.self, forKey: .isSecured)
        self.defaultRating = try container.decodeIfPresent(Int.self, forKey: .defaultRating)
        
        // UUID comes from the dictionary key in the structure, not from the object itself
        // When decoding from a dictionary value, we need to set it separately
        self.uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? ""
    }
    
    init(uuid: String, name: String, type: String, room: String? = nil, cat: String? = nil, states: [String: LoxoneStateValue]? = nil, details: LoxoneControlDetails? = nil, subControls: [String: LoxoneControl]? = nil, isFavorite: Bool? = nil, isSecured: Bool? = nil, defaultRating: Int? = nil) {
        self.uuid = uuid
        self.name = name
        self.type = type
        self.room = room
        self.cat = cat
        self.states = states
        self.details = details
        self.subControls = subControls
        self.isFavorite = isFavorite
        self.isSecured = isSecured
        self.defaultRating = defaultRating
    }
}

// MARK: - State Value (can be string UUID or complex object)

enum LoxoneStateValue: Codable {
    case uuid(String)
    case complex([String: String])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .uuid(stringValue)
        } else if let dictValue = try? container.decode([String: String].self) {
            self = .complex(dictValue)
        } else {
            self = .uuid("")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .uuid(let string):
            try container.encode(string)
        case .complex(let dict):
            try container.encode(dict)
        }
    }
    
    /// Get the UUID string if this is a simple state
    var uuidString: String? {
        switch self {
        case .uuid(let string):
            return string
        case .complex:
            return nil
        }
    }
}

// MARK: - Control Details

struct LoxoneControlDetails: Codable {
    let format: String?
    let min: Double?
    let max: Double?
    let step: Double?
    let allOff: Bool?
    let movementScene: Int?
    let animation: Int?
    let isAutomatic: Bool?
    let masterValue: String?
    let masterColor: String?
    let jLocked: Bool?
    let presenceConnected: Bool?
    
    enum CodingKeys: String, CodingKey {
        case format
        case min
        case max
        case step
        case allOff
        case movementScene
        case animation
        case isAutomatic
        case masterValue
        case masterColor
        case jLocked
        case presenceConnected
    }
}

// MARK: - API Command Response

struct LoxoneCommandResponse: Codable {
    let LL: LoxoneLL
}

struct LoxoneLL: Codable {
    let control: String?
    let value: LoxoneResponseValue?
    let code: String?
    
    enum CodingKeys: String, CodingKey {
        case control
        case value
        case code = "Code"
    }
}

enum LoxoneResponseValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else {
            self = .string("")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
    
    var doubleValue: Double? {
        switch self {
        case .string(let str):
            return Double(str)
        case .number(let num):
            return num
        case .bool(let bool):
            return bool ? 1.0 : 0.0
        }
    }
    
    var stringValue: String {
        switch self {
        case .string(let str):
            return str
        case .number(let num):
            return String(num)
        case .bool(let bool):
            return bool ? "1" : "0"
        }
    }
}

// MARK: - Control Types

enum LoxoneControlType: String, CaseIterable {
    case switch_ = "Switch"
    case lightController = "LightController"
    case lightControllerV2 = "LightControllerV2"
    case dimmer = "Dimmer"
    case eibDimmer = "EIBDimmer"
    case colorPicker = "ColorPicker"
    case colorPickerV2 = "ColorPickerV2"
    case jalousie = "Jalousie"
    case centralJalousie = "CentralJalousie"
    case gate = "Gate"
    case window = "Window"
    case door = "Door"
    case pushbutton = "Pushbutton"
    case slider = "Slider"
    case infoOnlyAnalog = "InfoOnlyAnalog"
    case infoOnlyDigital = "InfoOnlyDigital"
    case textState = "TextState"
    case iRoomController = "IRoomController"
    case iRoomControllerV2 = "IRoomControllerV2"
    case alarm = "Alarm"
    case smokeAlarm = "SmokeAlarm"
    case meter = "Meter"
    case audioZone = "AudioZone"
    case audioZoneV2 = "AudioZoneV2"
    case intercom = "Intercom"
    case tracker = "Tracker"
    case fronius = "Fronius"
    case ventilation = "Ventilation"
    case timedSwitch = "TimedSwitch"
    case sauna = "Sauna"
    case pool = "Pool"
    case daytimer = "Daytimer"
    case radio = "Radio"
    case upDownDigital = "UpDownDigital"
    case leftRightDigital = "LeftRightDigital"
    case hourcounter = "Hourcounter"
    case centralLightController = "CentralLightController"
    
    /// Check if this control type is controllable (can be toggled/changed)
    var isControllable: Bool {
        switch self {
        case .switch_, .lightController, .lightControllerV2, .dimmer, .eibDimmer,
             .colorPicker, .colorPickerV2, .jalousie, .centralJalousie, .gate,
             .window, .door, .pushbutton, .slider, .iRoomController, .iRoomControllerV2,
             .alarm, .smokeAlarm, .intercom, .ventilation, .timedSwitch, .sauna,
             .pool, .daytimer, .radio, .upDownDigital, .leftRightDigital,
             .centralLightController:
            return true
        case .infoOnlyAnalog, .infoOnlyDigital, .textState, .meter, .audioZone,
             .audioZoneV2, .tracker, .fronius, .hourcounter:
            return false
        }
    }
    
    /// Check if this control type is a sensor
    var isSensor: Bool {
        switch self {
        case .infoOnlyAnalog, .infoOnlyDigital, .textState, .meter, .tracker, .fronius:
            return true
        default:
            return false
        }
    }
    
    /// Get SF Symbol icon for this control type
    var icon: String {
        switch self {
        case .switch_: return "power"
        case .lightController, .lightControllerV2, .centralLightController: return "lightbulb"
        case .dimmer, .eibDimmer: return "sun.max"
        case .colorPicker, .colorPickerV2: return "paintpalette"
        case .jalousie, .centralJalousie: return "blinds.horizontal.closed"
        case .gate: return "door.garage.closed"
        case .window: return "window.horizontal.closed"
        case .door: return "door.left.hand.closed"
        case .pushbutton: return "button.programmable"
        case .slider: return "slider.horizontal.3"
        case .infoOnlyAnalog: return "chart.line.uptrend.xyaxis"
        case .infoOnlyDigital: return "circle.fill"
        case .textState: return "text.quote"
        case .iRoomController, .iRoomControllerV2: return "thermometer"
        case .alarm: return "bell.badge"
        case .smokeAlarm: return "smoke"
        case .meter: return "bolt"
        case .audioZone, .audioZoneV2: return "speaker.wave.3"
        case .intercom: return "phone"
        case .tracker: return "location"
        case .fronius: return "sun.max.fill"
        case .ventilation: return "wind"
        case .timedSwitch: return "timer"
        case .sauna: return "flame"
        case .pool: return "drop.fill"
        case .daytimer: return "calendar"
        case .radio: return "radio"
        case .upDownDigital, .leftRightDigital: return "arrow.up.arrow.down"
        case .hourcounter: return "clock"
        }
    }
}

// MARK: - Room Extension for Icon

extension LoxoneRoom {
    /// Get an icon based on room name
    var icon: String {
        let lowercaseName = name.lowercased()
        
        let iconMap: [(keywords: [String], icon: String)] = [
            (["living", "wohn"], "sofa"),
            (["bedroom", "schlaf"], "bed.double"),
            (["kitchen", "küche"], "fork.knife"),
            (["bathroom", "bad", "wc", "toilet"], "shower"),
            (["office", "büro", "arbeit"], "desktopcomputer"),
            (["garage"], "car"),
            (["garden", "garten"], "leaf"),
            (["terrace", "terrasse", "balkon", "balcony"], "sun.max"),
            (["basement", "keller"], "archivebox"),
            (["hallway", "flur", "gang", "corridor"], "door.left.hand.open"),
            (["entrance", "eingang"], "door.left.hand.closed"),
            (["pool", "schwimm"], "drop.fill"),
            (["sauna"], "flame"),
            (["gym", "fitness"], "dumbbell"),
            (["cinema", "kino", "theater"], "film"),
            (["wine", "wein"], "wineglass"),
            (["laundry", "wasch"], "washer"),
            (["kids", "kinder", "child"], "figure.child"),
            (["guest", "gast"], "figure.wave"),
            (["storage", "lager", "abstellraum"], "shippingbox"),
            (["attic", "dach", "dachboden"], "house.lodge"),
            (["outside", "aussen", "outdoor"], "cloud.sun")
        ]
        
        for (keywords, icon) in iconMap {
            for keyword in keywords {
                if lowercaseName.contains(keyword) {
                    return icon
                }
            }
        }
        
        return "house"
    }
}

