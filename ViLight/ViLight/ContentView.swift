import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @State private var mode: LightMode = .cct
    @State private var showControls: Bool = true
    
    // CCT Mode
    @State private var temperature: Double = 4500 // 3000K to 8000K
    
    // HSI Mode
    @State private var hue: Double = 0.5
    @State private var saturation: Double = 1.0
    
    // Global
    @State private var brightness: Double = {
        #if os(iOS)
        return UIScreen.main.brightness
        #else
        return 1.0
        #endif
    }()
    
    enum LightMode: String, CaseIterable {
        case cct = "Белый (CCT)"
        case hsi = "Цвет (HSI)"
    }
    
    var brightnessBinding: Binding<Double> {
        Binding<Double>(
            get: { self.brightness },
            set: { newValue in
                self.brightness = newValue
                #if os(iOS)
                UIScreen.main.brightness = CGFloat(newValue)
                #endif
            }
        )
    }
    
    var body: some View {
        ZStack {
            // Background light
            currentColor
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls.toggle()
                    }
                }
            
            if showControls {
                VStack {
                    Text("Нажми в любом месте, чтобы скрыть настройки")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.top, 40)
                    
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Picker("Режим", selection: $mode) {
                            ForEach(LightMode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        if mode == .cct {
                            VStack(alignment: .leading) {
                                Text("Температура: \(Int(temperature))K")
                                    .font(.subheadline)
                                Slider(value: $temperature, in: 3000...8000)
                            }
                            
                            // Temperature gradient preview
                            let tempGradient = Gradient(colors: [colorForTemperature(3000), colorForTemperature(8000)])
                            LinearGradient(gradient: tempGradient, startPoint: .leading, endPoint: .trailing)
                                .frame(height: 12)
                                .cornerRadius(6)
                                .padding(.bottom, 10)
                            
                        } else {
                            // HSI Mode: Color Wheel
                            ColorWheel(hue: $hue, saturation: $saturation)
                                .frame(width: 220, height: 220)
                                .padding(.vertical, 10)
                            
                            VStack(alignment: .leading) {
                                Text("Насыщенность")
                                    .font(.subheadline)
                                Slider(value: $saturation, in: 0...1)
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading) {
                            Text("Яркость экрана")
                                .font(.subheadline)
                            Slider(value: brightnessBinding, in: 0.0...1.0)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(24)
                    .padding()
                    .shadow(radius: 20)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // Prevent screen from turning off automatically
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = true
            brightness = UIScreen.main.brightness
            #endif
        }
        .onDisappear {
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
    }
    
    var currentColor: Color {
        if mode == .cct {
            return colorForTemperature(temperature)
        } else {
            return Color(hue: hue, saturation: saturation, brightness: 1.0)
        }
    }
    
    func colorForTemperature(_ temp: Double) -> Color {
        let t = temp / 100.0
        var r: Double, g: Double, b: Double
        
        if t <= 66 {
            r = 255
            g = 99.4708025861 * log(t) - 161.1195681661
            b = t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307
        } else {
            r = 329.698727446 * pow(t - 60, -0.1332047592)
            g = 288.1221695283 * pow(t - 60, -0.0755148492)
            b = 255
        }
        
        r = max(0, min(255, r)) / 255.0
        g = max(0, min(255, g)) / 255.0
        b = max(0, min(255, b)) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
}

struct ColorWheel: View {
    @Binding var hue: Double
    @Binding var saturation: Double
    
    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Hue Gradient (Outer Ring)
                AngularGradient(gradient: Gradient(colors: [
                    Color(hue: 0.0, saturation: 1, brightness: 1),
                    Color(hue: 0.166, saturation: 1, brightness: 1),
                    Color(hue: 0.333, saturation: 1, brightness: 1),
                    Color(hue: 0.5, saturation: 1, brightness: 1),
                    Color(hue: 0.666, saturation: 1, brightness: 1),
                    Color(hue: 0.833, saturation: 1, brightness: 1),
                    Color(hue: 1.0, saturation: 1, brightness: 1)
                ]), center: .center)
                .clipShape(Circle())
                
                // Saturation Gradient (Center White)
                RadialGradient(gradient: Gradient(colors: [.white, .white.opacity(0.0)]), center: .center, startRadius: 0, endRadius: radius)
                .clipShape(Circle())
                
                // Indicator
                Circle()
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
                    .background(Circle().fill(Color(hue: hue, saturation: saturation, brightness: 1.0)))
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.3), radius: 3)
                    .position(indicatorPosition(center: center, radius: radius))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateColor(at: value.location, center: center, radius: radius)
                    }
            )
        }
    }
    
    func indicatorPosition(center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = hue * 2 * .pi
        let r = saturation * radius
        let x = center.x + CGFloat(cos(angle)) * r
        let y = center.y + CGFloat(sin(angle)) * r
        return CGPoint(x: x, y: y)
    }
    
    func updateColor(at location: CGPoint, center: CGPoint, radius: CGFloat) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = min(sqrt(dx * dx + dy * dy), radius)
        
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }
        
        hue = angle / (2 * .pi)
        saturation = distance / radius
    }
}

#Preview {
    ContentView()
}
