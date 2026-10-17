import Foundation
import PhoneLibrary
import Testing

@Test func p2PreferencesDecodeWithP3DefaultsAndRoundTripWithoutSchemaChange() throws {
    let old = Data(#"{"fontSize":40,"speed":65}"#.utf8)
    var preferences = try JSONDecoder().decode(ReaderPreferences.self, from: old)
    #expect(preferences.fontSize == 40)
    #expect(preferences.speed == 65)
    #expect(preferences.alignment == .natural)
    #expect(preferences.appearance == .dark)
    #expect(preferences.panelPosition == 0)
    preferences.readingBand = true
    preferences.alignment = .right
    preferences.appearance = .light
    preferences.backgroundOpacity = 0.9
    preferences.panelHeight = 0.7
    preferences.panelPosition = 0.5
    let restored = try JSONDecoder().decode(ReaderPreferences.self, from: JSONEncoder().encode(preferences))
    #expect(restored == preferences)
    #expect(ScriptLibrary.currentSchemaVersion == 1)
}

@Test func invalidReaderGeometryAndOpacityNormalizeAtStorageBoundary() throws {
    let bad = Data(#"{"fontSize":1000,"speed":-4,"backgroundOpacity":0,"panelPosition":4,"panelHeight":-1}"#.utf8)
    let preferences = try JSONDecoder().decode(ReaderPreferences.self, from: bad)
    #expect(preferences.fontSize == 72)
    #expect(preferences.speed == 10)
    #expect(preferences.backgroundOpacity == 0.65)
    #expect(preferences.panelPosition == 1)
    #expect(preferences.panelHeight == 0.3)
}
