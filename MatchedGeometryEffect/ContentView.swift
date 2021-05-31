//
//  ContentView.swift
//  MatchedGeometryEffect
//
//  Created by Chris Eidhof on 25.05.21.
//

import SwiftUI

struct GeometryKey: Hashable {
    var namespace: Namespace.ID
    var id: AnyHashable
}

typealias GeometryEffectDatabase = [GeometryKey: CGRect]

struct GeometryEffectKey: PreferenceKey, EnvironmentKey {
    static var defaultValue: GeometryEffectDatabase = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: {
            print("Duplicate isSource views")
            return $1
        })
    }
}

extension EnvironmentValues {
    var geometryEffectDatabase: GeometryEffectKey.Value {
        get { self[GeometryEffectKey.self] }
        set { self[GeometryEffectKey.self] = newValue }
    }
}

struct FrameKey: PreferenceKey {
    static var defaultValue: CGRect?
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

extension View {
    func onFrameChange(_ f: @escaping (CGRect) -> ()) -> some View {
        overlay(GeometryReader { proxy in
            Color.clear.preference(key: FrameKey.self, value: proxy.frame(in: .global))
        }).onPreferenceChange(FrameKey.self, perform: {
            f($0!)
        })
    }
}

struct MatchedGeometryEffect<ID: Hashable>: ViewModifier {
    var id: ID
    var namespace: Namespace.ID
    var properties: MatchedGeometryProperties
    var isSource: Bool = true
    @Environment(\.geometryEffectDatabase) var database
    
    var key: GeometryKey {
        GeometryKey(namespace: namespace, id: id)
    }
    
    var frame: CGRect? { database[key] }
    @State var originalFrame: CGRect?
    var offset: CGSize {
        guard let target = frame, let original = originalFrame else {
            return .zero
        }
        return CGSize(width: target.minX - original.minX, height: target.minY - original.minY)
    }
    
    func body(content: Content) -> some View {
        Group {
            if isSource {
                content
                    .overlay(GeometryReader { proxy in
                        let f = proxy.frame(in: .global)
                        Color.clear.preference(key: GeometryEffectKey.self, value: [key: f])
                    })
            } else {
                content
                    .onFrameChange {
                        self.originalFrame = $0
                    }
                    .hidden()
                    .overlay(
                        content
                            .offset(offset)
                            .frame(width: frame?.size.width, height: frame?.size.height)
                        , alignment: .topLeading
                    )
            }
        }
    }
}

extension View {
    func myMatchedGeometryEffect<ID: Hashable>(useBuiltin: Bool = true, id: ID, in ns: Namespace.ID, properties: MatchedGeometryProperties = .frame, isSource: Bool = true) -> some View {
        Group {
            if useBuiltin {
                self.matchedGeometryEffect(id: id, in: ns, properties: properties, isSource: isSource)
            } else {
                modifier(MatchedGeometryEffect(id: id, namespace: ns, properties: properties, isSource: isSource))
            }
        }
    }
}

struct Sample: View {
    var builtin = true
    var properties: MatchedGeometryProperties
    @Namespace var ns

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.red)
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties)
                .frame(width: 100, height: 100)
            Circle()
                .fill(Color.green)
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, isSource: false)
                .frame(height: 50)
                .border(Color.blue)
            Circle()
                .fill(Color.blue)
                .frame(width: 25, height: 25)
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, isSource: false)
                .border(Color.blue)
        }.frame(width: 150, height: 100)
    }
}

struct ApplyGeometryEffects: ViewModifier {
    @State var database: GeometryEffectDatabase = [:]
    
    func body(content: Content) -> some View {
        content
            .environment(\.geometryEffectDatabase, database)
            .onPreferenceChange(GeometryEffectKey.self) {
                database = $0
            }

    }
}

extension MatchedGeometryProperties: Hashable {}

struct ContentView: View {
    @State var properties: MatchedGeometryProperties = .frame
    
    var body: some View {
        VStack {
            Picker("Properties", selection: $properties) {
                Text("Position").tag(MatchedGeometryProperties.position)
                Text("Size").tag(MatchedGeometryProperties.size)
                Text("Frame").tag(MatchedGeometryProperties.frame)
            }
            Sample(builtin: true, properties: properties)
            Sample(builtin: false, properties: properties)
        }
        .modifier(ApplyGeometryEffects())
        .padding(100)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
