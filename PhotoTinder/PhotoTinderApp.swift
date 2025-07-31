//
//  PhotoTinderApp.swift
//  PhotoTinder
//
//  Created by Jarosław Derda on 31/07/2025.
//

import SwiftUI

// Definicja enum dla motywów aplikacji
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "Systemowy" // Dostosowuje się do ustawień systemowych
    case light = "Jasny"    // Wymusza tryb jasny
    case dark = "Ciemny"    // Wymusza tryb ciemny

    var id: String { self.rawValue } // Używane przez ForEach

    // Zwraca odpowiedni ColorScheme, nil dla systemowego
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct PhotoTinderApp: App {
    // Odczytuje preferowany motyw z UserDefaults (jest trwały)
        @AppStorage("appTheme") private var appTheme: AppTheme = .system // Domyślnie ustawiony na systemowy

        var body: some Scene {
            WindowGroup {
                ContentView()
                    .preferredColorScheme(appTheme.colorScheme) // Stosuje wybrany motyw do całego widoku
            }
        }
}
