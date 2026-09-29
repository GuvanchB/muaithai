import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var scene = GameScene.make()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            SpriteView(scene: scene)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Strike.allCases) { s in
                    Button { scene.perform(s) } label: {
                        VStack(spacing: 2) {
                            Text(s.icon).font(.title2)
                            Text(s.title)
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(2).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .foregroundColor(.yellow)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.6)))
                    }
                }
            }
            .padding(10)
            .background(Color(white: 0.1))
        }
        .background(Color(white: 0.1).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
