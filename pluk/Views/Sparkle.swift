//
//  Sparkle.swift
//  Pluk
//
//  Created by Fauzaan on 4/23/25.
//

import SwiftUI

extension Bundle {
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as! String
    }
}

struct ContentView: View {
    var body: some View {
        Text("\(Bundle.main.buildNumber)")
            .padding()
            .frame(width: 300, height: 200)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
