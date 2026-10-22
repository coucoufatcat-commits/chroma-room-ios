import SwiftUI

@main
struct ChromaRoomApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

private enum Palette {
    static let bg = Color(red: 0.055, green: 0.059, blue: 0.055)
    static let panel = Color(red: 0.105, green: 0.11, blue: 0.10)
    static let paper = Color(red: 0.91, green: 0.87, blue: 0.77)
    static let amber = Color(red: 0.95, green: 0.58, blue: 0.25)
    static let muted = Color(red: 0.48, green: 0.49, blue: 0.44)
}

struct ContentView: View {
    @State private var tab = 0
    @State private var film = 1
    @State private var exposure = 0.0
    @State private var grain = 0.55
    @State private var showDevelop = false
    @StateObject private var camera = CameraEngine()
    @State private var colorBalance = 0.0
    @State private var colorSaturation = 1.0
    @State private var saveMessage: String?

    private let films = ["PORTRA 400", "GOLD 200", "CINE 800", "MONO 160"]

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Group {
                    switch tab {
                    case 0: cameraView
                    case 1: darkroomView
                    default: archiveView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                tabBar
            }
        }
        .preferredColorScheme(.dark)
        .task { camera.requestAccessAndStart() }
        .alert("暗房已就绪", isPresented: $showDevelop) {
            Button("继续探索", role: .cancel) { }
        } message: {
            Text(camera.capturedImage == nil ? "先拍摄一张照片，再到暗房调整胶片色彩。" : "可以调整胶片参数，或保存显影后的照片。")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("CHROMA ROOM")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(2.4).foregroundStyle(Palette.paper)
                Text("ANALOG IMAGING LAB · Nº 01")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.2).foregroundStyle(Palette.muted)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Palette.amber).frame(width: 5, height: 5)
                Text("DARKROOM LIVE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1).foregroundStyle(Palette.amber)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .overlay(Capsule().stroke(Palette.amber.opacity(0.4), lineWidth: 0.7))
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 18)
    }

    private var cameraView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("01 / CAPTURE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.amber)
                        Text("让光线\n留下痕迹。")
                            .font(.system(size: 31, weight: .regular, design: .serif)).foregroundStyle(Palette.paper)
                            .lineSpacing(-2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("36") .font(.system(size: 27, weight: .light, design: .monospaced)).foregroundStyle(Palette.paper)
                        Text("FRAMES LEFT").font(.system(size: 7, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(Palette.muted)
                    }
                }
                cameraStage
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FILM STOCK").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(Palette.muted)
                        Text(films[film]).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.paper)
                    }
                    Spacer()
                    Button { film = (film + 1) % films.count } label: {
                        Image(systemName: "dial.low").font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.amber)
                            .frame(width: 44, height: 44).background(Palette.panel, in: Circle())
                            .overlay(Circle().stroke(Palette.paper.opacity(0.17), lineWidth: 1))
                    }
                    .accessibilityLabel("切换胶片")
                }
                controlPanel
                HStack(spacing: 10) {
                    Button {
                        if camera.capturedImage != nil { camera.capturedImage = nil } else { camera.capture() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: camera.capturedImage == nil ? "circle.inset.filled" : "arrow.counterclockwise")
                            Text(camera.capturedImage == nil ? "拍摄一张" : "重新拍摄")
                        }.font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Palette.paper)
                            .frame(maxWidth: .infinity).frame(height: 50).background(Palette.panel, in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.amber.opacity(0.55), lineWidth: 1))
                    }.disabled(!camera.isAuthorized || camera.isCapturing)
                    Button {
                        guard let image = camera.capturedImage else { return }
                        let developed = FilmLab.process(image, exposure: exposure, grain: grain, filmIndex: film, colorBalance: colorBalance, saturation: colorSaturation)
                        FilmLab.saveToPhotos(developed) { success in saveMessage = success ? "已保存到照片图库" : "保存失败，请检查照片权限" }
                    } label: {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.bg).frame(width: 52, height: 50).background(Palette.amber, in: RoundedRectangle(cornerRadius: 4))
                    }.disabled(camera.capturedImage == nil)
                }
                if let saveMessage { Text(saveMessage).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.amber) }
                Button { showDevelop = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "circle.lefthalf.filled")
                        Text("进入暗房").tracking(2)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.bg).padding(.horizontal, 18).frame(height: 54)
                    .background(Palette.amber, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 22)
        }
    }

    private var cameraStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(Color.black)
            if let captured = camera.capturedImage {
                Image(uiImage: FilmLab.process(captured, exposure: exposure, grain: grain, filmIndex: film, colorBalance: colorBalance, saturation: colorSaturation)).resizable().scaledToFill()
            } else if camera.isAuthorized {
                CameraPreview(session: camera.session)
            } else {
                LinearGradient(colors: [Color(red: 0.38, green: 0.29, blue: 0.19), Color(red: 0.16, green: 0.20, blue: 0.17), Color(red: 0.07, green: 0.10, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 8) {
                    Image(systemName: camera.permissionDenied ? "camera.slash" : "camera.aperture").font(.system(size: 34, weight: .light))
                    Text(camera.permissionDenied ? "请在系统设置中允许相机权限" : "正在准备相机…").font(.system(size: 10, weight: .medium, design: .monospaced))
                }.foregroundStyle(Palette.paper)
            }
            GeometryReader { geo in
                Path { p in
                    for i in 1...2 {
                        let x = geo.size.width * CGFloat(i) / 3
                        let y = geo.size.height * CGFloat(i) / 3
                        p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height))
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }.stroke(Palette.paper.opacity(0.18), lineWidth: 0.5)
                Rectangle().stroke(Palette.paper.opacity(0.55), lineWidth: 0.7).padding(22)
            }.allowsHitTesting(false)
            VStack {
                HStack { Text(camera.capturedImage == nil ? "CHROMA · LIVE" : "CHROMA · NEGATIVE"); Spacer(); Image(systemName: "sun.max.fill") }
                Spacer()
                HStack { Text("1/125"); Spacer(); Text("ƒ / 2.8"); Spacer(); Text("ISO AUTO") }
            }.font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.8).foregroundStyle(Palette.paper.opacity(0.95)).padding(14)
            LinearGradient(colors: [.clear, .black.opacity(0.22)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
        }
        .frame(height: 255).clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .bottomLeading) {
            Text(camera.capturedImage == nil ? "VIEWFINDER / LIVE" : "FRAME / DEVELOPED").font(.system(size: 7, weight: .medium, design: .monospaced)).tracking(1.3).foregroundStyle(Palette.paper.opacity(0.75)).padding(12)
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.paper.opacity(0.2), lineWidth: 0.8))
    }

    private var controlPanel: some View {
        VStack(spacing: 14) {
            HStack {
                Text("EXPOSURE COMP.").foregroundStyle(Palette.muted)
                Spacer()
                Text(String(format: "%+.1f EV", exposure)).foregroundStyle(Palette.paper)
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
            Slider(value: $exposure, in: -2...2, step: 0.5).tint(Palette.amber)
            HStack(spacing: 0) {
                ForEach(-2...2, id: \.self) { n in
                    VStack(spacing: 5) {
                        Rectangle().fill(Palette.muted.opacity(n == 0 ? 1 : 0.5)).frame(width: 1, height: n == 0 ? 12 : 6)
                        Text(n == 0 ? "0" : (n > 0 ? "+\(n)" : "\(n)"))
                            .font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity)
                }
            }
            Rectangle().fill(Palette.paper.opacity(0.1)).frame(height: 1)
            HStack {
                Text("FILM GRAIN").foregroundStyle(Palette.muted)
                Spacer()
                Text("\(Int(grain * 100))%").foregroundStyle(Palette.paper)
            }.font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
            Slider(value: $grain, in: 0...1).tint(Palette.amber)
        }
        .padding(16).background(Palette.panel, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.paper.opacity(0.1), lineWidth: 0.7))
    }

    private var darkroomView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionLabel("02 / COLOR DARKROOM")
                Text("显影，\n直到颜色开口。")
                    .font(.system(size: 32, weight: .regular, design: .serif)).foregroundStyle(Palette.paper)
                ZStack {
                    if let captured = camera.capturedImage {
                        Image(uiImage: FilmLab.process(captured, exposure: exposure, grain: grain, filmIndex: film, colorBalance: colorBalance, saturation: colorSaturation)).resizable().scaledToFill().frame(height: 210).clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [Color(red: 0.78, green: 0.38, blue: 0.21), Color(red: 0.37, green: 0.31, blue: 0.23), Color(red: 0.12, green: 0.2, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        VStack(spacing: 8) { Image(systemName: "drop.halffull").font(.system(size: 25)); Text("先拍摄一张照片，再开始显影").font(.system(size: 10, design: .monospaced)) }.foregroundStyle(Palette.paper)
                    }
                    VStack { HStack { Text("NEGATIVE / 01"); Spacer(); Text(films[film]) }; Spacer(); HStack { Text("COLOR BALANCE"); Spacer(); Image(systemName: "circle.hexagongrid.fill") } }
                        .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(Palette.paper).padding(14)
                }.frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("COLOR CHANNELS")
                    HStack { Text("WARM ↔ COOL").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Palette.paper.opacity(0.8)); Spacer(); Text(String(format: "%+.0f", colorBalance * 100)).font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted) }
                    Slider(value: $colorBalance, in: -1...1).tint(Palette.amber)
                    HStack { Text("SATURATION").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Palette.paper.opacity(0.8)); Spacer(); Text("\(Int(colorSaturation * 100))%").font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted) }
                    Slider(value: $colorSaturation, in: 0...1.5).tint(.green)
                    Text("参数会实时作用于拍摄照片；最终效果可保存到系统照片图库。").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
                }.padding(16).background(Palette.panel, in: RoundedRectangle(cornerRadius: 4))
                Button { showDevelop = true } label: {
                    Text("开始显影  ↗").font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(1.5).frame(maxWidth: .infinity).frame(height: 52).background(Palette.amber, in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(Palette.bg)
                }
            }.padding(.horizontal, 22).padding(.bottom, 24)
        }.scrollIndicators(.hidden)
    }

    private var archiveView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionLabel("03 / FILM ARCHIVE")
                Text("每一格，\n都是一段时间。")
                    .font(.system(size: 32, weight: .regular, design: .serif)).foregroundStyle(Palette.paper)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    archiveTile(number: "001", title: "LAST LIGHT", color: Color(red: 0.56, green: 0.35, blue: 0.22))
                    archiveTile(number: "002", title: "QUIET STREET", color: Color(red: 0.24, green: 0.35, blue: 0.29))
                    archiveTile(number: "003", title: "AFTER RAIN", color: Color(red: 0.3, green: 0.34, blue: 0.38))
                    archiveTile(number: "004", title: "SOFT FOCUS", color: Color(red: 0.53, green: 0.43, blue: 0.29))
                }
                Text("示例底片 · 接入照片库后将展示你的真实作品")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
            }.padding(.horizontal, 22).padding(.bottom, 24)
        }.scrollIndicators(.hidden)
    }

    private func archiveTile(number: String, title: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(colors: [color.opacity(0.8), color.opacity(0.35), Palette.bg], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Palette.paper.opacity(0.32)).frame(width: 48, height: 48).blur(radius: 1).offset(x: 25, y: -25)
                Image(systemName: "mountain.2.fill").font(.system(size: 44)).foregroundStyle(Palette.bg.opacity(0.45)).offset(y: 20)
                VStack { HStack { Text("CR-\(number)"); Spacer(); Text("36") }; Spacer(); Text("35 MM / COLOR NEGATIVE").frame(maxWidth: .infinity, alignment: .leading) }
                    .font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(0.6).foregroundStyle(Palette.paper.opacity(0.85)).padding(9)
            }.frame(height: 135).clipped()
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(Palette.paper).padding(10)
        }.background(Palette.panel).clipShape(RoundedRectangle(cornerRadius: 3)).overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.paper.opacity(0.12), lineWidth: 0.7))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.amber)
    }

    private func colorSlider(_ title: String, value: Binding<Double>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.8).foregroundStyle(Palette.paper.opacity(0.8))
            Slider(value: value).tint(tint)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("camera.aperture", title: "相机", index: 0)
            tabButton("drop.halffull", title: "暗房", index: 1)
            tabButton("square.grid.2x2", title: "档案", index: 2)
        }
        .padding(.top, 12).padding(.bottom, 8)
        .background(Palette.bg)
        .overlay(alignment: .top) { Rectangle().fill(Palette.paper.opacity(0.12)).frame(height: 0.7) }
    }

    private func tabButton(_ icon: String, title: String, index: Int) -> some View {
        Button { tab = index } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .regular))
                Text(title).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
            }
            .foregroundStyle(tab == index ? Palette.amber : Palette.muted)
            .frame(maxWidth: .infinity).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
